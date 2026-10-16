#!/bin/bash
# Ubuntu 24.04 adjustments for upstream requirements.sh (written for 18.04).
# Usage: noble-compat.sh [path-to-requirements.sh]
set -euo pipefail

REQ="${1:-requirements.sh}"
if [ ! -f "$REQ" ]; then
  echo "noble-compat: $REQ not found, skipping"
  exit 0
fi

sed -i 's/ libnl-nf-3-dev\b//g' "$REQ"
sed -i 's/\blibfreetype6-dev\b/libfreetype-dev/g' "$REQ"
sed -i 's/\blibgl1-mesa-dev\b/libgl-dev/g' "$REQ"
sed -i 's/\blibsmi2-dev\b//g' "$REQ"
sed -i '/apt install gcc-9 g++-9 libstdc++-9-dev/d' "$REQ"
sed -i '/ppa:beineri\/opt-qt-5.12.2-bionic/d' "$REQ"
sed -i '/qt512base\|qt512tools\|qt512svg\|qt512multimedia/d' "$REQ"
sed -i '/ppa:ubuntu-toolchain-r\/test/d' "$REQ"
sed -i '/nodesource.com\/setup_16/d' "$REQ"
sed -i '/--ignore-missing/!s/sudo apt install /sudo apt install --ignore-missing /g' "$REQ"
sed -i '/--ignore-missing/!s/sudo apt-get install /sudo apt-get install --ignore-missing /g' "$REQ"
echo "noble-compat: patched $REQ"
