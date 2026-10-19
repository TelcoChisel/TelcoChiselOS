#!/usr/bin/env bash
# =============================================================================
# install-telcochisel-repo.sh
# Adds the official TelcoChisel APT repository to Ubuntu 24.04 (Noble) systems.
# Enables installing TelcoChisel metapackages, SDR udev rules, and tools.
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== TelcoChisel Official APT Repository Installer ===${NC}"

if [ "$(id -u)" -ne 0 ]; then
  echo -e "${RED}ERROR: Please run as root or with sudo: sudo bash $0${NC}"
  exit 1
fi

TELCOSEC_URL="https://meta.telcochisel.com"
TELCOSEC_KEY="/etc/apt/keyrings/telcochisel-archive-keyring.asc"
TELCOSEC_SOURCES="/etc/apt/sources.list.d/telcochisel.sources"
TELCOSEC_FPR="6326A34C15FEF05FBD63518B4325182E2F0D9DB9"

echo "--> Installing prerequisites..."
apt-get update -qq
apt-get install -y -qq curl gnupg ca-certificates

echo "--> Fetching repository signing key..."
mkdir -p /etc/apt/keyrings
if ! curl -fsSL "${TELCOSEC_URL}/public.gpg" -o "$TELCOSEC_KEY" 2>/dev/null || [ ! -s "$TELCOSEC_KEY" ]; then
  curl -fsSL "${TELCOSEC_URL}/telcosec.gpg" -o "$TELCOSEC_KEY"
fi

echo "--> Verifying GPG signing key fingerprint..."
ACTUAL_FPR=$(gpg --show-keys --with-colons "$TELCOSEC_KEY" 2>&1 | awk -F: '$1=="fpr"{print $10; exit}')

if [ -z "$ACTUAL_FPR" ]; then
  echo -e "${RED}ERROR: Could not read fingerprint from downloaded key.${NC}"
  rm -f "$TELCOSEC_KEY"
  exit 1
fi

if [ "$ACTUAL_FPR" != "$TELCOSEC_FPR" ]; then
  echo -e "${RED}ERROR: Key fingerprint mismatch!${NC}"
  echo "Expected: $TELCOSEC_FPR"
  echo "Actual:   $ACTUAL_FPR"
  rm -f "$TELCOSEC_KEY"
  exit 1
fi

chmod 0644 "$TELCOSEC_KEY"
echo -e "${GREEN}✓ Key verified successfully: $ACTUAL_FPR${NC}"

echo "--> Configuring APT source list..."
mkdir -p /etc/apt/sources.list.d
cat > "$TELCOSEC_SOURCES" << EOF
Types: deb
URIs: ${TELCOSEC_URL}
Suites: noble
Components: main
Signed-By: ${TELCOSEC_KEY}
EOF
chmod 0644 "$TELCOSEC_SOURCES"

echo "--> Configuring TelcoChisel package pinning policy..."
mkdir -p /etc/apt/preferences.d
cat > "/etc/apt/preferences.d/99-telcochisel.pref" << 'EOF'
Package: telcochisel-*
Pin: origin meta.telcochisel.com
Pin-Priority: 1001

Package: *
Pin: origin meta.telcochisel.com
Pin-Priority: 990
EOF
chmod 0644 "/etc/apt/preferences.d/99-telcochisel.pref"

echo "--> Installing telcosec-pkg management CLI..."
mkdir -p /usr/local/bin
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/../builder/scripts/bin/telcosec-pkg" ]; then
  cp "$SCRIPT_DIR/../builder/scripts/bin/telcosec-pkg" /usr/local/bin/telcosec-pkg
  chmod 0755 /usr/local/bin/telcosec-pkg
  ln -sf /usr/local/bin/telcosec-pkg /usr/local/bin/telcochisel-pkg
  echo -e "${GREEN}✓ telcosec-pkg CLI installed locally to /usr/local/bin/telcosec-pkg${NC}"
fi

echo "--> Refreshing package indices..."
apt-get update

echo -e "\n${GREEN}=== TelcoChisel Repository Successfully Installed! ===${NC}"
echo -e "You can manage metapackages using the ${BLUE}telcosec-pkg${NC} CLI tool or standard ${BLUE}apt${NC}:"
echo ""
echo -e "  ${YELLOW}telcosec-pkg list${NC}                          # Check status of all 10 tiers"
echo -e "  ${YELLOW}telcosec-pkg tools 5g${NC}                      # Inspect exact tools in 5G tier"
echo -e "  ${YELLOW}telcosec-pkg search sdr${NC}                    # Search metapackages and tool manifests"
echo -e "  ${YELLOW}sudo telcosec-pkg install 5g ue${NC}            # Install 5G and UE tool suites"
echo -e "  ${YELLOW}sudo telcosec-pkg install full${NC}             # Install complete 100-tool suite"
echo ""
echo -e "Official 10-Tier Modular Architecture:"
echo -e "  1.  ${BLUE}telcochisel-base${NC}           (alias: ${YELLOW}base${NC})       - Realtime kernel limits, sysctl & SCTP autoload"
echo -e "  2.  ${BLUE}telcochisel-hardware-sdr${NC}  (alias: ${YELLOW}hardware${NC})   - SDR USB udev rules & FPGA bitstream loaders"
echo -e "  3.  ${BLUE}telcochisel-tools-sdr${NC}     (alias: ${YELLOW}sdr${NC})        - RF analysis & Satcom suite (GNU Radio, Inspectrum, URH)"
echo -e "  4.  ${BLUE}telcochisel-tools-2g-3g${NC}   (alias: ${YELLOW}2g-3g${NC})      - 2G/3G env + build tooling; Osmocom/OpenBTS/YateBTS build on first run"
echo -e "  5.  ${BLUE}telcochisel-tools-4g${NC}      (alias: ${YELLOW}4g${NC})         - 4G env + build tooling; srsRAN/LTESniffer build on first run"
echo -e "  6.  ${BLUE}telcochisel-tools-5g${NC}      (alias: ${YELLOW}5g${NC})         - 5G env + build tooling; Open5GS/UERANSIM/5Ghoul build on first run"
echo -e "  7.  ${BLUE}telcochisel-tools-sim${NC}     (alias: ${YELLOW}sim${NC})        - SIM/eSIM: PC-SC, OpenSC, pyscard; pySim/SIMtrace/lpac on first run"
echo -e "  8.  ${BLUE}telcochisel-tools-pstn-adsl${NC}(alias: ${YELLOW}wireline${NC})   - PSTN, ADSL, VoIP/SIP security & packet crafting"
echo -e "  9.  ${BLUE}telcochisel-tools-ue${NC}       (alias: ${YELLOW}ue${NC})         - UE env: ADB/Fastboot; QCSuper/SCAT/FirmWire/MTKClient on first run"
echo -e "  10. ${BLUE}telcochisel-meta-full${NC}     (alias: ${YELLOW}full${NC})       - Complete TelcoChisel distribution umbrella (100 tools)"
echo ""
