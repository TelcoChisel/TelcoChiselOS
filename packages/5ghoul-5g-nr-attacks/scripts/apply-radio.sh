#!/bin/bash
# Apply a radio backend to a cloned 5Ghoul tree.
# Usage: apply-radio.sh --radio USRP|BLADERF|LIMESDR [--install-dir DIR]
set -euo pipefail

RADIO="${TELCOSEC_5GHOUL_RADIO:-USRP}"
INSTALL_DIR="${TELCOSEC_5GHOUL_DIR:-/opt/telcosec/5ghoul}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --radio)   RADIO="${2^^}"; shift 2 ;;
    --radio=*) RADIO="${1#*=}"; RADIO="${RADIO^^}"; shift ;;
    --install-dir) INSTALL_DIR="$2"; shift 2 ;;
    --install-dir=*) INSTALL_DIR="${1#*=}"; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

case "$RADIO" in
  USRP|BLADERF|LIMESDR) ;;
  *) echo "Unknown radio: $RADIO (USRP, BLADERF, LIMESDR)" >&2; exit 1 ;;
esac

if [ ! -d "$INSTALL_DIR" ]; then
  echo "5Ghoul tree not found at $INSTALL_DIR"
  exit 0
fi

OAI_HW="USRP"
SDR_TOKEN=""
RX_GAIN=""
TX_GAIN=""
TAG=""
case "$RADIO" in
  BLADERF)
    OAI_HW="BLADERF"
    SDR_TOKEN="bladerf"
    RX_GAIN=60
    TX_GAIN=60
    TAG="bladerf"
    ;;
  LIMESDR)
    OAI_HW="LMSSDR"
    SDR_TOKEN="driver=lime"
    RX_GAIN=50
    TX_GAIN=40
    TAG="limesdr"
    ;;
esac

echo "Applying radio backend $RADIO (OAI -w $OAI_HW) to $INSTALL_DIR"

if [ "$OAI_HW" != "USRP" ]; then
  while IFS= read -r -d '' script; do
    sed -i "s/-w USRP\\b/-w ${OAI_HW}/g" "$script"
    echo "  build target: $script (-w ${OAI_HW})"
  done < <(grep -rlZ --include='*.sh' --exclude-dir=.git -- '-w USRP' "$INSTALL_DIR" || true)
fi

write_conf() {
  local src="$INSTALL_DIR/configs/5gnr_gnb/n78.106.conf"
  local dst="$INSTALL_DIR/configs/5gnr_gnb/n78.106.${TAG}.conf"
  if [ ! -f "$src" ]; then
    echo "  no $src yet; radio conf will be written after the tree is present"
    return 0
  fi
  cp "$src" "$dst"
  sed -i -E "s/max_rxgain[[:space:]]*=[[:space:]]*[0-9]+/max_rxgain = ${RX_GAIN}/" "$dst"
  if grep -q 'max_txgain' "$dst"; then
    sed -i -E "s/max_txgain[[:space:]]*=[[:space:]]*[0-9]+/max_txgain = ${TX_GAIN}/" "$dst"
  fi
  if grep -q 'sdr_addrs' "$dst"; then
    sed -i -E "s/sdr_addrs[[:space:]]*=[[:space:]]*\"[^\"]*\"/sdr_addrs = \"${SDR_TOKEN}\";/" "$dst"
  else
    sed -i "/local_rf/a sdr_addrs = \"${SDR_TOKEN}\";" "$dst"
  fi
  mkdir -p "$INSTALL_DIR/conf"
  cp "$dst" "$INSTALL_DIR/conf/gnb_${TAG}.conf"
  echo "  gNB conf: $dst"
  echo "  launcher conf: $INSTALL_DIR/conf/gnb_${TAG}.conf"
}

if [ -n "$TAG" ]; then
  write_conf
fi

echo "$RADIO" > "$INSTALL_DIR/.radio-backend"
echo "Radio backend recorded: $RADIO"
