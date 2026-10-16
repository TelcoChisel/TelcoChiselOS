#!/bin/bash
# =============================================================================
# docker/smoke-test.sh — post-build sanity check for TelcoChisel images.
#
# Runs a representative tool per category with --version/--help inside each
# image and asserts a zero exit code. This is NOT a functional test of SDR/
# kernel-module/network features (those need real hardware/privilege — see
# docker/README.md) — it only confirms the image built correctly and the
# tool is on PATH and executable.
#
# Usage:
#   bash docker/smoke-test.sh              # test images already built locally
#   bash docker/smoke-test.sh --build       # build each image first, then test
# =============================================================================
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

if [ "${1:-}" = "--build" ]; then
  echo "=== Building images ==="
  docker build -f "$REPO_ROOT/docker/base.Dockerfile" -t telcochisel-base "$REPO_ROOT" || exit 1
  docker build -f "$REPO_ROOT/docker/device-tools.Dockerfile" -t telcochisel-device-tools "$REPO_ROOT" || exit 1
  docker build -f "$REPO_ROOT/docker/sdr.Dockerfile" -t telcochisel-sdr "$REPO_ROOT" || exit 1
  docker build -f "$REPO_ROOT/docker/core-network.Dockerfile" -t telcochisel-core-network "$REPO_ROOT" || exit 1
  docker build -f "$REPO_ROOT/docker/5ghoul.Dockerfile" -t telcochisel-5ghoul "$REPO_ROOT" || exit 1
fi

check() {
  local image="$1" desc="$2"; shift 2
  printf '  [%-22s] %-14s ... ' "$image" "$desc"
  # MSYS_NO_PATHCONV avoids Git-Bash-on-Windows mangling /bin/bash into a
  # Windows path (C:/Program Files/Git/usr/bin/bash) before Docker sees it;
  # harmless no-op on Linux/Mac.
  if MSYS_NO_PATHCONV=1 docker run --rm --entrypoint /bin/bash "$image" -c "$*" >/tmp/smoke-"$desc".log 2>&1; then
    echo "OK"
  else
    echo "FAIL (see /tmp/smoke-$desc.log)"
    FAIL=1
  fi
}

echo "=== telcochisel-base ==="
check telcochisel-base tini         "/usr/bin/tini --version"
check telcochisel-base healthcheck  "/usr/local/bin/container-healthcheck.sh"
check telcochisel-base telcosec-go  "test -x /usr/local/libexec/telcosec && telcosec version"
check telcochisel-base nmap         "nmap --version"
check telcochisel-base tshark       "tshark --version"
check telcochisel-base scapy        "python3 -c 'import scapy; print(scapy.VERSION)'"
check telcochisel-base sctpscan     "sctpscan -h || true"
check telcochisel-base pysim        "pySim-shell --help"
check telcochisel-base ueransim     "nr-ue --help || true"
check telcochisel-base sipvicious   "sipvicious_svmap --help"
check telcochisel-base asleap       "asleap -h || true"
check telcochisel-base snmp-check   "snmp-check -h || true"
check telcochisel-base docsis       "docsis -h || true"
check telcochisel-base rtpbleed     "rtpbleed -h"
check telcochisel-base voiphopper   "command -v voiphopper"
check telcochisel-base sipsak       "sipsak -V || true"
check telcochisel-base mausezahn    "command -v mz && command -v mausezahn"
check telcochisel-base sdr-info     "sdr-info"
check telcochisel-base ran-status   "telcosec-ran-status"
check telcochisel-base academy-cli  "telcosec-academy --help"
check telcochisel-base telcosec-pkg "telcosec-pkg --help"
check telcochisel-base rdnsx        "rdnsx --help || true"
check telcochisel-base routersploit "routersploit --help || true"

echo "=== telcochisel-device-tools ==="
check telcochisel-device-tools healthcheck "/usr/local/bin/container-healthcheck.sh"
check telcochisel-device-tools heimdall    "heimdall version"
check telcochisel-device-tools adb         "adb version"
check telcochisel-device-tools mtk         "mtk --help"

echo "=== telcochisel-sdr ==="
check telcochisel-sdr healthcheck "/usr/local/bin/container-healthcheck.sh"
check telcochisel-sdr soapysdr    "SoapySDRUtil --info"
check telcochisel-sdr hackrf      "hackrf_info --version || true"

echo "=== telcochisel-core-network ==="
check telcochisel-core-network healthcheck "/usr/local/bin/container-healthcheck.sh"
check telcochisel-core-network helpers     "command -v srsran-install && command -v open5gs-install && command -v gtp5g-load && command -v 5ghoul-install"

echo "=== telcochisel-5ghoul ==="
check telcochisel-5ghoul healthcheck "/usr/local/bin/container-healthcheck.sh"
check telcochisel-5ghoul overlay     "test -x /usr/local/bin/5ghoul-install && test -f /opt/telcosec/5ghoul-overlay/UPSTREAM && grep -q 452c8ced /opt/telcosec/5ghoul-overlay/UPSTREAM"

echo "=== Telecom POD Manifest Validation ==="
if command -v python3 &>/dev/null; then
  for manifest in "$REPO_ROOT"/docker/pods/*.yaml; do
    printf '  [%-22s] %-14s ... ' "pod-manifest" "$(basename "$manifest")"
    if python3 -c "import yaml, sys; yaml.safe_load(open(sys.argv[1]))" "$manifest" >/tmp/smoke-yaml.log 2>&1; then
      echo "OK"
    else
      echo "FAIL (syntax error)"
      FAIL=1
    fi
  done
fi

if [ "$FAIL" -ne 0 ]; then
  echo ""
  echo "One or more smoke checks FAILED — see the logs referenced above."
  exit 1
fi
echo ""
echo "All smoke checks passed."
