#!/usr/bin/env bash
set -euo pipefail

KEY_EMAIL="repo@telcochisel.com"
KEY_NAME="TelcoSec Package Signing Key"
KEY_COMMENT="TelcoChisel Official APT Repository"

# The one true production signing key. The repo is published to clients that
# verify this fingerprint (TELCOSEC_FPR in TelcoChiselOS 00-install-all-packages.sh
# and install-telcochisel-repo.sh). CI MUST sign with exactly this key — never a
# freshly generated one, or every client's apt enrollment breaks.
EXPECTED_FPR="3DDEADD34827571266C41601C3BB61613B110128"

mkdir -p ~/.gnupg
chmod 700 ~/.gnupg
echo "allow-loopback-pinentry" >> ~/.gnupg/gpg-agent.conf
echo "pinentry-mode loopback" >> ~/.gnupg/gpg.conf
gpgconf --reload gpg-agent 2>/dev/null || true

KEY_IMPORTED=0
if [ -n "${GPG_PRIVATE_KEY:-}" ]; then
    if echo "${GPG_PRIVATE_KEY}" | gpg --batch --import 2>/dev/null; then
        echo "[+] Successfully imported GPG_PRIVATE_KEY directly."
        KEY_IMPORTED=1
    elif echo "${GPG_PRIVATE_KEY}" | base64 -d 2>/dev/null | gpg --batch --import 2>/dev/null; then
        echo "[+] Successfully imported base64-decoded GPG_PRIVATE_KEY."
        KEY_IMPORTED=1
    fi
fi

# FAIL LOUDLY instead of generating a throwaway key. Silently generating a new
# key (the previous behaviour) re-keys the repo and bricks client enrollment,
# because clients pin EXPECTED_FPR. A missing/invalid secret must stop the build.
if [ "${KEY_IMPORTED}" -eq 0 ]; then
    echo "::error::GPG_PRIVATE_KEY secret is missing or failed to import." >&2
    echo "        Refusing to generate a new signing key (that would re-key the" >&2
    echo "        repo and break every client that pins ${EXPECTED_FPR})." >&2
    echo "        Set GPG_PRIVATE_KEY to the private key for ${EXPECTED_FPR}." >&2
    exit 1
fi

# Verify the imported key is the authoritative one before any signing happens.
if ! gpg --list-secret-keys --with-colons 2>/dev/null \
        | awk -F: '$1=="fpr"{print $10}' | grep -qx "${EXPECTED_FPR}"; then
    echo "::error::Imported GPG key fingerprint does not match the expected" >&2
    echo "        production key ${EXPECTED_FPR}." >&2
    echo "        Imported fingerprints were:" >&2
    gpg --list-secret-keys --with-colons 2>/dev/null \
        | awk -F: '$1=="fpr"{print "          "$10}' >&2
    echo "        Publishing with the wrong key would break client enrollment." >&2
    exit 1
fi

echo "[+] Verified signing key ${EXPECTED_FPR} is present."
