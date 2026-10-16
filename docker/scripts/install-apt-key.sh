#!/usr/bin/env bash
# Install and fingerprint-verify the TelcoChisel APT signing key (parity with
# builder/scripts/00-install-all-packages.sh and scripts/install-telcochisel-repo.sh).
set -euo pipefail

TELCOSEC_URL="${TELCOSEC_URL:-https://meta.telcosec.net}"
TELCOSEC_KEY="/etc/apt/keyrings/telcochisel-archive-keyring.asc"
TELCOSEC_SOURCES="/etc/apt/sources.list.d/telcochisel.sources"
TELCOSEC_FPR="6326A34C15FEF05FBD63518B4325182E2F0D9DB9"

mkdir -p /etc/apt/keyrings /etc/apt/sources.list.d

if ! command -v curl >/dev/null 2>&1 || ! command -v gpg >/dev/null 2>&1; then
  apt-get update -qq
  apt-get install -y -qq curl ca-certificates gnupg
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

if ! curl -fsSL "${TELCOSEC_URL}/public.gpg" -o "$TMP" 2>/dev/null || [ ! -s "$TMP" ]; then
  curl -fsSL "${TELCOSEC_URL}/telcosec.gpg" -o "$TMP"
fi

ACTUAL_FPR=$(gpg --show-keys --with-colons "$TMP" 2>/dev/null | awk -F: '$1=="fpr"{print $10; exit}')
if [ -z "$ACTUAL_FPR" ]; then
  echo "ERROR: could not read fingerprint from TelcoChisel APT key" >&2
  exit 1
fi
if [ "$ACTUAL_FPR" != "$TELCOSEC_FPR" ]; then
  echo "ERROR: TelcoChisel APT key fingerprint mismatch" >&2
  echo "Expected: $TELCOSEC_FPR" >&2
  echo "Actual:   $ACTUAL_FPR" >&2
  exit 1
fi

install -m 0644 "$TMP" "$TELCOSEC_KEY"
cat > "$TELCOSEC_SOURCES" << EOF
Types: deb
URIs: ${TELCOSEC_URL}
Suites: noble
Components: main
Signed-By: ${TELCOSEC_KEY}
EOF
chmod 0644 "$TELCOSEC_SOURCES"
echo "TelcoChisel APT key verified: $ACTUAL_FPR"
