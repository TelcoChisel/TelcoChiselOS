#!/bin/bash
set -e

# =============================================================================
# 00-install-all-packages.sh
# Consolidated APT package installation for TelcoChisel ISO build.
# Combines all PPAs, third-party repos, and apt-get install calls from
# scripts 01–09 into a single transaction to eliminate redundant index
# downloads and dependency resolution cycles.
# =============================================================================

echo "=== [Phase 0] Consolidated Package Installation ==="

export DEBIAN_FRONTEND=noninteractive

# Source the shared package arrays (single source of truth for per-script sets)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/packages.sh
source "${SCRIPT_DIR}/lib/packages.sh"
# shellcheck source=lib/chroot-suppress.sh
source "${SCRIPT_DIR}/lib/chroot-suppress.sh"

# Speed up apt downloads: parallel host-based queue, pipelining, auto-retry.
# Timeouts + generous retries matter for the big packages (linux-firmware
# ~640 MB, arm-none-eabi newlib ~460 MB) served from the Cloudflare-fronted
# archive.ubuntu.com, which intermittently times out / resets mid-transfer.
cat > /etc/apt/apt.conf.d/99fast-dl << 'APT_FAST'
Acquire::Queue-Mode "host";
Acquire::http::Pipeline-Depth 5;
Acquire::Retries 5;
Acquire::Retries::Delay::Maximum "30";
Acquire::http::Timeout "60";
Acquire::https::Timeout "60";
APT_FAST

# Shell-level retry around apt-get fetch/install: apt's own Acquire::Retries
# can still exhaust on a persistently flaky mirror, aborting the whole build
# under set -e. Re-running apt-get resumes from the debs already in
# /var/cache/apt/archives, so each attempt fetches strictly less. Mirrors the
# repo's pip-retry.sh philosophy for the same transient-network failure class.
apt_get_retry() {
  local attempt
  for attempt in 1 2 3 4; do
    if apt-get "$@"; then
      return 0
    fi
    echo "  WARNING: 'apt-get $1' attempt ${attempt} failed (likely transient fetch error); retrying in 15s..."
    sleep 15
    apt-get --fix-missing "$@" && return 0 || true
  done
  echo "  ERROR: 'apt-get $1' still failing after retries."
  return 1
}

# ─── 0. Chroot service suppression ──────────────────────────────────────────
# Hardware package postinstalls call udevadm/invoke-rc.d which fail in a
# chroot (no udev socket, no running init). Suppress them for the duration
# of the install phase so dpkg doesn't abort on packages like librtlsdr2,
# libhackrf0, etc. (shared logic in lib/chroot-suppress.sh)
suppress_chroot_services_inplace

# Recover from any previously interrupted dpkg transactions (e.g. from an aborted build)
echo "  Checking and repairing chroot package manager state..."
dpkg --configure -a 2>/dev/null || true

# ─── 0.5. Recover from broken apt state (crucial for --resume) ──────────────
apt-get --fix-broken install -y -o Dpkg::Options::="--force-overwrite" || true


# ─── 1. Add all third-party repositories first ──────────────────────────────

# Fingerprint pinning: after dearmoring each fetched key, verify its
# fingerprint matches the value published by the upstream project before
# trusting the repo. A mismatch (MITM'd/truncated key) removes the key and
# repo file rather than installing packages signed by it.
verify_key_fpr() {  # verify_key_fpr <keyring.gpg> <expected-fpr> <repo-name>
  local key="$1" expected="$2" name="$3" actual
  # gpg prints the listing on stderr (not stdout), so merge streams
  actual=$(gpg --show-keys --with-colons "$key" 2>&1 | awk -F: '$1=="fpr"{print $10; exit}')
  if [ -z "$actual" ]; then
    echo "  ERROR: could not read fingerprint from $name key — rejecting" >&2
    return 1
  fi
  if [ "$actual" != "$expected" ]; then
    echo "  ERROR: $name key fingerprint mismatch (got $actual, want $expected) — rejecting" >&2
    return 1
  fi
  return 0
}

echo "  Adding third-party repositories..."

# Prerequisites for add-apt-repository
apt-get install -y software-properties-common curl wget gnupg

# Firefox PPA (native .deb, not snap)
add-apt-repository -y ppa:mozillateam/ppa
cat << 'EOF' > /etc/apt/preferences.d/99mozillateam
Package: firefox*
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001
EOF

if [ -f /tmp/security/99-telcochisel.pref ]; then
  cp -f /tmp/security/99-telcochisel.pref /etc/apt/preferences.d/99-telcochisel.pref
fi

# Open5GS and MongoDB are NOT installed at build time.
# They are pulled in at first run via: sudo open5gs-install

# Osmocom official repository (OsmoBTS, OsmocomBB, osmo-trx, etc.)
# Key must be dearmored (binary GPG) for apt signed-by= to work.
# On failure, remove the repo file so apt-get update doesn't error out.
OSMOCOM_KEY=/usr/share/keyrings/osmocom.gpg
OSMOCOM_LIST=/etc/apt/sources.list.d/osmocom.list
OSMOCOM_URL="https://downloads.osmocom.org/packages/osmocom:/latest/xUbuntu_24.04"
# Fingerprint of the "osmocom OBS Project <osmocom@osmocom>" signing key
OSMOCOM_FPR="6B2A9F3792D15EB70D4E6A8F86A730B653725973"
if wget -qO- "${OSMOCOM_URL}/Release.key" 2>/dev/null | \
     gpg --dearmor --yes -o "$OSMOCOM_KEY" 2>/dev/null && \
   [ -s "$OSMOCOM_KEY" ] && \
   verify_key_fpr "$OSMOCOM_KEY" "$OSMOCOM_FPR" "Osmocom"; then
  echo "deb [signed-by=${OSMOCOM_KEY}] ${OSMOCOM_URL}/ ./" > "$OSMOCOM_LIST"
  echo "  Osmocom repo added successfully."
else
  echo "  WARNING: Osmocom repo key import failed — skipping repo (tools will build from source in script 10)."
  rm -f "$OSMOCOM_LIST" "$OSMOCOM_KEY"
fi

# Kismet official repo (removed from Ubuntu 24.04 official repos)
KISMET_KEY=/usr/share/keyrings/kismet-archive-keyring.gpg
# Fingerprint published at kismetwireless.net (Kismet Wireless Packaging Signature)
KISMET_FPR="ADA09A0E9B80ACCCE8FE6BB65345B8BF43403B93"
if wget -qO- https://www.kismetwireless.net/repos/kismet-release.gpg.key 2>/dev/null | \
     gpg --dearmor --yes -o "$KISMET_KEY" 2>/dev/null && [ -s "$KISMET_KEY" ] && \
   verify_key_fpr "$KISMET_KEY" "$KISMET_FPR" "Kismet"; then
  echo "deb [signed-by=${KISMET_KEY}] https://www.kismetwireless.net/repos/apt/release/noble noble main" \
    > /etc/apt/sources.list.d/kismet.list
  echo "  Kismet repo added."
else
  echo "  WARNING: Kismet repo key import failed — kismet will be skipped."
  rm -f "$KISMET_KEY" /etc/apt/sources.list.d/kismet.list
fi

# TelcoChisel Official APT Repository (Cloudflare Edge CDN: meta.telcosec.net)
# Distributes official metapackages, SDR hardware rules, and kernel tuning.
TELCOSEC_KEY=/etc/apt/keyrings/telcochisel-archive-keyring.asc
TELCOSEC_SOURCES=/etc/apt/sources.list.d/telcochisel.sources
TELCOSEC_URL="https://meta.telcosec.net"
TELCOSEC_FPR="6326A34C15FEF05FBD63518B4325182E2F0D9DB9"

mkdir -p /etc/apt/keyrings
if curl -fsSL "${TELCOSEC_URL}/public.gpg" -o "$TELCOSEC_KEY" 2>/dev/null && [ -s "$TELCOSEC_KEY" ] && \
   verify_key_fpr "$TELCOSEC_KEY" "$TELCOSEC_FPR" "TelcoChisel"; then
  chmod 0644 "$TELCOSEC_KEY"
  cat > "$TELCOSEC_SOURCES" << 'EOF'
Types: deb
URIs: https://meta.telcosec.net
Suites: noble
Components: main
Signed-By: /etc/apt/keyrings/telcochisel-archive-keyring.asc
EOF
  echo "  TelcoChisel official APT repo added (meta.telcosec.net, fingerprint verified)."
  TELCOSEC_REPO_ENABLED=1
else
  echo "  WARNING: TelcoChisel custom APT repo not reachable or key verification failed — continuing with upstream/source builds."
  rm -f "$TELCOSEC_KEY" "$TELCOSEC_SOURCES"
  TELCOSEC_REPO_ENABLED=0
fi

# ─── 2. Single apt-get update ───────────────────────────────────────────────

echo "  Updating package index (single pass)..."
apt-get update

# ─── 3. System upgrade (opt-in) ─────────────────────────────────────────────
# The blanket upgrade pulls the entire Noble updates set into every ISO and
# makes builds non-reproducible. Off by default; opt in with APT_UPGRADE=1
# (exported by build-iso.sh / build-wsl.sh) for releases that want the
# freshest point-release base.

if [ "${APT_UPGRADE:-0}" = "1" ]; then
  echo "  Upgrading base system (APT_UPGRADE=1)..."
  apt_get_retry upgrade -y
else
  echo "  Skipping base system upgrade (set APT_UPGRADE=1 to enable)"
fi

# ─── 4. Package installation by flavor ─────────────────────────────────────
BUILD_FLAVOR="${BUILD_FLAVOR:-full}"

if [ "$BUILD_FLAVOR" = "lite" ]; then
  echo "  Installing Modular Lite Edition packages (${#PKGS_LITE_BASE[@]} base packages)..."
  # shellcheck disable=SC2086
  apt_get_retry install -y -o Dpkg::Options::="--force-overwrite" \
    "${PKGS_LITE_BASE[@]}"

  # In Lite Edition, install the base metapackage to equip the system with repository keys,
  # hardware SDR udev rules, limits, and the telcosec-pkg CLI.
  if [ "${TELCOSEC_REPO_ENABLED:-0}" = "1" ] && [ -f /etc/apt/sources.list.d/telcochisel.sources ]; then
    echo "  Installing official TelcoChisel base metapackage (telcochisel-base)..."
    apt_get_retry install -y -o Dpkg::Options::="--force-overwrite" telcochisel-base || \
      echo "  WARNING: telcochisel-base install failed (non-fatal)"
  fi
else
  echo "  Installing Flagship Field Edition packages (all 100 telecom tools & runtimes)..."
  # Install the union of all package arrays (sourced from lib/packages.sh)
  # plus any packages that don't belong to a downstream-script group.
  # shellcheck disable=SC2086
  apt_get_retry install -y -o Dpkg::Options::="--force-overwrite" \
    "${PKGS_BASE[@]}" \
    "${PKGS_SDR[@]}" \
    "${PKGS_CORE_NETWORK[@]}" \
    "${PKGS_TOOLS[@]}" \
    "${PKGS_UE_ANALYSIS[@]}" \
    "${PKGS_5GHOUL_BUILD[@]}" \
    "${PKGS_5GHOUL_RUNTIME[@]}" \
    "${PKGS_5GHOUL_REQS[@]}" \
    "${PKGS_ADVANCED[@]}" \
    \
    `# Extra packages not belonging to any per-script group` \
    libsqlite3-dev \
    liblapacke-dev libblas-dev liblapack-dev \
    `# osmo-simtrace2 compiled from source in 06; only its build deps are above`

  # ─── 4b. Official TelcoChisel Metapackages ──────────────────────────────────
  # Installed while chroot service suppression is active so udevadm/sysctl postinst
  # hooks don't fail inside the chroot environment.
  if [ "${TELCOSEC_REPO_ENABLED:-0}" = "1" ] && [ -f /etc/apt/sources.list.d/telcochisel.sources ]; then
    echo "  Installing official TelcoChisel metapackages (${PKGS_TELCOCHISEL_META[*]})..."
    apt_get_retry install -y -o Dpkg::Options::="--force-overwrite" "${PKGS_TELCOCHISEL_META[@]}" || \
      echo "  WARNING: TelcoChisel metapackage install failed (non-fatal)"
  fi
fi

# ─── 5. Purge repo-setup-only packages ──────────────────────────────────────
# software-properties-common (~150 MB with its DBus/gir dependency closure)
# is only needed for add-apt-repository above. Purge it and its now-orphaned
# auto-installed dependencies so they don't ship in the ISO. Non-fatal: a
# purge failure must not abort the build at this late stage.
echo "  Purging software-properties-common and orphaned dependencies..."
apt-get purge -y software-properties-common >/dev/null 2>&1 \
  && apt-get autoremove --purge -y >/dev/null 2>&1 \
  || echo "  WARNING: purge of software-properties-common failed (non-fatal)"

# ─── 5b. Remove chroot service suppression ───────────────────────────────────
restore_chroot_services_inplace

# ─── 6. Wireshark non-interactive config ─────────────────────────────────────

echo "wireshark-common wireshark-common/install-syscap boolean true" | debconf-set-selections
dpkg-reconfigure wireshark-common
if ! getent group wireshark >/dev/null; then
  groupadd -r wireshark
fi

# ─── 7. Clang alternatives (OAI build requires clang-15 as default) ─────────

update-alternatives --install /usr/bin/clang   clang   /usr/bin/clang-15   100 || true
update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-15 100 || true
update-alternatives --install /usr/bin/lld     lld     /usr/bin/lld-15     100 || true

# ─── 6b. Global pip config — extend timeout for large wheel downloads ────────
# SSL DECRYPTION_FAILED on large wheels (>20 MB) is a transient network error.
# pip's --retries does not catch it (urllib3 marks it non-retriable), so scripts
# that download big packages use shell-level retry loops. This config increases
# the per-request timeout so slower CI mirrors don't also time out.
mkdir -p /etc/pip
cat > /etc/pip/pip.conf << 'PIPCONF'
[global]
timeout = 120
retries = 10
PIPCONF

# ─── 7. Hand typing-extensions ownership to pip ─────────────────────────────
# Ubuntu 24.04 installs typing-extensions via apt without a pip RECORD file.
# Any subsequent pip install that tries to upgrade it aborts with
# "Cannot uninstall … RECORD file not found". Force-reinstalling it now
# gives pip a proper RECORD file so later installs can upgrade it freely.
pip3 install --break-system-packages --force-reinstall --no-deps \
  typing-extensions || true

# ─── 8. Rust — deferred to first-run (~550 MB saved from ISO) ───────────────
# Rust is not required by any tool compiled during the ISO build. Deferring it
# saves ~550 MB. Run 'sudo telcosec-install-rust' on the live system when needed.
cat > /usr/local/bin/telcosec-install-rust << 'RUST_SCRIPT'
#!/bin/bash
set -e
echo "=== Installing Rust toolchain (stable, system-wide) ==="
export RUSTUP_HOME=/usr/local/rustup
export CARGO_HOME=/usr/local/cargo
# Prefer a version-pinned rustup-init binary; fall back to the official installer
# script only if the archive CDN is unreachable.
RUSTUP_VERSION="1.27.1"
RUSTUP_INIT_URL="https://static.rust-lang.org/rustup/archive/${RUSTUP_VERSION}/x86_64-unknown-linux-gnu/rustup-init"
if curl --proto '=https' --tlsv1.2 -fsSL "$RUSTUP_INIT_URL" -o /tmp/rustup-init \
   && [ -s /tmp/rustup-init ]; then
  chmod +x /tmp/rustup-init
  /tmp/rustup-init -y --no-modify-path --default-toolchain stable
  rm -f /tmp/rustup-init
  echo "  rustup-init ${RUSTUP_VERSION} installed from archive CDN"
else
  echo "  WARNING: pinned rustup-init download failed — falling back to sh.rustup.rs" >&2
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
    sh -s -- -y --no-modify-path --default-toolchain stable
fi
cat > /etc/profile.d/rust.sh << 'EOF'
export RUSTUP_HOME=/usr/local/rustup
export CARGO_HOME=/usr/local/cargo
export PATH="$CARGO_HOME/bin:$PATH"
EOF
chmod 644 /etc/profile.d/rust.sh
ln -sf /usr/local/cargo/bin/rustc /usr/local/bin/rustc
ln -sf /usr/local/cargo/bin/cargo /usr/local/bin/cargo
echo "Rust installed. Run: source /etc/profile.d/rust.sh"
RUST_SCRIPT
chmod +x /usr/local/bin/telcosec-install-rust

# ─── 9. JAVA_HOME environment ────────────────────────────────────────────────
echo "  Setting JAVA_HOME..."
JAVA_PATH=$(update-alternatives --list java 2>/dev/null | grep -m1 java-17 || true)
if [ -n "$JAVA_PATH" ]; then
  JAVA_HOME_DIR=$(dirname "$(dirname "$JAVA_PATH")")
  cat > /etc/profile.d/java.sh << EOF
export JAVA_HOME=${JAVA_HOME_DIR}
export PATH="\$JAVA_HOME/bin:\$PATH"
EOF
  chmod 644 /etc/profile.d/java.sh
fi


# ─── 10. Kismet (official repo — not in Ubuntu 24.04 universe) ──────────────
if [ -f /etc/apt/sources.list.d/kismet.list ]; then
  apt-get update -q
  apt-get install -y kismet || echo "  WARNING: kismet install failed"
else
  echo "  WARNING: Kismet repo unavailable — skipping kismet."
fi

# ─── 11. SIPp (not in Ubuntu 24.04 — build from source with full modules) ────
if ! command -v sipp >/dev/null 2>&1; then
  echo "  Building optimized sipp from source with all modules (TLS, SCTP, PCAP, GSL)..."
  mkdir -p /opt/telcosec/src
  git clone --depth 1 --branch v3.7.9 https://github.com/SIPp/sipp /opt/telcosec/src/sipp 2>/dev/null \
    || git clone --depth 1 https://github.com/SIPp/sipp /opt/telcosec/src/sipp 2>/dev/null || true
  if [ -d /opt/telcosec/src/sipp ]; then
    cmake -S /opt/telcosec/src/sipp -B /opt/telcosec/src/sipp/build \
      -DCMAKE_BUILD_TYPE=Release \
      -DUSE_SSL=1 \
      -DUSE_SCTP=1 \
      -DUSE_PCAP=1 \
      -DUSE_GSL=1 \
      -DTLS_KEY_LOGGING=1 \
      -DSIPP_MAX_MSG_SIZE=262144 \
      -DCMAKE_CXX_FLAGS="-O3 -pipe" \
      -DCMAKE_INSTALL_PREFIX=/usr/local >/dev/null
    make -C /opt/telcosec/src/sipp/build -j"$(nproc)" sipp >/dev/null
    install -m 755 /opt/telcosec/src/sipp/build/sipp /usr/local/bin/sipp
    echo "  sipp built and installed (TLS, SCTP, PCAP, GSL, TLS_KEY_LOGGING enabled)."
  else
    echo "  WARNING: sipp source clone failed — skipping."
  fi
fi

# ─── 12. Force-reinstall system python libraries with pip RECORD files ───────
pip3 install --break-system-packages --ignore-installed typing-extensions rich rich-argparse 2>/dev/null || true

# ─── 13. Mark phase 0 complete ───────────────────────────────────────────────

touch /tmp/.packages-installed
echo "=== [Phase 0] All packages installed successfully ==="
