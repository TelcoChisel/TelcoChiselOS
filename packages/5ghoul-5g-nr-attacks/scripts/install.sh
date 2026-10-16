#!/bin/bash
# Clone the pinned upstream 5Ghoul tree, apply the TelcoSec radio overlay, and build.
# Usage: install.sh [--radio USRP|BLADERF|LIMESDR] [--install-dir DIR] [--no-build]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/UPSTREAM"

RADIO="${TELCOSEC_5GHOUL_RADIO:-USRP}"
INSTALL_DIR="${TELCOSEC_5GHOUL_DIR:-/opt/telcosec/5ghoul}"
DO_BUILD=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --radio)   RADIO="${2^^}"; shift 2 ;;
    --radio=*) RADIO="${1#*=}"; RADIO="${RADIO^^}"; shift ;;
    --install-dir) INSTALL_DIR="$2"; shift 2 ;;
    --install-dir=*) INSTALL_DIR="${1#*=}"; shift ;;
    --no-build) DO_BUILD=0; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

case "$RADIO" in
  USRP|BLADERF|LIMESDR) ;;
  *) echo "Unknown radio: $RADIO (USRP, BLADERF, LIMESDR)" >&2; exit 1 ;;
esac

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo 5ghoul-install [--radio USRP|BLADERF|LIMESDR]"
  exit 1
fi

echo "5Ghoul overlay"
echo "  upstream : $UPSTREAM_REPO"
echo "  pin      : $UPSTREAM_REF"
echo "  radio    : $RADIO"
echo "  tree     : $INSTALL_DIR"

if [ "$RADIO" = "BLADERF" ]; then
  if ! dpkg -l libbladerf2 2>/dev/null | grep -q '^ii'; then
    echo "ERROR: libbladerf2 is not installed (apt-get install libbladerf2 libbladerf-dev bladerf)"
    exit 1
  fi
fi

mkdir -p "$(dirname "$INSTALL_DIR")"
if [ ! -d "$INSTALL_DIR/.git" ]; then
  echo "[1/4] Cloning pinned upstream..."
  rm -rf "$INSTALL_DIR"
  git init "$INSTALL_DIR"
  git -C "$INSTALL_DIR" remote add origin "$UPSTREAM_REPO"
  git -C "$INSTALL_DIR" fetch --depth 1 origin "$UPSTREAM_REF"
  git -C "$INSTALL_DIR" checkout --detach FETCH_HEAD
else
  echo "[1/4] Tree exists; checking pin..."
  current="$(git -C "$INSTALL_DIR" rev-parse HEAD)"
  if [ "$current" != "$UPSTREAM_REF" ]; then
    git -C "$INSTALL_DIR" fetch --depth 1 origin "$UPSTREAM_REF"
    git -C "$INSTALL_DIR" checkout --detach FETCH_HEAD
  fi
fi

echo "[2/4] Submodules..."
git -C "$INSTALL_DIR" submodule update --init --recursive --depth 1

echo "[3/4] Radio overlay + Ubuntu 24.04 compatibility..."
"$ROOT/scripts/apply-radio.sh" --radio "$RADIO" --install-dir "$INSTALL_DIR"
if [ -f "$INSTALL_DIR/requirements.sh" ]; then
  "$ROOT/scripts/noble-compat.sh" "$INSTALL_DIR/requirements.sh"
fi

if [ "$DO_BUILD" -eq 0 ]; then
  echo "Source ready at $INSTALL_DIR (--no-build)."
  exit 0
fi

echo "[4/4] Dependencies and compile (often 20–60 min)..."
cd "$INSTALL_DIR"
if command -v add-apt-repository >/dev/null 2>&1; then
  add-apt-repository universe -y >/dev/null 2>&1 || true
fi
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install --ignore-missing -y \
  bc swig graphviz libgraphviz-dev \
  libspandsp-dev libsbc-dev libspeexdsp-dev \
  libxrandr-dev libxinerama-dev libxcursor-dev libxi-dev \
  libmaxminddb-dev libfreetype-dev libgl-dev libpcre2-dev \
  libxss1 sshpass >/dev/null 2>&1 || true

DEBIAN_FRONTEND=noninteractive bash requirements.sh dev || true
DEBIAN_FRONTEND=noninteractive bash requirements.sh 5g || true

MEM_KB="$(awk '/^MemTotal:/{print $2}' /proc/meminfo 2>/dev/null || echo 0)"
MEM_KB="${MEM_KB:-0}"
MAX_JOBS=$(( MEM_KB / 2097152 ))
[ "$MAX_JOBS" -lt 1 ] && MAX_JOBS=1
NPROC="$(nproc)"
[ "$MAX_JOBS" -gt "$NPROC" ] && MAX_JOBS="$NPROC"
export MAKEFLAGS="-j${MAX_JOBS}"
bash build.sh all

if id telcosec >/dev/null 2>&1; then
  chown -R telcosec:plugdev "$INSTALL_DIR" 2>/dev/null || chown -R telcosec:telcosec "$INSTALL_DIR" || true
fi

echo "5Ghoul built at $INSTALL_DIR (radio: $RADIO)"
echo "Launcher: 5ghoul-run"
