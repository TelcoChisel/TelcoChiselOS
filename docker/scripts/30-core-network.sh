#!/bin/bash
# =============================================================================
# docker/scripts/30-core-network.sh — telcochisel-core-network image contents
#
# Runs as root during `docker build`, FROM telcochisel-base. Installs the
# build-dependency set and first-run helper stubs for srsRAN, Open5GS, OAI
# UE, and 5Ghoul — mirrors (not sources) builder/scripts/03-install-core-
# network.sh, builder/scripts/09-install-5ghoul.sh, and the OAI/gtp5g
# sections of builder/scripts/10-install-telecom-advanced.sh.
#
# HONEST LIMITATIONS (see docker/README.md for detail — these are the same
# tools flagged as host-only in CLAUDE.md, not new gaps introduced by
# containerizing):
#   - gtp5g is a kernel module. It cannot be built against, or loaded into,
#     the container's host kernel from inside a container — gtp5g-load will
#     fail unless the container has kernel headers matching the *host* and
#     runs with enough privilege to modprobe (--privileged + host /lib/modules
#     mount). Prefer loading gtp5g on the host directly.
#   - open5gs-install uses upstream's docker-compose flow (container-in-
#     container). Needs a mounted host docker socket (see docker/compose.yaml)
#     or Docker-in-Docker; it will not work in a fully isolated container.
#   - 5ghoul-install compiles a full OAI gNB (20-60 min) against real SDR
#     hardware. The BladeRF/LimeSDR config auto-patchers from the ISO
#     (builder/scripts/09-install-5ghoul.sh) are deliberately NOT duplicated
#     here to keep this image lean — see the 5ghoul-install stub below for
#     what's included.
# =============================================================================
set -e

LIB=/opt/telcosec/lib
TELCOSEC_OPT=/opt/telcosec
# shellcheck source=00-container-common.sh
source "${LIB}/00-container-common.sh"
# shellcheck source=../../builder/scripts/lib/packages.sh
source "${LIB}/packages.sh"

suppress_services

# ─── 1. APT packages (PKGS_CORE_NETWORK + PKGS_5GHOUL_*, filtered) ─────────
echo "=== Installing core-network APT packages ==="
apt-get update
mapfile -t FILTERED_PKGS < <(filter_pkgs \
  "${PKGS_CORE_NETWORK[@]}" "${PKGS_5GHOUL_BUILD[@]}" \
  "${PKGS_5GHOUL_RUNTIME[@]}" "${PKGS_5GHOUL_REQS[@]}")
apt_retry install -y --no-install-recommends "${FILTERED_PKGS[@]}" build-essential
update-alternatives --install /usr/bin/clang   clang   /usr/bin/clang-15   100 || true
update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-15 100 || true
update-alternatives --install /usr/bin/lld     lld     /usr/bin/lld-15     100 || true
rm -rf /var/lib/apt/lists/*

mkdir -p /etc/telcosec

# Test PLMN constants (ITU-T standard test network), from 10-install-telecom-advanced.sh
cat > /etc/telcosec/plmn.conf << 'EOF'
# TelcoSec test PLMN configuration (ITU-T test network 001-01)
MCC=001
MNC=01
PLMN=00101
TAC=0x0001
EOF

# ─── 2. srsRAN first-run installer (from 03-install-core-network.sh) ───────
cat << 'SRSRAN_SCRIPT' > /usr/local/bin/srsran-install
#!/bin/bash
set -e
INSTALL_DIR="/opt/telcosec/srsRAN_Project"
echo "=== srsRAN Project Builder (https://github.com/srsran/srsRAN_Project) ==="
if [ ! -d "$INSTALL_DIR/.git" ]; then
  echo "[1/3] Cloning srsRAN_Project..."
  if ! git clone --depth 1 --branch release_25_10 --recurse-submodules \
      https://github.com/srsran/srsRAN_Project.git "$INSTALL_DIR"; then
    echo "[1/3] release_25_10 unavailable — cloning default branch"
    git clone --depth 1 --recurse-submodules https://github.com/srsran/srsRAN_Project.git "$INSTALL_DIR"
  fi
else
  echo "[1/3] Already cloned — leaving existing checkout (no floating pull)"
fi
cd "$INSTALL_DIR"
mkdir -p build && cd build
echo "[2/3] Configuring with cmake..."
cmake ../ -DENABLE_EXPORT=ON -DENABLE_ZEROMQ=ON -DENABLE_BLADERF=ON -DENABLE_LIMESDR=ON
echo "[3/3] Compiling (this takes 10-20 min)..."
make -j"$(nproc)"
make install
echo ""
echo "srsRAN installed. Run: srsgnb --help"
SRSRAN_SCRIPT
chmod +x /usr/local/bin/srsran-install

# ─── 3. Open5GS first-run installer (from 03-install-core-network.sh) ──────
# NOTE: this drives `docker compose` FROM INSIDE the container — it needs a
# mounted host docker socket (opt-in compose override), see docker/README.md.
cat << 'OPEN5GS_SCRIPT' > /usr/local/bin/open5gs-install
#!/bin/bash
set -e
echo "=== Open5GS 5G SA Core Docker Installer (https://open5gs.org) ==="
if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker CLI not found in this container."
  echo "Opt in to the host socket (lab hosts only):"
  echo "  docker compose -f docker/compose.yaml -f docker/compose.docker-sock.yaml run --rm core-network"
  echo "Or run open5gs-install on the host instead."
  exit 1
fi
if [ ! -S /var/run/docker.sock ]; then
  echo "ERROR: /var/run/docker.sock is not mounted."
  echo "Use docker/compose.docker-sock.yaml (opt-in) or bind-mount the socket explicitly."
  exit 1
fi
mkdir -p /opt/telcosec/open5gs
cd /opt/telcosec/open5gs
OPEN5GS_DOCKER_SHA="1f3bcf73f926b5b7526ef3c41cd2b839c2b17ac3"
if [ ! -d "/opt/telcosec/open5gs/docker_open5gs/.git" ]; then
  git clone https://github.com/herlesupreeth/docker_open5gs
  git -C docker_open5gs checkout "$OPEN5GS_DOCKER_SHA" \
    || echo "WARNING: could not checkout $OPEN5GS_DOCKER_SHA — using clone HEAD"
fi
cd docker_open5gs
echo "Pulling Open5GS Docker images..."
docker compose pull || docker-compose pull
echo "Patching PLMN to test PLMN (MCC 001, MNC 01)..."
if [ -f .env ]; then
  sed -i 's/MCC=.*/MCC=001/g' .env
  sed -i 's/MNC=.*/MNC=01/g' .env
fi
echo ""
echo "Open5GS Dockerized environment installed."
echo "  Start:  sudo open5gs-start"
echo "  Stop:   sudo open5gs-stop"
OPEN5GS_SCRIPT
chmod +x /usr/local/bin/open5gs-install

# ─── 4. OAI UE first-run installer (from 10-install-telecom-advanced.sh) ───
cat << 'OAI_SCRIPT' > /usr/local/bin/oai-install
#!/bin/bash
set -e
echo "=== OpenAirInterface UE Install ==="
RADIO="BLADERF"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --radio)   RADIO="${2^^}"; shift 2 ;;
    --radio=*) RADIO="${1#*=}"; RADIO="${RADIO^^}"; shift ;;
    *)         shift ;;
  esac
done
case "$RADIO" in
  USRP|BLADERF|LMSSDR) ;;
  *) echo "Unknown --radio value: $RADIO. Options: USRP, BLADERF, LMSSDR"; exit 1 ;;
esac
if [ ! -d /opt/telcosec/oai ]; then
  git clone --depth 1 --branch 2026.w38 https://gitlab.eurecom.fr/oai/openairinterface5g.git /opt/telcosec/oai \
    || git clone --depth 1 https://gitlab.eurecom.fr/oai/openairinterface5g.git /opt/telcosec/oai
fi
cd /opt/telcosec/oai
source oaienv
echo "Building OAI UE for radio backend: $RADIO"
./cmake_targets/build_oai.sh -I --ue -w "$RADIO" 2>&1 | tee /tmp/oai-build.log
echo "OAI UE installed. Binaries in targets/bin/"
OAI_SCRIPT
chmod +x /usr/local/bin/oai-install

# ─── 5. gtp5g kernel-module helper (from 10-install-telecom-advanced.sh) ───
# See the HONEST LIMITATIONS header above — this genuinely cannot succeed in
# an unprivileged container against a mismatched kernel. The helper is
# installed anyway so the failure mode is a clear message, not "command not
# found", and so it works as documented when run with --privileged + a host
# /lib/modules mount and matching kernel headers.
cat << 'GTP5G_SCRIPT' > /usr/local/bin/gtp5g-load
#!/bin/bash
set -e
if [ ! -d /lib/modules/"$(uname -r)"/build ]; then
  echo "ERROR: no kernel headers for $(uname -r) inside this container."
  echo "gtp5g is a kernel module and must be built against the HOST kernel."
  echo "Run this on the host, or with --privileged and the host's"
  echo "/usr/src / /lib/modules mounted in. See docker/README.md."
  exit 1
fi
if [ ! -d /opt/telcosec/gtp5g ]; then
  echo "Cloning gtp5g source (v0.10.2)..."
  git clone --depth 1 --branch v0.10.2 https://github.com/free5gc/gtp5g /opt/telcosec/gtp5g \
    || git clone --depth 1 https://github.com/free5gc/gtp5g /opt/telcosec/gtp5g
fi
cd /opt/telcosec/gtp5g
[ -f gtp5g.ko ] || make -j"$(nproc)"
make install
modprobe gtp5g
echo "gtp5g module loaded: $(lsmod | grep gtp5g)"
GTP5G_SCRIPT
chmod +x /usr/local/bin/gtp5g-load

# ─── 6. 5Ghoul first-run installer (condensed from 09-install-5ghoul.sh) ───
cat << 'GHOUL_SCRIPT' > /usr/local/bin/5ghoul-install
#!/bin/bash
set -e
if [ -x /opt/telcosec/5ghoul-overlay/scripts/install.sh ]; then
  exec /opt/telcosec/5ghoul-overlay/scripts/install.sh "$@"
fi
echo "BladeRF/LimeSDR: use the telcochisel-5ghoul image (this core-network helper is the USRP-oriented fallback)."
INSTALL_DIR="/opt/telcosec/5ghoul"
RADIO="USRP"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --radio)   RADIO="${2^^}"; shift 2 ;;
    --radio=*) RADIO="${1#*=}"; RADIO="${RADIO^^}"; shift ;;
    *)         shift ;;
  esac
done
case "$RADIO" in
  USRP|BLADERF|LIMESDR) ;;
  *) echo "Unknown --radio value: $RADIO. Options: USRP, BLADERF, LIMESDR"; exit 1 ;;
esac
echo "=== 5Ghoul 5G NR Attack Framework Installer ==="
echo "https://github.com/asset-group/5ghoul-5g-nr-attacks"
echo "Radio backend: $RADIO   Build time: 20-60 min"
if [ ! -d "$INSTALL_DIR/.git" ]; then
  echo "[1/3] Cloning 5Ghoul repository (--recurse-submodules)..."
  git clone --depth 1 --recurse-submodules --shallow-submodules \
    https://github.com/asset-group/5ghoul-5g-nr-attacks "$INSTALL_DIR"
fi
cd "$INSTALL_DIR"
echo "[2/3] Running upstream requirements.sh..."
[ -f requirements.sh ] && bash requirements.sh || true
echo "[3/3] Running upstream build.sh (this is the 20-60 min step)..."
OAI_HW="USRP"
case "$RADIO" in
  BLADERF) OAI_HW="BLADERF" ;;
  LIMESDR) OAI_HW="LMSSDR" ;;
esac
if [ "$OAI_HW" != "USRP" ]; then
  while IFS= read -r -d '' f; do
    sed -i "s/-w USRP\\b/-w ${OAI_HW}/g" "$f"
  done < <(grep -rlZ --include='*.sh' --exclude-dir=.git -- '-w USRP' . || true)
fi
bash build.sh all 2>&1 | tee /tmp/5ghoul-build.log
echo ""
echo "5Ghoul built. See ${INSTALL_DIR} for run instructions."
echo "Add a test subscriber to Open5GS: sudo 5ghoul-add-subscriber"
GHOUL_SCRIPT
chmod +x /usr/local/bin/5ghoul-install

# 5Ghoul test-subscriber helper (from 09-install-5ghoul.sh; default 5Ghoul creds)
cat << 'EOF' > /usr/local/bin/5ghoul-add-subscriber
#!/bin/bash
if ! command -v open5gs-dbctl &>/dev/null; then
  echo "Open5GS is not installed. Run: sudo open5gs-install"
  exit 1
fi
echo "Adding 5Ghoul test subscriber to Open5GS..."
open5gs-dbctl add 001011234567890 465B5CE8B199B49FAA5F0A2EE238A6BC E8ED289DEBA952E4283B54E88E6183CA \
  || echo "Subscriber already exists."
echo "IMSI : 001011234567890"
echo "K    : 465B5CE8B199B49FAA5F0A2EE238A6BC"
echo "OPc  : E8ED289DEBA952E4283B54E88E6183CA"
EOF
chmod +x /usr/local/bin/5ghoul-add-subscriber

# ─── 7. Ownership & Healthcheck ──────────────────────────────────────────────
install_container_healthcheck
chown -R telcosec:telcosec "${TELCOSEC_OPT}" /etc/telcosec

echo "=== telcochisel-core-network installation complete ==="
echo "First-run helpers installed: srsran-install, open5gs-install,"
echo "oai-install, gtp5g-load, 5ghoul-install, 5ghoul-add-subscriber."
