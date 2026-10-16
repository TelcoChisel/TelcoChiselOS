#!/bin/bash
# Fixture check for the BladeRF/LimeSDR conf and build-target rewrite.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/configs/5gnr_gnb"
cat > "$tmp/configs/5gnr_gnb/n78.106.conf" << 'EOF'
local_rf = "yes"
max_rxgain = 114;
nb_tx = 1
EOF
cat > "$tmp/requirements.sh" << 'EOF'
#!/bin/bash
./build_oai -I -w USRP --gNB --nrUE
EOF

bash "$ROOT/scripts/apply-radio.sh" --radio BLADERF --install-dir "$tmp"
grep -q 'sdr_addrs = "bladerf";' "$tmp/configs/5gnr_gnb/n78.106.bladerf.conf"
grep -q 'max_rxgain = 60' "$tmp/configs/5gnr_gnb/n78.106.bladerf.conf"
grep -q -- '-w BLADERF' "$tmp/requirements.sh"
test -f "$tmp/conf/gnb_bladerf.conf"
grep -qx BLADERF "$tmp/.radio-backend"

# Re-apply must stay idempotent: still one BladeRF target, source conf unchanged.
bash "$ROOT/scripts/apply-radio.sh" --radio BLADERF --install-dir "$tmp"
grep -q -- '-w BLADERF' "$tmp/requirements.sh"
if grep -q -- '-w USRP' "$tmp/requirements.sh"; then
  echo "USRP target survived a BladeRF apply" >&2
  exit 1
fi
if grep -q 'sdr_addrs' "$tmp/configs/5gnr_gnb/n78.106.conf"; then
  echo "upstream conf was modified in place" >&2
  exit 1
fi

usrp="$(mktemp -d)"
mkdir -p "$usrp/configs/5gnr_gnb"
cp "$tmp/configs/5gnr_gnb/n78.106.conf" "$usrp/configs/5gnr_gnb/n78.106.conf"
printf '%s\n' '#!/bin/bash' './build_oai -I -w USRP --gNB' > "$usrp/requirements.sh"
bash "$ROOT/scripts/apply-radio.sh" --radio USRP --install-dir "$usrp"
grep -q -- '-w USRP' "$usrp/requirements.sh"
test ! -f "$usrp/configs/5gnr_gnb/n78.106.bladerf.conf"
rm -rf "$usrp"

echo "apply-radio OK"
