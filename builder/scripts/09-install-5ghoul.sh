#!/bin/bash
set -e

echo "=== Installing 5Ghoul 5G NR Attack Framework Dependencies ==="
# 5Ghoul (https://github.com/asset-group/5ghoul-5g-nr-attacks) uses OpenAirInterface
# as the rogue gNB. Supported radios: USRP B210 (primary), BladeRF A4, and LimeSDR Mini.
# All system deps are installed here during ISO build; the repo clone + compilation is
# deferred to first-run to keep ISO build time reasonable. No VM support.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/pip-retry.sh
source "${SCRIPT_DIR}/lib/pip-retry.sh"

# Skip apt operations — handled by 00-install-all-packages.sh
if [ ! -f /tmp/.packages-installed ]; then
  echo "WARNING: Running standalone (packages not pre-installed)"
  # shellcheck source=lib/packages.sh
  source "${SCRIPT_DIR}/lib/packages.sh"
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    "${PKGS_5GHOUL_BUILD[@]}" \
    "${PKGS_5GHOUL_RUNTIME[@]}" \
    "${PKGS_5GHOUL_REQS[@]}"
fi

# ── Python tooling ───────────────────────────────────────────────────────
sudo_pip_retry install --break-system-packages \
  colorlog \
  pyzmq \
  pycryptodome \
  construct \
  pyshark

# ── Pre-fetch 5Ghoul repo (best-effort for air-gapped / offline support) ──────
if [ ! -d /opt/telcosec/5ghoul/.git ]; then
  echo "Pre-fetching 5Ghoul repository (best-effort)..."
  mkdir -p /opt/telcosec
  git clone --depth 1 --recurse-submodules --shallow-submodules \
    https://github.com/asset-group/5ghoul-5g-nr-attacks \
    /opt/telcosec/5ghoul 2>/dev/null || true
  if [ -d /opt/telcosec/5ghoul/.git ]; then
    chown -R telcosec:plugdev /opt/telcosec/5ghoul || true
    echo "  5Ghoul repository pre-fetched successfully."
  else
    echo "  5Ghoul pre-fetch skipped or offline; will clone on first run."
  fi
fi

# ── Open5GS TUN interface (ogstun) for UPF user-plane traffic ────────────────
cat << 'EOF' | sudo tee /etc/systemd/network/99-ogstun.netdev
[NetDev]
Name=ogstun
Kind=tun
EOF

cat << 'EOF' | sudo tee /etc/systemd/network/99-ogstun.network
[Match]
Name=ogstun

[Network]
Address=10.45.0.1/16
Address=2001:db8:cafe::1/48
EOF

# ── ogstun bring-up + NAT masquerade (runs at boot) ─────────────────────────
cat << 'SVCSCRIPT' | sudo tee /usr/local/bin/5ghoul-setup-net
#!/bin/bash
ip tuntap add name ogstun mode tun 2>/dev/null || true
ip addr add 10.45.0.1/16        dev ogstun 2>/dev/null || true
ip addr add 2001:db8:cafe::1/48 dev ogstun 2>/dev/null || true
ip link set ogstun up

iptables  -t nat -C POSTROUTING -s 10.45.0.0/16      ! -o ogstun -j MASQUERADE 2>/dev/null || \
  iptables  -t nat -A POSTROUTING -s 10.45.0.0/16    ! -o ogstun -j MASQUERADE
ip6tables -t nat -C POSTROUTING -s 2001:db8:cafe::/48 ! -o ogstun -j MASQUERADE 2>/dev/null || \
  ip6tables -t nat -A POSTROUTING -s 2001:db8:cafe::/48 ! -o ogstun -j MASQUERADE

echo "5Ghoul network interfaces ready."
SVCSCRIPT
sudo chmod +x /usr/local/bin/5ghoul-setup-net

cat << 'EOF' | sudo tee /etc/systemd/system/5ghoul-net.service
[Unit]
Description=5Ghoul ogstun Interface and NAT Setup
After=network.target
Before=open5gs-upfd.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/5ghoul-setup-net
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable 5ghoul-net.service || true

# ── Test subscriber helper ────────────────────────────────────────────────────
# Default 5Ghoul credentials: IMSI 001011234567890, K 465B5CE8B199B49FAA5F0A2EE238A6BC
# OPc E8ED289DEBA952E4283B54E88E6183CA  (matches 5Ghoul documentation)
cat << 'EOF' | sudo tee /usr/local/bin/5ghoul-add-subscriber
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
sudo chmod +x /usr/local/bin/5ghoul-add-subscriber

# Stage packages/5ghoul-5g-nr-attacks into the image. 5ghoul-install execs it.
if [ -d /tmp/5ghoul-overlay/scripts ]; then
  mkdir -p /opt/telcosec
  rm -rf /opt/telcosec/5ghoul-overlay
  cp -a /tmp/5ghoul-overlay /opt/telcosec/5ghoul-overlay
  chmod 755 /opt/telcosec/5ghoul-overlay/scripts/*.sh /opt/telcosec/5ghoul-overlay/scripts/5ghoul-run
  chown -R telcosec:plugdev /opt/telcosec/5ghoul-overlay 2>/dev/null || true
else
  echo "WARNING: /tmp/5ghoul-overlay missing; 5ghoul-install will use the embedded patchers."
fi

# ── BladeRF A4 config patcher (fallback if the overlay was not staged) ──────
# Translates USRP-specific OAI gNB conf files into BladeRF-compatible variants.
# Key differences:
#   sdr_addrs  "type=b200" → "bladerf"  (libbladeRF auto-selects the device)
#   max_rxgain 114         → 60         (AD9361 max gain on BladeRF A4)
#   max_txgain (any)       → 60         (BladeRF A4 TX gain range 0–66 dB)
#   Bandwidth is capped at 106 PRBs (20 MHz); 40 MHz causes RX overruns on BladeRF.
cat << 'PATCHSCRIPT' | sudo tee /usr/local/bin/5ghoul-bladerf-patch
#!/bin/bash
set -e
if [ -x /opt/telcosec/5ghoul-overlay/scripts/apply-radio.sh ]; then
  exec /opt/telcosec/5ghoul-overlay/scripts/apply-radio.sh --radio BLADERF --install-dir "${1:-/opt/telcosec/5ghoul}"
fi
INSTALL_DIR="${1:-/opt/telcosec/5ghoul}"

echo "Patching OAI gNB configs for BladeRF A4..."

patch_conf() {
  local src="$1" dst="$2"
  cp "$src" "$dst"
  # Device address: USRP B210 address string → BladeRF auto-detect
  sed -i \
    -e 's|sdr_addrs\s*=\s*"type=b200[^"]*"|sdr_addrs = "bladerf"|g' \
    -e 's|sdr_addrs\s*=\s*"addr=[^"]*"|sdr_addrs = "bladerf"|g' \
    "$dst"
  # RF gain: clamp to BladeRF A4 AD9361 max (60 dB RX, 60 dB TX)
  sed -i \
    -e 's|max_rxgain\s*=\s*[0-9][0-9]*|max_rxgain = 60|g' \
    -e 's|max_txgain\s*=\s*[0-9][0-9]*|max_txgain = 60|g' \
    "$dst"
  # Ensure bandwidth stays at 106 PRBs (20 MHz) — comment out any 217/162 PRB entries
  sed -i \
    -e 's|^\(\s*N_RB_DL\s*=\s*21[0-9]\)|# BladeRF: max 106 PRBs (20 MHz)\n# \1|g' \
    -e 's|^\(\s*N_RB_DL\s*=\s*16[0-9]\)|# BladeRF: max 106 PRBs (20 MHz)\n# \1|g' \
    "$dst"
  echo "  Created: $dst"
}

# Search all known conf locations in the 5Ghoul repo tree
found=0
while IFS= read -r -d '' usrp_conf; do
  # Derive BladeRF conf path by replacing usrp/b210 tokens in filename
  bladerf_conf=$(echo "$usrp_conf" | sed \
    -e 's/usrpb210/bladerf-a4/g' \
    -e 's/usrp\.b210/bladerf.a4/g' \
    -e 's/\.usrp\b/.bladerf/g' \
    -e 's/usrp/bladerf/g' \
    -e 's/b210/bladerf-a4/g')
  if [ "$bladerf_conf" != "$usrp_conf" ]; then
    patch_conf "$usrp_conf" "$bladerf_conf"
    found=$((found + 1))
  fi
done < <(find "$INSTALL_DIR" \
  \( -name "*usrpb210*" -o -name "*usrp.b210*" -o -name "*.usrp.*" \) \
  -name "*.conf" -print0 2>/dev/null)

# Also patch any generic gNB confs that contain USRP device strings
while IFS= read -r -d '' conf; do
  # Only process files not already processed above
  if [[ "$conf" != *bladerf* ]]; then
    bladerf_conf="${conf%.conf}.bladerf-a4.conf"
    patch_conf "$conf" "$bladerf_conf"
    found=$((found + 1))
  fi
done < <(grep -rlZ 'type=b200\|sdr_addrs.*b200' "$INSTALL_DIR" \
  --include='*.conf' 2>/dev/null || true)

if [ "$found" -eq 0 ]; then
  echo "  No USRP conf files found yet (repo not cloned?); patch will re-run at build time."
fi

# Patch build.sh to compile OAI with the BladeRF (-w BLADERF) backend
for build_script in "$INSTALL_DIR/build.sh" "$INSTALL_DIR"/build*.sh; do
  [ -f "$build_script" ] || continue
  if grep -q '\-w USRP' "$build_script" 2>/dev/null; then
    sed -i 's/-w USRP\b/-w BLADERF/g' "$build_script"
    echo "  Patched build backend: $build_script  (-w USRP → -w BLADERF)"
  fi
done

# Patch nested OAI build_oai calls, including requirements.sh (grep -l, not find -exec).
while IFS= read -r -d '' f; do
  sed -i 's/-w USRP\b/-w BLADERF/g' "$f"
  echo "  Patched: $f"
done < <(grep -rlZ --include='*.sh' --exclude-dir=.git -- '-w USRP' "$INSTALL_DIR" 2>/dev/null || true)

echo "BladeRF patch complete."
PATCHSCRIPT
sudo chmod +x /usr/local/bin/5ghoul-bladerf-patch

# ── LimeSDR Mini config patcher ───────────────────────────────────────────────
cat << 'PATCHSCRIPT' | sudo tee /usr/local/bin/5ghoul-limesdr-patch
#!/bin/bash
set -e
if [ -x /opt/telcosec/5ghoul-overlay/scripts/apply-radio.sh ]; then
  exec /opt/telcosec/5ghoul-overlay/scripts/apply-radio.sh --radio LIMESDR --install-dir "${1:-/opt/telcosec/5ghoul}"
fi
INSTALL_DIR="${1:-/opt/telcosec/5ghoul}"

echo "Patching OAI gNB configs for LimeSDR Mini (Portuguese local testing optimization)..."

patch_conf() {
  local src="$1" dst="$2"
  cp "$src" "$dst"
  sed -i \
    -e 's|sdr_addrs\s*=\s*"type=b200[^"]*"|sdr_addrs = "driver=lime"|g' \
    -e 's|sdr_addrs\s*=\s*"addr=[^"]*"|sdr_addrs = "driver=lime"|g' \
    "$dst"
  sed -i \
    -e 's|max_rxgain\s*=\s*[0-9][0-9]*|max_rxgain = 50|g' \
    -e 's|max_txgain\s*=\s*[0-9][0-9]*|max_txgain = 40|g' \
    "$dst"
  sed -i \
    -e 's|^\(\s*N_RB_DL\s*=\s*21[0-9]\)|# LimeSDR: max 106 PRBs (20 MHz)\n# \1|g' \
    -e 's|^\(\s*N_RB_DL\s*=\s*16[0-9]\)|# LimeSDR: max 106 PRBs (20 MHz)\n# \1|g' \
    "$dst"
  echo "  Created: $dst"
}

found=0
while IFS= read -r -d '' usrp_conf; do
  limesdr_conf=$(echo "$usrp_conf" | sed \
    -e 's/usrpb210/limesdr/g' \
    -e 's/usrp\.b210/limesdr/g' \
    -e 's/\.usrp\b/.limesdr/g' \
    -e 's/usrp/limesdr/g' \
    -e 's/b210/limesdr/g')
  if [ "$limesdr_conf" != "$usrp_conf" ]; then
    patch_conf "$usrp_conf" "$limesdr_conf"
    found=$((found + 1))
  fi
done < <(find "$INSTALL_DIR" \( -name "*usrpb210*" -o -name "*usrp.b210*" -o -name "*.usrp.*" \) -name "*.conf" -print0 2>/dev/null)

while IFS= read -r -d '' conf; do
  if [[ "$conf" != *limesdr* && "$conf" != *bladerf* ]]; then
    limesdr_conf="${conf%.conf}.limesdr.conf"
    patch_conf "$conf" "$limesdr_conf"
    found=$((found + 1))
  fi
done < <(grep -rlZ 'type=b200\|sdr_addrs.*b200' "$INSTALL_DIR" --include='*.conf' 2>/dev/null || true)

for build_script in "$INSTALL_DIR/build.sh" "$INSTALL_DIR"/build*.sh; do
  [ -f "$build_script" ] || continue
  if grep -q '\-w USRP' "$build_script" 2>/dev/null; then
    sed -i 's/-w USRP\b/-w LMSSDR/g' "$build_script"
  fi
done

while IFS= read -r -d '' f; do
  sed -i 's/-w USRP\b/-w LMSSDR/g' "$f"
done < <(grep -rlZ --include='*.sh' --exclude-dir=.git -- '-w USRP' "$INSTALL_DIR" 2>/dev/null || true)

echo "LimeSDR patch complete."
PATCHSCRIPT
sudo chmod +x /usr/local/bin/5ghoul-limesdr-patch

# ── First-run installer (clones repo + compiles on live system) ──────────────
# Usage: sudo 5ghoul-install [--radio USRP|BLADERF]
cat << 'INSTALLSCRIPT' | sudo tee /usr/local/bin/5ghoul-install
#!/bin/bash
set -e
if [ -x /opt/telcosec/5ghoul-overlay/scripts/install.sh ]; then
  exec /opt/telcosec/5ghoul-overlay/scripts/install.sh "$@"
fi
INSTALL_DIR="/opt/telcosec/5ghoul"
RADIO="USRP"

# Parse --radio argument
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

echo "╔══════════════════════════════════════════════════════╗"
echo "║      5Ghoul 5G NR Attack Framework Installer        ║"
echo "║  https://github.com/asset-group/5ghoul-5g-nr-attacks ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "Radio backend : $RADIO"
if [ "$RADIO" = "BLADERF" ]; then
  echo "Hardware      : BladeRF A4 (BladeRF 2.0 micro xA4) via USB 3.0"
  echo "Max bandwidth : 20 MHz NR (106 PRBs) — 40 MHz causes RX overruns on BladeRF"
elif [ "$RADIO" = "LIMESDR" ]; then
  echo "Hardware      : LimeSDR Mini"
  echo "Optimization  : Portuguese local testing limits applied (RX: 50, TX: 40)"
else
  echo "Hardware      : USRP B210 via USB 3.0"
fi
echo "Build time    : 20–60 min"
echo ""

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo 5ghoul-install [--radio USRP|BLADERF]"
  exit 1
fi

# Verify the requested hardware library is present
if [ "$RADIO" = "BLADERF" ]; then
  if ! dpkg -l libbladerf2 2>/dev/null | grep -q '^ii'; then
    echo "ERROR: libbladerf2 not found. Install with: apt-get install libbladerf2 libbladerf-dev"
    exit 1
  fi
  echo "  libbladerf2 found."
  bladerf_info=$(bladerf-cli -e version 2>/dev/null || true)
  if [ -n "$bladerf_info" ]; then
    echo "  BladeRF CLI: $bladerf_info"
  fi
  # Verify BladeRF FPGA bitstreams in /usr/share/Nuand/bladeRF
  if [ ! -f /usr/share/Nuand/bladeRF/hostedxA4.rbf ] && [ ! -f /usr/share/Nuand/bladeRF/hosted.rbf ]; then
    echo "  NOTE: BladeRF FPGA bitstream not found in /usr/share/Nuand/bladeRF/."
    if command -v bladerf-download-images >/dev/null 2>&1; then
      echo "  Attempting automated download via bladerf-download-images..."
      bladerf-download-images || echo "  WARNING: Image download failed. Connect to internet and run: sudo bladerf-download-images"
    fi
  else
    echo "  BladeRF FPGA hosted bitstream detected."
  fi
fi
if [ "$RADIO" = "LIMESDR" ]; then
  if ! dpkg -l limesuite 2>/dev/null | grep -q '^ii'; then
    echo "WARNING: limesuite not found in apt. Assuming it was built via conda/source."
  else
    echo "  limesuite found."
  fi
fi

# [1/5] Clone
if [ ! -d "$INSTALL_DIR/.git" ]; then
  echo "[1/5] Cloning 5Ghoul repository..."
  git clone --depth 1 --recurse-submodules --shallow-submodules \
    https://github.com/asset-group/5ghoul-5g-nr-attacks \
    "$INSTALL_DIR"
else
  echo "[1/5] Repository already cloned, updating..."
  git -C "$INSTALL_DIR" pull --recurse-submodules || true
fi

cd "$INSTALL_DIR"

# [2/5] Radio-specific pre-build patching
if [ "$RADIO" = "BLADERF" ]; then
  echo "[2/5] Applying BladeRF patches to OAI config and build scripts..."
  /usr/local/bin/5ghoul-bladerf-patch "$INSTALL_DIR"
  # Record which radio this build targets so 5ghoul-run can auto-select configs
  echo "BLADERF" > "$INSTALL_DIR/.radio-backend"
elif [ "$RADIO" = "LIMESDR" ]; then
  echo "[2/5] Applying LimeSDR patches to OAI config and build scripts..."
  /usr/local/bin/5ghoul-limesdr-patch "$INSTALL_DIR"
  echo "LIMESDR" > "$INSTALL_DIR/.radio-backend"
else
  echo "[2/5] USRP backend selected — no patching required."
  echo "USRP" > "$INSTALL_DIR/.radio-backend"
fi

# [3/5] Framework dependencies
echo "[3/5] Installing framework dependencies (Ubuntu 24.04 Noble compat)..."

# ── Ubuntu 24.04 (Noble) compatibility shim for 5ghoul's requirements.sh ─────
# requirements.sh was written for Ubuntu 18.04 Bionic. Several packages have
# been renamed, dropped, or moved to the 'universe' repo in Noble.
#
# Package fixes applied:
#   bc, swig, graphviz, libgraphviz-dev — available, just need universe
#   libspandsp-dev           — universe repo only
#   libxrandr-dev libxinerama-dev libxcursor-dev libxi-dev — now in libx11-dev/libxext-dev umbrella;
#                              packages still exist in Noble universe
#   libnl-nf-3-dev           — renamed to libnl-nf-3-200 (runtime) + libnl-3-dev (dev); skip
#   libbrotli-dev            — still exists
#   libsmi2-dev              — removed in Noble (replaced by libsmi2ldbl); skip with apt --ignore-missing
#   libsbc-dev               — universe
#   libspeexdsp-dev          — universe
#   libfreetype6-dev         — renamed to libfreetype-dev in Noble
#   libasound2-dev           — still exists
#   libmaxminddb-dev         — universe
#   libopus-dev              — still exists
#   sshpass                  — universe
#   libxss1                  — renamed to libxss-dev or present as libxss1; skip gracefully
#   libgl1-mesa-dev          — renamed to libgl-dev in Noble
#   gcc-9 g++-9 libstdc++-9-dev — dropped from Noble repos; skip
#   ppa:beineri/opt-qt-5.12.2-bionic — Bionic-only PPA; skip entirely
#   ppa:ubuntu-toolchain-r/test       — not needed on Noble (gcc-12+ built-in)
#   nodesource setup_16.x            — use system nodejs (already installed)
#   qt512base etc.                    — Qt5 available via libqt5*-dev in Noble

# Enable universe repo so optional packages are available
add-apt-repository universe -y 2>/dev/null || true
apt-get update -qq

# Patch requirements.sh in-place (idempotent — only modifies if patterns match)
_patch_requirements() {
  local req="requirements.sh"
  [ -f "$req" ] || return 0

  # 1. libnl-nf-3-dev → skip (not in Noble; libnl-3-dev covers it)
  sed -i 's/ libnl-nf-3-dev\b//g' "$req"

  # 2. libfreetype6-dev → libfreetype-dev (renamed in Noble)
  sed -i 's/\blibfreetype6-dev\b/libfreetype-dev/g' "$req"

  # 3. libgl1-mesa-dev → libgl-dev (renamed in Noble)
  sed -i 's/\blibgl1-mesa-dev\b/libgl-dev/g' "$req"

  # 4. libsmi2-dev — removed in Noble; substitute with apt-get --ignore-missing workaround
  sed -i 's/\blibsmi2-dev\b//g' "$req"

  # 5. Drop gcc-9/g++-9/libstdc++-9-dev block (not in Noble repos)
  sed -i '/apt install gcc-9 g++-9 libstdc++-9-dev/d' "$req"

  # 6. Suppress the Bionic-only Qt 5.12.2 PPA block entirely
  sed -i '/ppa:beineri\/opt-qt-5.12.2-bionic/d' "$req"
  sed -i '/qt512base\|qt512tools\|qt512svg\|qt512multimedia/d' "$req"

  # 7. Suppress the ubuntu-toolchain-r PPA (not needed on Noble, causes 404s)
  sed -i '/ppa:ubuntu-toolchain-r\/test/d' "$req"

  # 8. Suppress the nodesource setup_16.x curl pipe (nodejs already installed)
  sed -i '/nodesource.com\/setup_16/d' "$req"

  # 9. Add --ignore-missing to all apt install lines so unknown packages don't abort
  sed -i 's/sudo apt install /sudo apt install --ignore-missing /g' "$req"
  sed -i 's/sudo apt-get install /sudo apt-get install --ignore-missing /g' "$req"

  echo "  requirements.sh patched for Ubuntu 24.04 Noble."
}

_patch_requirements

# Install packages that requirements.sh drops but Noble still has (via universe)
DEBIAN_FRONTEND=noninteractive apt-get install --ignore-missing -y \
  bc swig graphviz libgraphviz-dev \
  libspandsp-dev \
  libsbc-dev libspeexdsp-dev \
  libxrandr-dev libxinerama-dev libxcursor-dev libxi-dev \
  libmaxminddb-dev \
  libfreetype-dev \
  libgl-dev \
  libpcre2-dev \
  libxss1 \
  sshpass 2>/dev/null || true

# Now run the (patched) upstream dependency scripts
DEBIAN_FRONTEND=noninteractive bash requirements.sh dev || true
DEBIAN_FRONTEND=noninteractive bash requirements.sh 5g  || true

# [4/5] Compile
echo "[4/5] Compiling (this takes a while)..."
# Calculate safe concurrency to prevent OOM crashes (allocate ~2GB RAM per compilation job)
TOTAL_RAM_MB=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}' || true)
if [ -n "$TOTAL_RAM_MB" ] && [ "$TOTAL_RAM_MB" -gt 0 ]; then
  MAX_JOBS=$(( TOTAL_RAM_MB / 2048 ))
  [ "$MAX_JOBS" -lt 1 ] && MAX_JOBS=1
  NPROC=$(nproc)
  [ "$MAX_JOBS" -gt "$NPROC" ] && MAX_JOBS="$NPROC"
  echo "  Allocating $MAX_JOBS parallel compilation jobs for $TOTAL_RAM_MB MB system RAM..."
else
  MAX_JOBS=$(nproc)
fi
export MAKEFLAGS="-j$MAX_JOBS"
bash build.sh all

# [5/5] Permissions
echo "[5/5] Setting permissions..."
chown -R telcosec:plugdev "$INSTALL_DIR" || true
chmod -R g+rw "$INSTALL_DIR" || true

echo ""
echo "✓ 5Ghoul installed at $INSTALL_DIR (radio: $RADIO)"
echo ""
echo "Quick start:"
echo "  1. sudo 5ghoul-add-subscriber      # register test UE in Open5GS"
echo "  2. sudo open5gs-start              # start 5G SA core"
if [ "$RADIO" = "BLADERF" ] || [ "$RADIO" = "LIMESDR" ]; then
  if [ "$RADIO" = "BLADERF" ]; then
    # Try known path first (5Ghoul repo: conf/gnb_bladerf.conf), fall back to find
    BCONF="${INSTALL_DIR}/conf/gnb_bladerf.conf"
    [ -f "$BCONF" ] || BCONF=$(find "$INSTALL_DIR" -name '*bladerf*' -name '*.conf' 2>/dev/null | head -1)
    echo "  3. Connect BladeRF A4 via USB 3.0"
  else
    # Try known path first (5Ghoul repo: conf/gnb_limesdr.conf), fall back to find
    BCONF="${INSTALL_DIR}/conf/gnb_limesdr.conf"
    [ -f "$BCONF" ] || BCONF=$(find "$INSTALL_DIR" -name '*limesdr*' -name '*.conf' 2>/dev/null | head -1)
    echo "  3. Connect LimeSDR Mini via USB"
  fi
  echo "  4. cd $INSTALL_DIR"
  if [ -n "$BCONF" ]; then
    echo "  5. sudo ./build/5g_fuzzer --gnb.conf $BCONF --Attack.Name=NAS_5GS_Fuzz --UE.IMSI=001011234567890"
  else
    echo "  5. sudo ./build/5g_fuzzer --Attack.Name=NAS_5GS_Fuzz --UE.IMSI=001011234567890"
  fi
  echo ""
  echo "Note: If you see RX overrun errors, reduce the NR bandwidth to 20 MHz (106 PRBs)."
else
  echo "  3. Connect USRP B210 via USB 3.0"
  echo "  4. cd $INSTALL_DIR"
  echo "  5. sudo ./build/5g_fuzzer --Attack.Name=NAS_5GS_Fuzz --UE.IMSI=001011234567890"
fi
INSTALLSCRIPT
sudo chmod +x /usr/local/bin/5ghoul-install

# ── Fuzzer launcher wrapper ───────────────────────────────────────────────────
# Auto-selects the BladeRF gNB conf when the build was done with --radio BLADERF.
cat << 'RUNSCRIPT' | sudo tee /usr/local/bin/5ghoul-run
#!/bin/bash
INSTALL_DIR="/opt/telcosec/5ghoul"
FUZZER="$INSTALL_DIR/build/5g_fuzzer"

if [ ! -f "$FUZZER" ]; then
  echo "5Ghoul not yet built."
  echo "  For USRP B210:     sudo 5ghoul-install"
  echo "  For BladeRF A4:    sudo 5ghoul-install --radio BLADERF"
  echo "  For LimeSDR Mini:  sudo 5ghoul-install --radio LIMESDR"
  if command -v xterm &>/dev/null; then
    xterm -fa 'Monospace' -fs 11 -T '5Ghoul — choose radio' \
      -e 'echo "Build for USRP B210, BladeRF A4, or LimeSDR Mini?"; \
          PS3="Select: "; select r in USRP BLADERF LIMESDR; do \
            sudo 5ghoul-install --radio "$r" && break; done; \
          read -rp "Press Enter to close..."'
  fi
  exit 1
fi

cd "$INSTALL_DIR"

# If the build was done for BladeRF and no --gnb.conf was given, auto-insert one
RADIO_BACKEND="USRP"
[ -f "$INSTALL_DIR/.radio-backend" ] && RADIO_BACKEND=$(cat "$INSTALL_DIR/.radio-backend")

EXTRA_ARGS=()
if [[ "$RADIO_BACKEND" =~ ^(BLADERF|LIMESDR)$ ]] && ! printf '%s\n' "$@" | grep -q -- '--gnb.conf'; then
  SEARCH_TERM=$(echo "$RADIO_BACKEND" | tr '[:upper:]' '[:lower:]')
  # Try known conf path first (5Ghoul repo: conf/gnb_<radio>.conf), fall back to find
  BCONF="${INSTALL_DIR}/conf/gnb_${SEARCH_TERM}.conf"
  [ -f "$BCONF" ] || BCONF="${INSTALL_DIR}/configs/5gnr_gnb/n78.106.${SEARCH_TERM}.conf"
  [ -f "$BCONF" ] || BCONF=$(find "$INSTALL_DIR" -name "*${SEARCH_TERM}*" -name '*.conf' 2>/dev/null | head -1)
  if [ -n "$BCONF" ] && [ -f "$BCONF" ]; then
    echo "Auto-selected $RADIO_BACKEND gNB config: $BCONF"
    EXTRA_ARGS=(--gnb.conf "$BCONF")
  fi
fi

exec sudo "$FUZZER" "${EXTRA_ARGS[@]}" "$@"
RUNSCRIPT
sudo chmod +x /usr/local/bin/5ghoul-run

# ── Open5GS start/stop helpers ───────────────────────────────────────────────
cat << 'EOF' | sudo tee /usr/local/bin/open5gs-start
#!/bin/bash
if [ ! -d "/opt/telcosec/open5gs/docker_open5gs" ]; then
  echo "Open5GS is not installed. Run: sudo open5gs-install"
  exit 1
fi
echo "Starting Open5GS 5G SA core network functions via Docker Compose..."
cd /opt/telcosec/open5gs/docker_open5gs
sudo docker compose up -d || sudo docker-compose up -d
echo "Done. Check status: sudo docker compose ps"
EOF
sudo chmod +x /usr/local/bin/open5gs-start

cat << 'EOF' | sudo tee /usr/local/bin/open5gs-stop
#!/bin/bash
if [ ! -d "/opt/telcosec/open5gs/docker_open5gs" ]; then
  echo "Open5GS is not installed."
  exit 1
fi
echo "Stopping Open5GS..."
cd /opt/telcosec/open5gs/docker_open5gs
sudo docker compose down || sudo docker-compose down
echo "Done."
EOF
sudo chmod +x /usr/local/bin/open5gs-stop

cat << 'EOF' | sudo tee /usr/local/bin/open5gs-logs
#!/bin/bash
if [ ! -d "/opt/telcosec/open5gs/docker_open5gs" ]; then
  echo "Open5GS is not installed."
  exit 1
fi
echo "Viewing Open5GS container logs (Ctrl+C to exit)..."
cd /opt/telcosec/open5gs/docker_open5gs
sudo docker compose logs -f || sudo docker-compose logs -f
EOF
sudo chmod +x /usr/local/bin/open5gs-logs

echo "=== 5Ghoul dependencies installed ==="
echo "  USRP B210:   sudo 5ghoul-install"
echo "  BladeRF A4:  sudo 5ghoul-install --radio BLADERF"
