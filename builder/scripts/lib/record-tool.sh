#!/bin/bash
# =============================================================================
# lib/record-tool.sh — TelcoChisel build-result verification helper
#
# Provides record_tool() — call it after every tool build to record whether
# the expected artifact (binary or path) landed. Results are appended to:
#   /var/log/telcosec-build-tools.log  (human-readable, build-time)
#   /usr/share/telcosec/tool-manifest.txt (machine-readable, ships in the ISO)
#
# Usage (source this file first, then call):
#   source /path/to/lib/record-tool.sh
#   record_tool "UERANSIM" "/usr/local/bin/nr-ue"
#   record_tool "LTESniffer" "/opt/telcosec/LTESniffer/build/src/LTESniffer"
#
# Arguments:
#   $1  tool_name   — display name (e.g. "UERANSIM", "gr-gsm")
#   $2  artifact    — absolute path to binary or file that must exist after build
#   $3  category    — optional category tag (default: "tool")
#
# The function always returns 0 so callers can use it after || true builds
# without the script aborting due to set -e.
# =============================================================================

_TELCOSEC_LOG=/var/log/telcosec-build-tools.log
_TELCOSEC_MANIFEST=/usr/share/telcosec/tool-manifest.txt

# Ensure destination directories exist (safe to call in chroot)
_record_tool_init() {
  mkdir -p /var/log /usr/share/telcosec
  if [ ! -f "$_TELCOSEC_LOG" ]; then
    echo "# TelcoChisel build-tool log — $(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
      > "$_TELCOSEC_LOG"
  fi
  if [ ! -f "$_TELCOSEC_MANIFEST" ]; then
    printf '# tool-manifest.txt — TelcoChisel %s\n' \
      "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" > "$_TELCOSEC_MANIFEST"
    printf '# Format: STATUS\tCATEGORY\tNAME\tARTIFACT\n' \
      >> "$_TELCOSEC_MANIFEST"
  fi
}

record_tool() {
  local tool_name="${1:-unknown}"
  local artifact="${2:-}"
  local category="${3:-tool}"
  local status ts

  _record_tool_init

  ts="$(date -u '+%H:%M:%SZ')"

  if [ -n "$artifact" ] && [ -e "$artifact" ]; then
    status="PASS"
  else
    status="FAIL"
  fi

  # Human-readable log
  printf '[%s] %-4s  %-12s  %s  (%s)\n' \
    "$ts" "$status" "$category" "$tool_name" "${artifact:-<no artifact specified>}" \
    >> "$_TELCOSEC_LOG"

  # Machine-readable manifest (shipped in ISO)
  printf '%s\t%s\t%s\t%s\n' \
    "$status" "$category" "$tool_name" "${artifact:-}" \
    >> "$_TELCOSEC_MANIFEST"

  if [ "$status" = "FAIL" ]; then
    echo "  !! BUILD WARNING: $tool_name — artifact not found: ${artifact:-<unspecified>}" >&2
  fi

  return 0  # never abort the build
}

# Print a summary of FAIL entries from the manifest.
# Called by build-iso.sh after all provisioning scripts complete.
record_tool_summary() {
  if [ ! -f "$_TELCOSEC_MANIFEST" ]; then
    echo "  (no tool manifest found — provisioning may not have run)"
    return 0
  fi

  local total pass fail
  total=$(grep -c '^PASS\|^FAIL' "$_TELCOSEC_MANIFEST" 2>/dev/null || echo 0)
  pass=$(grep  -c '^PASS' "$_TELCOSEC_MANIFEST" 2>/dev/null || echo 0)
  fail=$(grep  -c '^FAIL' "$_TELCOSEC_MANIFEST" 2>/dev/null || echo 0)

  echo ""
  echo "╔══════════════════════════════════════════════╗"
  echo "║  TelcoChisel Tool Build Summary             ║"
  printf "║  %d tools verified   PASS: %d   FAIL: %d%*s║\n" \
    "$total" "$pass" "$fail" \
    "$((10 - ${#total} - ${#pass} - ${#fail}))" ""
  echo "╚══════════════════════════════════════════════╝"

  if [ "$fail" -gt 0 ]; then
    echo ""
    echo "  FAILED tools (will be missing from the live image):"
    grep '^FAIL' "$_TELCOSEC_MANIFEST" | while IFS=$'\t' read -r _status _cat name artifact; do
      printf "    • %-28s  %s\n" "$name" "$artifact"
    done
    echo ""
    echo "  Full log: $_TELCOSEC_LOG"
    # Default: fail the ISO build when any instrumented tool is missing.
    # Override for intentional best-effort builds:
    #   TELCOSEC_ALLOW_TOOL_FAILURES=1 ./build-iso.sh ...
    if [ "${TELCOSEC_ALLOW_TOOL_FAILURES:-0}" = "1" ]; then
      echo "  WARNING: TELCOSEC_ALLOW_TOOL_FAILURES=1 — continuing despite $fail FAIL(s)."
      return 0
    fi
    echo "  ERROR: $fail tool build(s) failed. Set TELCOSEC_ALLOW_TOOL_FAILURES=1 to override."
    return 1
  fi

  return 0
}
