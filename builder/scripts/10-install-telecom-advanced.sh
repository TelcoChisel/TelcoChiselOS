#!/bin/bash
set -e

echo "=== Installing Advanced Telecom Tools ==="

# Prevent git from blocking on credential prompts in non-interactive CI/chroot builds.
# GIT_TERMINAL_PROMPT=0 stops the terminal askpass; credential.helper='' disables
# the credential manager (which can auto-fill username and then hang waiting for password);
# GIT_ASKPASS=/bin/false makes any remaining askpass call return immediately with failure.
export GIT_TERMINAL_PROMPT=0
export GIT_ASKPASS=/bin/false
git config --global credential.helper ''

TELCOSEC_OPT=/opt/telcosec
mkdir -p "$TELCOSEC_OPT"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/record-tool.sh
source "${SCRIPT_DIR}/lib/record-tool.sh"
# shellcheck source=lib/pip-retry.sh
source "${SCRIPT_DIR}/lib/pip-retry.sh"
# shellcheck source=lib/build-tool.sh
source "${SCRIPT_DIR}/lib/build-tool.sh"

# ─── Pre-clone all repos in parallel before starting any builds ──────────────
# Best-effort prefetch (deferred-installer pattern — first-run helpers
# re-clone if missing), but failures are reported so a silently missing
# repo is visible in the build log.
echo "  Cloning repositories in parallel (pinned refs where available)..."
mkdir -p "$TELCOSEC_OPT"
# Args: url dir [tag/branch] — see lib/build-tool.sh _clone_git
clone_bg https://github.com/aligungr/UERANSIM                     "${TELCOSEC_OPT}/ueransim"       v3.3.0
clone_bg https://github.com/fgsect/scat                           "${TELCOSEC_OPT}/scat"           v2.1.1
clone_bg https://github.com/scateu/kalibrate-hackrf               "${TELCOSEC_OPT}/kalibrate-gsm"
clone_bg https://github.com/Synacktiv-contrib/Modmobmap           "${TELCOSEC_OPT}/modmobmap"
clone_bg https://github.com/srlabs/SIMtester                      "${TELCOSEC_OPT}/simtester"
clone_bg https://github.com/yatebts/yatebts                       "${TELCOSEC_OPT}/yatebts"
clone_bg https://github.com/RangeNetworks/openbts                 "${TELCOSEC_OPT}/openbts"        v4.0.0
clone_bg https://github.com/srsran/srsgui                         "${TELCOSEC_OPT}/srsgui"
clone_bg https://github.com/Evrytania/LTE-Cell-Scanner            "${TELCOSEC_OPT}/lte-cellscanner"
clone_bg https://github.com/SysSec-KAIST/LTESniffer               "${TELCOSEC_OPT}/ltesniffer"     LTESniffer-v2.1.0
clone_bg https://github.com/free5gc/gtp5g                         "${TELCOSEC_OPT}/gtp5g"          v0.10.2
clone_bg https://github.com/TelcoSec-Tools/RDNSx                  "${TELCOSEC_OPT}/rdnsx"
clone_bg https://github.com/rlaager/docsis                        "${TELCOSEC_OPT}/docsis"
clone_bg https://github.com/fkie-cad/FALCON                       "${TELCOSEC_OPT}/falcon"
if wait_clones "prefetch"; then
  echo "  Parallel clone complete."
else
  echo "  WARNING: some prefetch clones failed — affected first-run helpers will re-clone on demand." >&2
fi

# Test PLMN constants (ITU-T standard test network)
MCC=001
MNC=01

# ─── Global PLMN config ──────────────────────────────────────────────────────
mkdir -p /etc/telcosec
cat > /etc/telcosec/plmn.conf << EOF
# TelcoSec test PLMN configuration (ITU-T test network 001-01)
MCC=${MCC}
MNC=${MNC}
PLMN=${MCC}${MNC}
TAC=0x0001
EOF

# ─── A. UERANSIM (5G UE/gNB simulator) ─────────────────────────────────────
echo "  Installing UERANSIM..."
# apt-cache show only proves the TelcoSec repo is listed, not that the
# install will succeed — if the apt install fails under set -e we'd abort
# the whole build even though the cloned source build is right there as a
# fallback. So: try apt, fall through to the source build on failure.
UERANSIM_APT_OK=0
if dpkg-query -W ueransim 2>/dev/null; then
  echo "    UERANSIM already installed via APT."
  UERANSIM_APT_OK=1
elif apt-cache show ueransim >/dev/null 2>&1 && apt-get install -y ueransim; then
  UERANSIM_APT_OK=1
fi

if [ "$UERANSIM_APT_OK" != "1" ]; then
  if [ -d "${TELCOSEC_OPT}/ueransim" ]; then
    cd "${TELCOSEC_OPT}/ueransim"
    mkdir -p build && cd build
    cmake -DCMAKE_BUILD_TYPE=Release .. >/dev/null 2>&1 || true
    make -j"$(nproc)" >/dev/null 2>&1 || true
    [ -f nr-gnb ] && ln -sf "${TELCOSEC_OPT}/ueransim/build/nr-gnb" /usr/local/bin/nr-gnb || true
    [ -f nr-ue ]  && ln -sf "${TELCOSEC_OPT}/ueransim/build/nr-ue"  /usr/local/bin/nr-ue  || true
    [ -f nr-cli ] && ln -sf "${TELCOSEC_OPT}/ueransim/build/nr-cli" /usr/local/bin/nr-cli || true

    # Deploy test PLMN config templates
    mkdir -p /etc/telcosec/ueransim
    cp ../config/open5gs-gnb.yaml /etc/telcosec/ueransim/gnb.yaml   2>/dev/null || true
    cp ../config/open5gs-ue.yaml  /etc/telcosec/ueransim/ue.yaml    2>/dev/null || true
    # Patch MCC/MNC into configs
    sed -i "s/mcc: '999'/mcc: '${MCC}'/g; s/mcc: 999/mcc: ${MCC}/g" \
      /etc/telcosec/ueransim/*.yaml 2>/dev/null || true
    sed -i "s/mnc: '70'/mnc: '${MNC}'/g;  s/mnc: 70/mnc: ${MNC}/g" \
      /etc/telcosec/ueransim/*.yaml 2>/dev/null || true
    chown -R telcosec:telcosec /etc/telcosec/ueransim
    cd /
  fi
fi
record_tool "UERANSIM" "/usr/local/bin/nr-ue" "5g"

# ─── B. SCAT (Diag protocol / Samsung/Qualcomm log decoder) ─────────────────
echo "  Installing SCAT..."
pip_retry install scat
if [ -f "${TELCOSEC_OPT}/scat/setup.py" ] || [ -f "${TELCOSEC_OPT}/scat/pyproject.toml" ]; then
  pip_retry install "${TELCOSEC_OPT}/scat"
fi
record_tool "SCAT" "$(command -v scat 2>/dev/null || echo '/usr/local/bin/scat')" "baseband"

# ─── C. Osmocom tools (GSM/2G BTS stack) ────────────────────────────────────
echo "  Installing Osmocom tools..."
# Try the Osmocom APT repo first (added by 00-install-all-packages.sh).
# If the repo key wasn't imported successfully the list file won't exist,
# so we fall back to source builds / skip gracefully.
OSMOCOM_PKGS="osmo-bts-virtual osmo-bts-trx osmo-hlr osmo-msc osmo-bsc osmo-sgsn libosmocore-utils libosmocore-dev libosmo-sigtran-dev"
if [ -f /etc/apt/sources.list.d/osmocom.list ]; then
  apt-get update -qq 2>/dev/null || true
  # shellcheck disable=SC2086
  apt-get install -y --no-install-recommends $OSMOCOM_PKGS 2>/dev/null || \
    echo "  WARNING: Some Osmocom packages unavailable — continuing without them"
else
  echo "  Osmocom APT repo not available — skipping binary package install."
  echo "  Osmocom tools can be compiled from source: https://osmocom.org/projects/cellular-infrastructure/wiki"
fi

# ─── D. Kalibrate-GSM (GSM frequency calibration) ──────────────────────────
echo "  Installing Kalibrate-GSM..."
[ -d "${TELCOSEC_OPT}/kalibrate-gsm" ] || clone_if_missing https://github.com/scateu/kalibrate-hackrf "${TELCOSEC_OPT}/kalibrate-gsm" 2>/dev/null || true
if [ -d "${TELCOSEC_OPT}/kalibrate-gsm" ]; then
  cd "${TELCOSEC_OPT}/kalibrate-gsm"
  ./bootstrap.sh 2>/dev/null || autoreconf -fi
  CONDA_SDR_PKG="${TELCOSEC_OPT}/miniconda/envs/telcosec-sdr/lib/pkgconfig"
  [ -d "$CONDA_SDR_PKG" ] && export PKG_CONFIG_PATH="${CONDA_SDR_PKG}:${PKG_CONFIG_PATH:-}"
  ./configure && nice -n 10 make -j"$(get_build_procs)"
  [ -f src/kal ] && cp -f src/kal /usr/local/bin/kal-gsm || true
  cd /
fi
record_tool "kalibrate-gsm" "/usr/local/bin/kal-gsm" "2g"

# ─── E. Modmobmap (cell mapping via AT commands) ────────────────────────────
echo "  Installing Modmobmap..."
[ -d "${TELCOSEC_OPT}/modmobmap" ] || clone_if_missing https://github.com/Synacktiv-contrib/Modmobmap "${TELCOSEC_OPT}/modmobmap" 2>/dev/null || true
if [ -d "${TELCOSEC_OPT}/modmobmap" ]; then
  pip_retry install -r "${TELCOSEC_OPT}/modmobmap/requirements.txt" \
    --break-system-packages
  cat > /usr/local/bin/modmobmap << 'SCRIPT'
#!/bin/bash
python3 /opt/telcosec/modmobmap/modmobmap.py "$@"
SCRIPT
  chmod +x /usr/local/bin/modmobmap
fi
record_tool "Modmobmap" "/usr/local/bin/modmobmap" "2g"

# ─── F. SIMTester (Java SIM card security testing) ──────────────────────────
echo "  Installing SIMTester..."
if [ -d "${TELCOSEC_OPT}/simtester" ]; then
  # The srlabs/SIMtester repo provides pre-compiled binaries instead of Maven source.
  JAR=$(find "${TELCOSEC_OPT}/simtester/binaries" -name "SIMTester.jar" | sort -V | tail -n 1)
  if [ -n "$JAR" ]; then
    cat > /usr/local/bin/simtester << EOF
#!/bin/bash
exec java -jar ${JAR} "\$@"
EOF
    chmod +x /usr/local/bin/simtester
  else
    echo "  WARNING: SIMTester.jar not found in binaries folder."
  fi
fi
record_tool "SIMTester" "/usr/local/bin/simtester" "sim"

# ─── G. YateBTS + Yate (GSM/UMTS BTS with BladeRF support) ─────────────────
echo "  Installing YateBTS (deferred compile — providing installer helper)..."

cat > /usr/local/bin/yatebts-install << 'SCRIPT'
#!/bin/bash
set -e
echo "=== YateBTS Full Install (BladeRF optimized) ==="
if [ ! -d /opt/telcosec/yatebts ]; then
  echo "Cloning YateBTS source..."
  git clone --depth 1 https://github.com/yatebts/yatebts /opt/telcosec/yatebts
fi
cd /opt/telcosec/yatebts

# Install Yate first
if [ ! -d /opt/telcosec/yate ]; then
  apt-get install -y yate yate-dev 2>/dev/null || \
    git clone --depth 1 https://github.com/YateTEL/yate /opt/telcosec/yate
  if [ -d /opt/telcosec/yate ] && [ ! -f /usr/local/bin/yate ]; then
    cd /opt/telcosec/yate
    ./autogen.sh && ./configure && make -j$(nproc) && make install
    cd -
  fi
fi

# Build YateBTS against Yate
cd /opt/telcosec/yatebts
./autogen.sh && ./configure && make -j$(nproc) && make install

# BladeRF / LimeSDR configs
mkdir -p /etc/yate
cat > /etc/yate/ybladerf.conf << EOF
[general]
; BladeRF A4 configuration for YateBTS
rx_latency=3
tx_latency=3
threads=2
loopback=none
EOF
cat > /etc/yate/ylms.conf << EOF
[general]
; LimeSDR Mini configuration for YateBTS
rx_latency=3
tx_latency=3
threads=2
loopback=none
EOF

# Install systemd unit files for Yate and YateBTS service management
cat << 'EOF' | tee /etc/systemd/system/yate.service
[Unit]
Description=Yate Telephony Engine / YateBTS Daemon
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/yate -s -l /var/log/yate.log
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

cat << 'EOF' | tee /etc/systemd/system/yatebts.service
[Unit]
Description=YateBTS GSM Base Station Service
After=network.target yate.service
Requires=yate.service

[Service]
Type=simple
ExecStart=/usr/local/bin/yate -s -l /var/log/yatebts.log -c /etc/yate
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload 2>/dev/null || true

echo "YateBTS installed. Start with: sudo systemctl start yatebts (or: sudo yate -s -l /var/log/yate.log)"
SCRIPT
chmod +x /usr/local/bin/yatebts-install

# ─── H. OpenBTS (GSM BTS, deferred compile) ─────────────────────────────────
echo "  Installing OpenBTS helper..."

cat > /usr/local/bin/openbts-install << 'SCRIPT'
#!/bin/bash
set -e
echo "=== OpenBTS Install ==="
if [ ! -d /opt/telcosec/openbts ]; then
  echo "Cloning OpenBTS source (v4.0.0)..."
  git clone --depth 1 --branch v4.0.0 https://github.com/RangeNetworks/openbts /opt/telcosec/openbts \
    || git clone --depth 1 https://github.com/RangeNetworks/openbts /opt/telcosec/openbts
fi
cd /opt/telcosec/openbts
# OpenBTS requires libosip2, libexosip2, liba53
apt-get install -y libosip2-dev libexosip2-dev
./autogen.sh && ./configure && make -j$(nproc) && make install
echo "OpenBTS installed. Configure: /etc/OpenBTS/OpenBTS.conf"
SCRIPT
chmod +x /usr/local/bin/openbts-install

# ─── I. srsGUI (visualization for srsRAN metrics) ───────────────────────────
echo "  Installing srsGUI..."
[ -d "${TELCOSEC_OPT}/srsgui" ] || clone_if_missing https://github.com/srsran/srsgui "${TELCOSEC_OPT}/srsgui" 2>/dev/null || true
if [ -d "${TELCOSEC_OPT}/srsgui" ]; then
  cd "${TELCOSEC_OPT}/srsgui"
  mkdir -p build && cd build
  cmake .. -DCMAKE_BUILD_TYPE=Release 2>&1 | tail -3
  # srsGUI CMakeLists.txt adds test subdirs unconditionally; build only the main target
  # to avoid test compilation failures (missing Qt test harness).
  make -j"$(nproc)" srsgui 2>&1 | tail -5 || \
    make -j"$(nproc)" 2>&1 | tail -5 || true
  cd /
fi
record_tool "srsGUI" "$(find ${TELCOSEC_OPT}/srsgui/build -name 'libsrsgui.so' 2>/dev/null | head -1)" "core"

# ─── J. LTE-CellScanner ──────────────────────────────────────────────────────
echo "  Installing LTE-CellScanner..."
[ -d "${TELCOSEC_OPT}/lte-cellscanner" ] || clone_if_missing https://github.com/Evrytania/LTE-Cell-Scanner "${TELCOSEC_OPT}/lte-cellscanner" 2>/dev/null || true
if [ -d "${TELCOSEC_OPT}/lte-cellscanner" ]; then
  dpkg -s libitpp-dev &>/dev/null || apt-get install -y libitpp-dev 2>/dev/null || true
  cd "${TELCOSEC_OPT}/lte-cellscanner"
  mkdir -p build && cd build
  export CFLAGS="-Wno-error -fcommon"
  export CXXFLAGS="-Wno-error -fcommon"
  cmake .. 2>&1 | tail -3
  nice -n 10 make -j"$(get_build_procs)" 2>&1 | tail -5 || true
  [ -f src/CellSearch ] && ln -sf "${TELCOSEC_OPT}/lte-cellscanner/build/src/CellSearch" \
    /usr/local/bin/LTE-CellSearch || true
  cd /
fi
record_tool "LTE-CellScanner" "/usr/local/bin/LTE-CellSearch" "4g"

# ─── K. LTESniffer ───────────────────────────────────────────────────────────
echo "  Installing LTESniffer..."
[ -d "${TELCOSEC_OPT}/ltesniffer" ] || clone_if_missing https://github.com/SysSec-KAIST/LTESniffer "${TELCOSEC_OPT}/ltesniffer" 2>/dev/null || true
if [ -d "${TELCOSEC_OPT}/ltesniffer" ]; then
  cd "${TELCOSEC_OPT}/ltesniffer"
  mkdir -p build && cd build
  export CFLAGS="-Wno-error -fcommon -fpermissive"
  export CXXFLAGS="-Wno-error -fcommon -fpermissive -std=c++14"
  cmake .. -DCMAKE_BUILD_TYPE=Release 2>&1 | tail -5
  nice -n 10 make -j"$(get_build_procs)" 2>&1 | tail -10 || make 2>&1 | tail -10 || true
  
  # Locate the compiled LTESniffer binary in build tree or src
  SNIFFER_BIN=$(find . -type f \( -name "LTESniffer" -o -name "ltesniffer" \) 2>/dev/null | head -1)
  if [ -n "$SNIFFER_BIN" ] && [ -f "$SNIFFER_BIN" ]; then
    ln -sf "${TELCOSEC_OPT}/ltesniffer/build/${SNIFFER_BIN#./}" /usr/local/bin/ltesniffer
    echo "  LTESniffer binary linked: ${SNIFFER_BIN}"
  elif [ -f "${TELCOSEC_OPT}/ltesniffer/src/LTESniffer" ]; then
    ln -sf "${TELCOSEC_OPT}/ltesniffer/src/LTESniffer" /usr/local/bin/ltesniffer
  else
    echo "  WARNING: LTESniffer binary not found after compilation"
  fi
  cd /
fi
record_tool "LTESniffer" "/usr/local/bin/ltesniffer" "4g"

# ─── L. 5G GTP kernel module (gtp5g) ─────────────────────────────────────────
echo "  Installing gtp5g kernel module..."
# Kernel module cannot be compiled inside the chroot (no kernel headers).
# gtp5g-load compiles and inserts it at first run on the live system.
# Always create the helper — it clones the source if the build-time clone was skipped.
cat > /usr/local/bin/gtp5g-load << 'GSCRIPT'
#!/bin/bash
set -e
# Build (if needed) and load the 5G GTP kernel module
if [ ! -d /opt/telcosec/gtp5g ]; then
  echo "Cloning gtp5g source (v0.10.2)..."
  git clone --depth 1 --branch v0.10.2 https://github.com/free5gc/gtp5g /opt/telcosec/gtp5g \
    || git clone --depth 1 https://github.com/free5gc/gtp5g /opt/telcosec/gtp5g
fi
cd /opt/telcosec/gtp5g
[ -f gtp5g.ko ] || make -j$(nproc)
make install
modprobe gtp5g
echo "gtp5g module loaded: $(lsmod | grep gtp5g)"
GSCRIPT
chmod +x /usr/local/bin/gtp5g-load

# ─── M. GTP & Telecom Python toolkit ─────────────────────────────────────────
echo "  Installing GTP & Telecom Python tools..."
pip_retry install pygtp python-messaging smpplib --break-system-packages

# ─── N. OAI UE installer helper ──────────────────────────────────────────────
echo "  Installing OAI-UE helper script..."
cat > /usr/local/bin/oai-install << 'SCRIPT'
#!/bin/bash
set -e
echo "=== OpenAirInterface UE Install ==="

# Radio backend, passed straight through to build_oai.sh's -w flag — same
# --radio argument style as 5ghoul-install, defaulting to BLADERF. Previously
# hardcoded with a comment telling the user to hand-edit this file for
# USRP/LimeSDR; matches OAI's own -w value naming (LMSSDR, not LIMESDR).
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

# Clone-if-missing guard (matches every other first-run helper: srsran-install,
# yatebts-install, openbts-install, gtp5g-load, 5ghoul-install). Without it,
# re-running this script after a partial/failed first attempt aborts
# immediately with "destination path already exists" under set -e.
if [ ! -d /opt/telcosec/oai ]; then
  git clone --depth 1 --branch 2026.w38 https://gitlab.eurecom.fr/oai/openairinterface5g.git /opt/telcosec/oai \
    || git clone --depth 1 https://gitlab.eurecom.fr/oai/openairinterface5g.git /opt/telcosec/oai
fi
cd /opt/telcosec/oai
source oaienv
echo "Building OAI UE for radio backend: $RADIO"
./cmake_targets/build_oai.sh -I --ue -w "$RADIO" 2>&1 | tee /tmp/oai-build.log
echo "OAI UE installed. Binaries in targets/bin/"
SCRIPT
chmod +x /usr/local/bin/oai-install

# ─── O. BSS management helper scripts (Nokia/Ericsson/Huawei) ────────────────
echo "  Installing BSS management scripts..."
mkdir -p "${TELCOSEC_OPT}/bss-tools"

cat > /usr/local/bin/nokia-netact-cli << 'SCRIPT'
#!/bin/bash
# Nokia NetAct CLI wrapper (SNMP + SSH)
# Usage: nokia-netact-cli <host> [community]
HOST=${1:-127.0.0.1}; COMMUNITY=${2:-public}
snmpwalk -v2c -c "$COMMUNITY" "$HOST" iso.3.6.1.2.1.1 2>/dev/null || \
  ssh -o StrictHostKeyChecking=no "netact@${HOST}" 2>/dev/null
SCRIPT

cat > /usr/local/bin/ericsson-enm-cli << 'SCRIPT'
#!/bin/bash
# Ericsson ENM CLI wrapper (SSH scripting)
# Usage: ericsson-enm-cli <host> [user]
HOST=${1:-127.0.0.1}; USER=${2:-nmsadm}
ssh -o StrictHostKeyChecking=no "${USER}@${HOST}"
SCRIPT

cat > /usr/local/bin/huawei-u2000-cli << 'SCRIPT'
#!/bin/bash
# Huawei U2000 CLI wrapper (telnet/SSH)
# Usage: huawei-u2000-cli <host> [port]
HOST=${1:-127.0.0.1}; PORT=${2:-22}
ssh -p "$PORT" -o StrictHostKeyChecking=no "mscuser@${HOST}" 2>/dev/null || \
  telnet "$HOST" "$PORT"
SCRIPT

chmod +x /usr/local/bin/nokia-netact-cli \
         /usr/local/bin/ericsson-enm-cli \
         /usr/local/bin/huawei-u2000-cli

# ─── P. Open5GS test PLMN patch (only if installed) ─────────────────────────
if [ -d /etc/open5gs ]; then
  echo "  Patching Open5GS to use test PLMN ${MCC}/${MNC}..."
  for CFG in /etc/open5gs/*.yaml; do
    [ -f "$CFG" ] || continue
    sed -i \
      -e "s/mcc: '901'/mcc: '${MCC}'/g" \
      -e "s/mnc: '70'/mnc: '${MNC}'/g"  \
      -e "s/mcc: 901/mcc: ${MCC}/g"     \
      -e "s/mnc: 70/mnc: ${MNC}/g"      \
      "$CFG" 2>/dev/null || true
  done
else
  echo "  Open5GS not installed — skipping PLMN patch (run sudo open5gs-install first)"
fi

# ─── Q. srsRAN test PLMN patch ───────────────────────────────────────────────
echo "  Patching srsRAN config to use test PLMN..."
for CFG in /etc/srsran/*.conf; do
  [ -f "$CFG" ] || continue
  sed -i \
    -e "s/^mcc\s*=.*/mcc = ${MCC}/" \
    -e "s/^mnc\s*=.*/mnc = ${MNC}/" \
    "$CFG" 2>/dev/null || true
done

# ─── R. RDNSx (Rapid DNS Reverse Resolver) ──────────────────────────────────
echo "  Installing RDNSx..."
if dpkg-query -W rdnsx 2>/dev/null; then
  echo "    RDNSx already installed via APT."
elif apt-cache show rdnsx >/dev/null 2>&1 && apt-get install -y rdnsx; then
  echo "    RDNSx installed via APT."
else
  if [ -d "${TELCOSEC_OPT}/rdnsx" ]; then
    cd "${TELCOSEC_OPT}/rdnsx"
    export CARGO_HOME=/usr/local/cargo
    export PATH="${CARGO_HOME}/bin:$PATH"
    command -v cargo &>/dev/null || apt-get install -y cargo rustc build-essential pkg-config libssl-dev 2>/dev/null || true
    if command -v cargo &>/dev/null; then
      echo "    Compiling RDNSx release binary..."
      cargo build --release --bin rdnsx -j"$(get_build_procs)" 2>&1 | tail -5 || true
    fi
    if [ -f target/release/rdnsx ]; then
      ln -sf "${TELCOSEC_OPT}/rdnsx/target/release/rdnsx" /usr/local/bin/rdnsx
    else
      # Create self-healing runtime launcher for offline/minimal builds
      cat > /usr/local/bin/rdnsx << 'LAUNCHER'
#!/usr/bin/env bash
set -e
RDNSX_DIR="/opt/telcosec/rdnsx"
RDNSX_BIN="${RDNSX_DIR}/target/release/rdnsx"

if [ -x "$RDNSX_BIN" ]; then
  exec "$RDNSX_BIN" "$@"
fi

echo "=== RDNSx: First-time setup / build required ==="
if ! command -v cargo &>/dev/null; then
  echo "[!] Cargo / Rust toolchain not detected."
  if [ -x /usr/local/bin/telcosec-install-rust ]; then
    echo "[*] Installing Rust toolchain via system installer..."
    sudo /usr/local/bin/telcosec-install-rust
    export CARGO_HOME=/usr/local/cargo
    export PATH="${CARGO_HOME}/bin:$PATH"
  else
    echo "[*] Installing cargo via apt..."
    sudo apt-get update -qq && sudo apt-get install -y cargo rustc build-essential pkg-config libssl-dev
  fi
fi

if [ -d "$RDNSX_DIR" ]; then
  echo "[*] Compiling RDNSx (this may take a minute)..."
  cd "$RDNSX_DIR"
  cargo build --release --bin rdnsx
  if [ -f "$RDNSX_BIN" ]; then
    sudo ln -sf "$RDNSX_BIN" /usr/local/bin/rdnsx
    echo "[+] RDNSx successfully built and linked to /usr/local/bin/rdnsx!"
    exec "$RDNSX_BIN" "$@"
  fi
fi

echo "[-] Error: Failed to locate or compile RDNSx in ${RDNSX_DIR}." >&2
exit 1
LAUNCHER
      chmod +x /usr/local/bin/rdnsx
    fi
    cd /
  fi
fi
record_tool "RDNSx" "/usr/local/bin/rdnsx" "adsl"

# ─── S. Broadband & ADSL Exploitation Tools ─────────────────────────────────
echo "  Installing Broadband & ADSL Exploitation Tools..."

# 1. Asleap (PPPoE / MS-CHAPv2 offline cracker)
if [ ! -d "${TELCOSEC_OPT}/asleap" ]; then
  git clone --depth 1 https://github.com/joswr1ght/asleap "${TELCOSEC_OPT}/asleap" 2>/dev/null || true
fi
if [ -d "${TELCOSEC_OPT}/asleap" ]; then
  cd "${TELCOSEC_OPT}/asleap"
  # Patch legacy POSIX setkey/encrypt in utils.c to use OpenSSL DES
  if grep -q "setkey((char \*)crypt_key)" utils.c 2>/dev/null; then
    python3 -c '
with open("utils.c", "r") as f:
    c = f.read()
old = """void DesEncrypt(unsigned char *clear, unsigned char *key, unsigned char *cipher)
{
    unsigned char des_key[8];
    unsigned char crypt_key[66];
    unsigned char des_input[66];

    MakeKey(key, des_key);

    Expand(des_key, crypt_key);
    setkey((char *)crypt_key);

    Expand(clear, des_input);
    encrypt((char *)des_input, 0);
    Collapse(des_input, cipher);
}"""
new = """#include <openssl/des.h>
void DesEncrypt(unsigned char *clear, unsigned char *key, unsigned char *cipher)
{
    DES_key_schedule schedule;
    DES_cblock des_key;
    MakeKey(key, des_key);
    DES_set_key((DES_cblock *)des_key, &schedule);
    DES_ecb_encrypt((DES_cblock *)clear, (DES_cblock *)cipher, &schedule, DES_ENCRYPT);
}"""
if old in c:
    with open("utils.c", "w") as f:
        f.write(c.replace(old, new))
' 2>/dev/null || true
  fi
  sed -i 's/-lxcrypt//g' Makefile 2>/dev/null || true
  make clean 2>/dev/null || true
  nice -n 10 make -j"$(get_build_procs)" 2>&1 | tail -5 || make 2>&1 | tail -5 || true
  [ -f asleap ] && ln -sf "${TELCOSEC_OPT}/asleap/asleap" /usr/local/bin/asleap || true
  [ -f genkeys ] && ln -sf "${TELCOSEC_OPT}/asleap/genkeys" /usr/local/bin/genkeys || true
  cd /
fi
record_tool "Asleap" "/usr/local/bin/asleap" "adsl"

# 2. snmp-check (Kali Linux native SNMP enumerator)
if [ ! -f /usr/local/bin/snmp-check ]; then
  wget -q https://gitlab.com/kalilinux/packages/snmpcheck/-/raw/kali/master/snmpcheck-1.9.rb -O /usr/local/bin/snmp-check || true
  if [ -s /usr/local/bin/snmp-check ]; then
    chmod +x /usr/local/bin/snmp-check
  fi
fi

# 3. RouterSploit (Embedded device exploitation framework)
if [ ! -d "${TELCOSEC_OPT}/routersploit" ]; then
  git clone --depth 1 --branch v3.4.7 https://github.com/threat9/routersploit "${TELCOSEC_OPT}/routersploit" 2>/dev/null \
    || git clone --depth 1 https://github.com/threat9/routersploit "${TELCOSEC_OPT}/routersploit" 2>/dev/null || true
fi
if [ -d "${TELCOSEC_OPT}/routersploit" ]; then
  cd "${TELCOSEC_OPT}/routersploit"
  pip_retry install -r requirements.txt --break-system-packages
  cat > /usr/local/bin/routersploit << 'SCRIPT'
#!/bin/bash
python3 /opt/telcosec/routersploit/rsf.py "$@"
SCRIPT
  chmod +x /usr/local/bin/routersploit
  cd /
fi
record_tool "RouterSploit" "/usr/local/bin/routersploit" "adsl"

# 4. DOCSIS config tool
if [ -d "${TELCOSEC_OPT}/docsis" ]; then
  cd "${TELCOSEC_OPT}/docsis"
  ./autogen.sh && ./configure && make -j"$(nproc)" 2>&1 | tail -5 || true
  make install || true
  cd /
fi
record_tool "docsis" "/usr/local/bin/docsis" "adsl"

# 5. VoIP Hopper (Voice VLAN hopping security assessment tool)
if [ ! -d "${TELCOSEC_OPT}/voiphopper" ]; then
  git clone --depth 1 https://github.com/hmgh0st/voiphopper.git "${TELCOSEC_OPT}/voiphopper" 2>/dev/null || \
  git clone --depth 1 https://gitlab.com/kalilinux/packages/voiphopper.git "${TELCOSEC_OPT}/voiphopper" 2>/dev/null || \
  git clone --depth 1 https://github.com/ik-5/voiphopper "${TELCOSEC_OPT}/voiphopper" 2>/dev/null || true
fi
if [ -d "${TELCOSEC_OPT}/voiphopper" ]; then
  cd "${TELCOSEC_OPT}/voiphopper"
  gcc -O2 -Wall voiphopper.c -o voiphopper -lpcap 2>/dev/null || make 2>/dev/null || true
  if [ -f voiphopper ]; then
    ln -sf "${TELCOSEC_OPT}/voiphopper/voiphopper" /usr/local/bin/voiphopper
  fi
  cd /
fi
record_tool "voiphopper" "/usr/local/bin/voiphopper" "voip"

# 6. rtpbleed (RTP stream bleeding and leaky media proxy auditor)
cat << 'EOF' | tee /usr/local/bin/rtpbleed > /dev/null
#!/usr/bin/env python3
"""
RTP Bleed / Leaky Media Proxy Security Auditor
Audits target RTP proxy ports for unauthenticated audio leaking.
"""
import sys
import socket
import argparse
import time

def audit_rtp(target, start_port, end_port, timeout=1.0):
    print(f"[*] Scanning {target} UDP ports {start_port}-{end_port} for leaky RTP streams...")
    found = 0
    for port in range(start_port, end_port + 1, 2):
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(timeout)
        try:
            dummy_rtp = b"\x80\x00\x00\x01\x00\x00\x00\x00\x12\x34\x56\x78"
            sock.sendto(dummy_rtp, (target, port))
            data, addr = sock.recvfrom(2048)
            if data and len(data) >= 12:
                v = (data[0] >> 6) & 0x3
                pt = data[1] & 0x7F
                print(f"[!] LEAK DETECTED: {target}:{port} responded with {len(data)} bytes (RTP v{v}, PT={pt})")
                found += 1
        except (socket.timeout, ConnectionRefusedError, OSError):
            pass
        finally:
            sock.close()
    print(f"[*] Scan finished. Leaky ports identified: {found}")

def main():
    parser = argparse.ArgumentParser(description="RTP Bleed Security Scanner")
    parser.add_argument("-t", "--target", required=True, help="Target SBC or RTPproxy IP/host")
    parser.add_argument("-p", "--ports", default="10000-20000", help="UDP port range (default: 10000-20000)")
    parser.add_argument("--timeout", type=float, default=0.5, help="Socket timeout in seconds")
    args = parser.parse_args()
    
    parts = args.ports.split("-")
    start_p = int(parts[0])
    end_p = int(parts[1]) if len(parts) > 1 else start_p
    audit_rtp(args.target, start_p, end_p, args.timeout)

if __name__ == "__main__":
    main()
EOF
chmod +x /usr/local/bin/rtpbleed
record_tool "rtpbleed" "/usr/local/bin/rtpbleed" "voip"


# ─── T. Falcon GUI (LTE Network Analyzer) ──────────────────────────────────
echo "  Installing Falcon GUI..."
[ -d "${TELCOSEC_OPT}/falcon" ] || clone_if_missing https://github.com/falkenber9/falcon.git "${TELCOSEC_OPT}/falcon" 2>/dev/null || \
clone_if_missing https://github.com/fkie-cad/FALCON "${TELCOSEC_OPT}/falcon" 2>/dev/null || true
if [ -d "${TELCOSEC_OPT}/falcon" ]; then
  cd "${TELCOSEC_OPT}/falcon"
  mkdir -p build && cd build
  cmake .. -DCMAKE_BUILD_TYPE=Release 2>&1 | tail -3
  nice -n 10 make -j"$(get_build_procs)" 2>&1 | tail -5 || true
  [ -f falcon ] && ln -sf "${TELCOSEC_OPT}/falcon/build/falcon" /usr/local/bin/falcon || true
  cd /
fi
record_tool "Falcon" "/usr/local/bin/falcon" "4g"

# ─── Final ownership (single pass, replaces per-tool chowns) ─────────────────
chown -R telcosec:telcosec "${TELCOSEC_OPT}"

echo "=== Advanced Telecom Tools installation complete ==="
