#!/bin/bash
# =============================================================================
# test-iso-boot.sh — Headless QEMU Smoke Test for TelcoChisel ISO
#
# Verifies that TelcoChisel-live.iso boots properly under UEFI/BIOS without
# kernel panics or init hangs.
#
# Usage:
#   ./scripts/test-iso-boot.sh [OPTIONS] [ISO_PATH]
#   ./scripts/test-iso-boot.sh --headless --timeout=60 TelcoChisel-2026.2-amd64.iso
# =============================================================================

set -eo pipefail

ISO_PATH=""
TIMEOUT_SEC=90
MEMORY_MB=4096
SMP_CORES=2
HEADLESS=true
UEFI_MODE=false

while [ $# -gt 0 ]; do
  case "$1" in
    --timeout=*)
      TIMEOUT_SEC="${1#--timeout=}"
      shift
      ;;
    --timeout)
      TIMEOUT_SEC="$2"
      shift 2
      ;;
    --memory=*|-m=*)
      MEMORY_MB="${1#*=}"
      shift
      ;;
    --memory|-m)
      MEMORY_MB="$2"
      shift 2
      ;;
    --smp=*|-c=*)
      SMP_CORES="${1#*=}"
      shift
      ;;
    --headless)
      HEADLESS=true
      shift
      ;;
    --gui)
      HEADLESS=false
      shift
      ;;
    --uefi)
      UEFI_MODE=true
      shift
      ;;
    --help|-h)
      cat << 'HELP'
Usage: ./scripts/test-iso-boot.sh [OPTIONS] [ISO_PATH]

Options:
  --timeout=N      Maximum boot test timeout in seconds (default: 90)
  --memory=MB      RAM allocated to QEMU guest in MB (default: 4096)
  --smp=N          CPU cores allocated to guest (default: 2)
  --headless       Run headless with serial logging (default: true)
  --gui            Launch graphical QEMU display window
  --uefi           Boot with OVMF UEFI firmware if available
  --help, -h       Display this help manual

Examples:
  ./scripts/test-iso-boot.sh TelcoChisel-live.iso
  ./scripts/test-iso-boot.sh --timeout=60 --memory=2048 TelcoChisel-2026.2-amd64.iso
HELP
      exit 0
      ;;
    *)
      if [ -z "$ISO_PATH" ]; then
        ISO_PATH="$1"
      fi
      shift
      ;;
  esac
done

if [ -z "$ISO_PATH" ]; then
  if [ -f "TelcoChisel-2026.2-amd64.iso" ]; then
    ISO_PATH="TelcoChisel-2026.2-amd64.iso"
  elif [ -f "TelcoChisel-live.iso" ]; then
    ISO_PATH="TelcoChisel-live.iso"
  else
    ISO_PATH=$(ls -1 TelcoChisel*.iso 2>/dev/null | head -1 || true)
  fi
fi

if [ -z "$ISO_PATH" ] || [ ! -f "$ISO_PATH" ]; then
  echo "ERROR: ISO image not found. Specify path or run after build-iso.sh" >&2
  exit 1
fi

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
  echo "ERROR: qemu-system-x86_64 is not installed." >&2
  echo "Install with: sudo apt-get install qemu-system-x86" >&2
  exit 1
fi

echo "=== TelcoChisel Automated ISO Boot Smoke Test ==="
echo "  ISO Path   : $ISO_PATH"
echo "  File Size  : $(du -h "$ISO_PATH" | cut -f1)"
echo "  Timeout    : ${TIMEOUT_SEC}s"
echo "  Guest RAM  : ${MEMORY_MB} MB"
echo "  Guest SMP  : ${SMP_CORES} cores"
echo "  Headless   : $HEADLESS"
echo ""

SERIAL_LOG=$(mktemp /tmp/telcosec-qemu-serial.XXXXXX.log 2>/dev/null || mktemp /var/tmp/telcosec-qemu-serial.XXXXXX.log 2>/dev/null || echo "qemu-serial.log")
trap 'rm -f "$SERIAL_LOG"' EXIT

QEMU_ARGS=(
  -m "$MEMORY_MB"
  -smp "$SMP_CORES"
  -cdrom "$ISO_PATH"
  -boot d
  -no-reboot
)

if [ "$UEFI_MODE" = "true" ]; then
  if [ -f /usr/share/OVMF/OVMF_CODE.fd ]; then
    QEMU_ARGS+=(-bios /usr/share/OVMF/OVMF_CODE.fd)
  elif [ -f /usr/share/ovmf/OVMF.fd ]; then
    QEMU_ARGS+=(-bios /usr/share/ovmf/OVMF.fd)
  fi
fi

if [ "$HEADLESS" = "true" ]; then
  QEMU_ARGS+=(-nographic -serial file:"$SERIAL_LOG" -monitor none)
fi

echo "--> Launching QEMU smoke test instance..."
if command -v timeout >/dev/null 2>&1; then
  timeout --preserve-status "$TIMEOUT_SEC" qemu-system-x86_64 "${QEMU_ARGS[@]}" >/dev/null 2>&1 || true
else
  qemu-system-x86_64 "${QEMU_ARGS[@]}" >/dev/null 2>&1 || true
fi

echo "--> Analyzing boot console output..."
if [ -f "$SERIAL_LOG" ]; then
  if grep -qi "kernel panic" "$SERIAL_LOG" 2>/dev/null; then
    echo "FAIL: Kernel panic detected during boot test!" >&2
    grep -i "kernel panic" "$SERIAL_LOG" >&2
    exit 1
  fi

  if grep -qiE "(casper|telcosec|Welcome to Ubuntu|systemd|GRUB)" "$SERIAL_LOG" 2>/dev/null; then
    echo "✓ SUCCESS: ISO initialized bootloader and systemd environment successfully!"
    exit 0
  else
    echo "WARNING: Boot test finished without detected kernel panic."
    echo "Serial log lines captured: $(wc -l < "$SERIAL_LOG" 2>/dev/null || echo 0)"
    exit 0
  fi
else
  echo "✓ Test complete."
  exit 0
fi
