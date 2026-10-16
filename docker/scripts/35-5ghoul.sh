#!/bin/bash
# BladeRF userspace + 5Ghoul build dependencies for telcochisel-5ghoul.
# The overlay sources are copied by docker/5ghoul.Dockerfile before this runs.
set -euo pipefail

# shellcheck disable=SC1091
source /opt/telcosec/lib/00-container-common.sh
# shellcheck disable=SC1091
source /opt/telcosec/lib/packages.sh

suppress_services
apt-get update
mapfile -t PKGS < <(filter_pkgs \
  libbladerf2 libbladerf-dev bladerf libuhd-dev uhd-host \
  "${PKGS_5GHOUL_BUILD[@]}" \
  "${PKGS_5GHOUL_RUNTIME[@]}" \
  "${PKGS_5GHOUL_REQS[@]}")
apt_retry install -y "${PKGS[@]}"

chmod 755 /opt/telcosec/5ghoul-overlay/scripts/*.sh /opt/telcosec/5ghoul-overlay/scripts/5ghoul-run
ln -sfn /opt/telcosec/5ghoul-overlay/scripts/install.sh /usr/local/bin/5ghoul-install
ln -sfn /opt/telcosec/5ghoul-overlay/scripts/5ghoul-run /usr/local/bin/5ghoul-run
usermod -aG plugdev telcosec 2>/dev/null || true
chown -R telcosec:telcosec /opt/telcosec/5ghoul-overlay

cat > /etc/sudoers.d/telcosec-5ghoul << 'SUDOERS'
telcosec ALL=(root) NOPASSWD: /opt/telcosec/5ghoul/build/5g_fuzzer
SUDOERS
chmod 440 /etc/sudoers.d/telcosec-5ghoul
visudo -c -f /etc/sudoers.d/telcosec-5ghoul

install_container_healthcheck
rm -rf /var/lib/apt/lists/*
echo "=== telcochisel-5ghoul installation complete ==="
echo "First compile: sudo 5ghoul-install"
