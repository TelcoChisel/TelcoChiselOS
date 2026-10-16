#!/bin/bash
set -euo pipefail

echo "Installing Nginx, PHP-FPM, PostgreSQL, and dashboard PHP extensions..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/record-tool.sh
source "${SCRIPT_DIR}/lib/record-tool.sh"
# shellcheck source=lib/build-tool.sh
source "${SCRIPT_DIR}/lib/build-tool.sh"

export DEBIAN_FRONTEND=noninteractive

# PostgreSQL + php-pgsql: the dashboard's actual DB layer (html/includes/db.php)
# is PostgreSQL-only (PDO pgsql) — php-sqlite3/sqlite3 are kept too since
# config.php still points BTS_SCANS_DB/APN_DB at local SQLite files.
# php-curl/mbstring/xml/zip/redis + php-cli match html/composer.json's
# ext-* requirements (curl, mbstring, pcntl, pdo_pgsql, posix, redis, xml,
# zip) — pcntl/posix ship inside php-cli on Ubuntu, no separate package needed.
apt-get install -y \
  nginx php-fpm php-cli \
  postgresql postgresql-contrib php-pgsql \
  php-sqlite3 sqlite3 \
  php-curl php-mbstring php-xml php-zip php-redis \
  composer sudo unzip git

# Derive installed PHP version (e.g. "8.3") so the nginx config doesn't break
# when Ubuntu ships a newer default PHP. Falls back to "8.3" if detection fails.
PHP_VER=$(php --version 2>/dev/null | grep -oP '^\S+\s+\K\d+\.\d+' | head -1)
PHP_VER="${PHP_VER:-8.3}"
echo "  PHP version detected: ${PHP_VER}"

# Enable-only — the chroot's policy-rc.d blocks service starts during build
# (see 00-install-all-packages.sh), so PostgreSQL only actually comes up on
# first real boot. The postgresql-common postinst still creates the default
# cluster on disk at install time, which is what we need for now.
systemctl enable postgresql || true

echo "Deploying Dashboard..."
mkdir -p /var/www/html
rm -f /var/www/html/index.html

# Canonical dashboard repo — must match CLAUDE.md and the clone in
# 10-install-telecom-advanced.sh (section: parallel repo clones). Both scripts
# previously referenced two DIFFERENT repos/orgs (a stale mistake — this one
# is the correct one, used by 10 and documented in CLAUDE.md).
DASHBOARD_REPO="https://github.com/TelcoSec-Tools/TelcoSec-ChiselControl-Dashboard"
DASHBOARD_SRC="/opt/telcosec/dashboard"

# 10-install-telecom-advanced.sh already clones this repo into $DASHBOARD_SRC
# as part of its parallel-clone block (build order: ... 10 11 12), so the
# normal case is deploying from that existing clone rather than re-cloning.
# Clone-if-missing guard covers standalone/resumed runs where 10 was skipped
# (matches the pattern used by oai-install, yatebts-install, etc.).
if [ ! -d "$DASHBOARD_SRC" ]; then
  echo "  ${DASHBOARD_SRC} not present (10-install-telecom-advanced.sh may have been skipped) — cloning directly..."
  clone_if_missing "$DASHBOARD_REPO" "$DASHBOARD_SRC" || \
    echo "  WARNING: dashboard clone failed — deploying nginx/PHP without dashboard UI" >&2
fi

if [ -d "$DASHBOARD_SRC" ] && [ -n "$(ls -A "$DASHBOARD_SRC" 2>/dev/null)" ]; then
    # Repo layout hasn't been confirmed (web assets may be in an html/
    # subdirectory or at repo root) — try both, keep the fallback.
    cp -r "$DASHBOARD_SRC"/html/* /var/www/html/ 2>/dev/null || cp -r "$DASHBOARD_SRC"/* /var/www/html/

    # Wire up the DB connection the dashboard actually reads (html/includes/db.php
    # via vlucas/phpdotenv) to the role/database created by the first-boot init
    # unit below. Only write if the deployed tree didn't already ship one.
    if [ ! -f /var/www/html/.env ] && [ -f /var/www/html/.env.example ]; then
      cp /var/www/html/.env.example /var/www/html/.env
      # Placeholder only — first-boot telcosec-dashboard-db-init.sh replaces
      # DB_PASS with a per-install openssl random secret and creates the role.
      sed -i \
        -e "s/^DB_HOST=.*/DB_HOST=127.0.0.1/" \
        -e "s/^DB_PORT=.*/DB_PORT=5432/" \
        -e "s/^DB_NAME=.*/DB_NAME=osmocom/" \
        -e "s/^DB_USER=.*/DB_USER=osmocom/" \
        -e "s/^DB_PASS=.*/DB_PASS=CHANGE_ME_AT_FIRST_BOOT/" \
        /var/www/html/.env
      chmod 640 /var/www/html/.env
      chown www-data:www-data /var/www/html/.env
    fi

    # Vendor libraries (Ratchet, Symfony Process, phpdotenv, Monolog) the
    # dashboard's own composer.json declares — needed for db.php's dotenv
    # loading and the WebSocket server. Best-effort: a network hiccup here
    # shouldn't fail the whole ISO build.
    if [ -f /var/www/html/composer.json ]; then
      (cd /var/www/html && composer install --no-dev --optimize-autoloader --no-interaction) \
        || echo "  WARNING: composer install failed — dashboard vendor/ will be missing until run manually."
    fi

    chown -R www-data:www-data /var/www/html
    echo "Dashboard successfully deployed from ${DASHBOARD_SRC}."
else
    echo "WARNING: Dashboard source not available at ${DASHBOARD_SRC} (repo not reachable or empty)."
    echo "Skipping dashboard UI deployment. Nginx and PHP are installed and ready."
fi

# Configure Nginx for PHP — use unquoted heredoc so $PHP_VER expands.
# nginx's own $ variables (like $uri) are escaped with \$ below.
cat > /etc/nginx/sites-available/default << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.php index.html index.htm;

    server_name _;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php${PHP_VER}-fpm.sock;
    }

    # Deny all dotfiles/dotdirs (.env, .git, .htaccess, etc.) — try_files
    # would otherwise serve /var/www/html/.env with DB credentials.
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}
EOF

# Ensure PHP-FPM is configured correctly
systemctl enable nginx || true
systemctl enable "php${PHP_VER}-fpm" || true

# ─── Service set the dashboard is actually allowed to control ───────────────
# Single source of truth for this script: must mirror the systemd-managed
# entries in html/includes/services.php's getServiceDefinitions() (osmo-*
# NITB stack + YateBTS's yate/yatebts units). srsenb/srsepc/srsue are excluded
# — services.php marks them 'systemd' => false, the dashboard execs them
# directly rather than through systemctl, so they need no sudo/polkit grant.
# Adding a new systemd-managed service to services.php means adding it here.
OSMO_SERVICES=(
  osmo-hlr osmo-msc osmo-stp osmo-mgw osmo-cbc osmo-bsc
  osmo-bts-trx osmo-trx-lms osmo-trx-uhd osmo-pcu
  osmo-sgsn osmo-ggsn osmo-gbproxy osmo-sip-connector
  yate yatebts
)

# Setup sudoers for www-data to execute systemctl and other commands as telcosec.
#
# Previously this used unscoped wildcards (`systemctl start/stop/restart *`,
# `pkill *`, `mkdir *`, `chown *`) which let a compromised PHP dashboard
# stop/restart ANY service, kill ANY process as telcosec, or create/chown ANY
# path on the system. Scoped down to exactly what this dashboard needs:
#   - open5gs-start/open5gs-stop: the project's own guarded helper scripts
#     (see 09-install-5ghoul.sh) rather than raw systemctl against Open5GS's
#     Docker-Compose-managed containers.
#   - nginx / php-fpm restart: the dashboard's own serving stack.
#   - systemctl start/stop/restart <service>: one explicit line per unit in
#     OSMO_SERVICES above (html/api/services.php calls
#     `sudo -u telcosec systemctl <verb> <service>` directly) — generated by
#     the loop below so the list can't drift from OSMO_SERVICES, but the
#     resulting sudoers file itself contains no wildcards.
#   - mkdir/chown: scoped to /opt/telcosec/gsm_data, the dashboard's own data
#     directory, not the whole filesystem.
# If the dashboard needs to control a NEW service or path, add an explicit
# scoped rule here — do not revert to a wildcard.
# Path-guarded helpers — sudoers must not use `*` arg wildcards (they match `/`).
cat > /usr/local/bin/telcosec-dashboard-mkdir << 'HELPER'
#!/bin/bash
set -euo pipefail
TARGET="${1:-/opt/telcosec/gsm_data}"
case "$TARGET" in
  /opt/telcosec/gsm_data|/opt/telcosec/gsm_data/*) ;;
  *) echo "telcosec-dashboard-mkdir: refused path outside /opt/telcosec/gsm_data: $TARGET" >&2; exit 1 ;;
esac
exec /bin/mkdir -p "$TARGET"
HELPER
cat > /usr/local/bin/telcosec-dashboard-chown << 'HELPER'
#!/bin/bash
set -euo pipefail
TARGET="${1:-/opt/telcosec/gsm_data}"
case "$TARGET" in
  /opt/telcosec/gsm_data|/opt/telcosec/gsm_data/*) ;;
  *) echo "telcosec-dashboard-chown: refused path outside /opt/telcosec/gsm_data: $TARGET" >&2; exit 1 ;;
esac
exec /bin/chown -R telcosec:telcosec "$TARGET"
HELPER
chmod 0755 /usr/local/bin/telcosec-dashboard-mkdir /usr/local/bin/telcosec-dashboard-chown

# NOTE: unquoted heredoc (unlike other sudoers examples) so $PHP_VER expands.
cat > /etc/sudoers.d/dashboard-www-data << EOF
www-data ALL=(telcosec) NOPASSWD: /usr/local/bin/open5gs-start
www-data ALL=(telcosec) NOPASSWD: /usr/local/bin/open5gs-stop
www-data ALL=(telcosec) NOPASSWD: /bin/systemctl restart nginx
www-data ALL=(telcosec) NOPASSWD: /bin/systemctl restart php${PHP_VER}-fpm
www-data ALL=(telcosec) NOPASSWD: /usr/local/bin/telcosec-dashboard-mkdir, /usr/local/bin/telcosec-dashboard-mkdir *
www-data ALL=(telcosec) NOPASSWD: /usr/local/bin/telcosec-dashboard-chown, /usr/local/bin/telcosec-dashboard-chown *
EOF
for svc in "${OSMO_SERVICES[@]}"; do
  for verb in start stop restart; do
    echo "www-data ALL=(telcosec) NOPASSWD: /bin/systemctl ${verb} ${svc}" >> /etc/sudoers.d/dashboard-www-data
  done
done
chmod 0440 /etc/sudoers.d/dashboard-www-data
visudo -c -f /etc/sudoers.d/dashboard-www-data || echo "WARNING: dashboard sudoers file failed visudo syntax check"

# ─── polkit: authorize telcosec itself to control those same units ─────────
# The sudoers rule above only gets www-data AS FAR AS running the command as
# the 'telcosec' user — telcosec still isn't root, and plain `systemctl
# start/stop/restart` on a system unit requires polkit authorization for
# non-root callers (systemd doesn't consult sudoers for this). Without this
# rule every service button in the dashboard would fail with "Interactive
# authentication required" even though the sudoers layer succeeded. Scoped to
# exactly OSMO_SERVICES + the four verbs the dashboard actually issues.
POLKIT_UNITS_JS=$(printf '"%s.service", ' "${OSMO_SERVICES[@]}")
POLKIT_UNITS_JS="[${POLKIT_UNITS_JS%, }]"

cat > /etc/polkit-1/rules.d/49-telcosec-dashboard.rules << EOF
// Generated by 12-install-dashboard.sh — allows the 'telcosec' user to
// start/stop/restart exactly the systemd units the ChiselControl Dashboard
// manages (html/includes/services.php's getServiceDefinitions()), nothing
// else. html/api/services.php runs these via
// 'sudo -u telcosec systemctl <verb> <service>' — the sudoers rule above
// grants www-data -> telcosec, this rule grants telcosec -> systemd.
// Do not widen to a blanket allow; add units here explicitly if
// getServiceDefinitions() grows, keeping OSMO_SERVICES in this script in sync.
polkit.addRule(function(action, subject) {
    var allowedUnits = ${POLKIT_UNITS_JS};
    var allowedVerbs = ["start", "stop", "restart", "reload-or-restart"];
    if (action.id == "org.freedesktop.systemd1.manage-units" &&
        subject.user == "telcosec" &&
        allowedUnits.indexOf(action.lookup("unit")) != -1 &&
        allowedVerbs.indexOf(action.lookup("verb")) != -1) {
        return polkit.Result.YES;
    }
});
EOF

# ─── Osmocom NITB core/RAN packages ─────────────────────────────────────────
# The dashboard's service registry (services.php) targets the classic Osmocom
# NITB daemons, which nothing else in this build installs (only
# libosmocore-dev, a build dependency, via PKGS_UE_ANALYSIS) — without this,
# every osmo-* row in the dashboard UI would show "not installed" forever.
# Installed from the Osmocom OBS repo already added in
# 00-install-all-packages.sh (downloads.osmocom.org .../xUbuntu_24.04).
# Package names here are best-effort against that index; a missing package
# just leaves that one service row unavailable, it doesn't fail the build —
# verify against the repo's actual package list if any warn below.
# yate/yatebts are deliberately NOT apt-installed here: per this OS's tool
# catalog, YateBTS is a deferred first-run build (`sudo yatebts-install`,
# see 10-install-telecom-advanced.sh) rather than an apt package; whether
# that helper produces systemd units named yate.service/yatebts.service
# (as services.php assumes) still needs verifying against that script.
OSMO_NITB_PACKAGES=(
  osmo-hlr osmo-msc osmo-stp osmo-mgw osmo-cbc osmo-bsc
  osmo-bts-trx osmo-trx-lms osmo-trx-uhd osmo-pcu
  osmo-sgsn osmo-ggsn osmo-gbproxy osmo-sip-connector
)
for pkg in "${OSMO_NITB_PACKAGES[@]}"; do
  apt-get install -y "$pkg" 2>/dev/null || \
    echo "  WARNING: package '${pkg}' not available — corresponding dashboard service will show as not installed"
done
record_tool "Osmocom NITB core stack" "$(command -v osmo-hlr 2>/dev/null)" "core"

# Create data directory for the dashboard
echo "Preparing GSM data directory..."
mkdir -p /opt/telcosec/gsm_data/scripts/management
mkdir -p /opt/telcosec/gsm_data/config/templates
mkdir -p /opt/telcosec/gsm_data/backups

# Setup SQLite DB permissions so www-data can interact, but owned by telcosec
chown -R telcosec:telcosec /opt/telcosec/gsm_data
chmod -R 775 /opt/telcosec/gsm_data

# Ensure www-data is in the telcosec group to write to the DB if necessary
usermod -aG telcosec www-data

# Non-root hardware access (BladeRF/HackRF/LimeSDR/USRP/PC-SC) for the
# dashboard's hardware-detection features, same convention as the udev rules
# in 08-system-optimization.sh (README: "Non-Root Hardware Access"). Without
# this, secure_exec() calls to bladeRF-cli/hackrf_info/LimeUtil/pcsc_scan as
# www-data would fail to open the USB devices even though the binaries exist.
usermod -aG plugdev www-data

# ─── First-boot DB init (role, database, schema) ────────────────────────────
# Can't run this at build time: the chroot's policy-rc.d blocks service
# starts (see 00-install-all-packages.sh), so PostgreSQL isn't actually up
# during provisioning. Deferred to a oneshot unit on first real boot, guarded
# by a sentinel so it only runs once — matches this project's first-run
# helper convention (srsran-install, open5gs-install, etc.).
cat > /usr/local/bin/telcosec-dashboard-db-init.sh << 'EOF'
#!/bin/bash
set -e
SENTINEL=/opt/telcosec/gsm_data/.db-initialized
ENV_FILE=/var/www/html/.env
PASS_FILE=/etc/telcosec/dashboard-db.pass
[ -f "$SENTINEL" ] && exit 0

for i in $(seq 1 30); do
  sudo -u postgres pg_isready -q && break
  sleep 1
done

# Per-install random DB password (never ship a fixed public secret).
mkdir -p /etc/telcosec
if [ -f "$PASS_FILE" ] && [ -s "$PASS_FILE" ]; then
  DB_PASS=$(tr -d '\n\r' < "$PASS_FILE")
else
  DB_PASS=$(openssl rand -hex 16)
  umask 077
  printf '%s\n' "$DB_PASS" > "$PASS_FILE"
  chmod 600 "$PASS_FILE"
  chown root:root "$PASS_FILE"
fi

if [ -f "$ENV_FILE" ]; then
  sed -i "s/^DB_PASS=.*/DB_PASS=${DB_PASS}/" "$ENV_FILE"
  chmod 640 "$ENV_FILE"
  chown www-data:www-data "$ENV_FILE"
fi

# Escape single quotes for SQL literal: ' -> ''
DB_PASS_SQL=${DB_PASS//\'/\'\'}

sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='osmocom'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE ROLE osmocom LOGIN PASSWORD '${DB_PASS_SQL}';"
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='osmocom'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE DATABASE osmocom OWNER osmocom;"

# Keep password in sync if the role already existed from a prior partial run.
sudo -u postgres psql -c "ALTER ROLE osmocom WITH PASSWORD '${DB_PASS_SQL}';" >/dev/null

if [ -f /var/www/html/install.php ]; then
  php /var/www/html/install.php || \
    echo "telcosec-dashboard-db-init: install.php failed — schema may need setting up manually."
fi

mkdir -p "$(dirname "$SENTINEL")"
touch "$SENTINEL"
EOF
chmod +x /usr/local/bin/telcosec-dashboard-db-init.sh

cat > /etc/systemd/system/telcosec-dashboard-db-init.service << 'EOF'
[Unit]
Description=TelcoSec ChiselControl Dashboard - first-boot database init
After=postgresql.service network.target
Requires=postgresql.service
ConditionPathExists=!/opt/telcosec/gsm_data/.db-initialized

[Service]
Type=oneshot
ExecStart=/usr/local/bin/telcosec-dashboard-db-init.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl enable telcosec-dashboard-db-init.service 2>/dev/null || true

echo "Dashboard installation complete."
