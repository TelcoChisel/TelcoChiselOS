#!/bin/bash
# shellcheck shell=bash
# =============================================================================
# lib/pip-retry.sh — shared pip retry helpers
#
# pip's own --retries does NOT catch SSL DECRYPTION_FAILED errors on large
# wheel downloads (urllib3 treats them as non-retriable), so these wrap pip
# invocations with a shell-level retry loop. Originally written inline in
# 06-install-ue-analysis.sh; extracted here so every script that does network
# pip installs (04, 06, 09, 10, 11) shares one implementation instead of each
# re-inventing (or omitting) the same resilience.
#
# Usage: source this file, then call `pip_retry install <pkg>` or
# `sudo_pip_retry install <pkg>` exactly like you would call pip3/`sudo pip3`.
# Both are non-fatal after 3 attempts (return 0) so a persistent network
# failure doesn't abort the whole provisioning script under `set -e` — the
# caller should follow up with `record_tool` to make the failure observable.
#
# Both also auto-apply lib/pip-constraints.txt (if present) to every `install`
# call via `-c`, so a version pin declared there holds across every script
# that uses this helper — see that file for what it's for and when to add to
# it. The constraints path is resolved from THIS file's own location, not the
# caller's, so it works regardless of which script sources pip-retry.sh.
# =============================================================================

_PIP_RETRY_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_PIP_CONSTRAINTS="${_PIP_RETRY_LIB_DIR}/pip-constraints.txt"

pip_retry() {
  local attempt
  local extra_args=()
  if [ "$1" = "install" ]; then
    extra_args=(--break-system-packages --ignore-installed)
    [ -f "$_PIP_CONSTRAINTS" ] && extra_args+=(-c "$_PIP_CONSTRAINTS")
  fi
  for attempt in 1 2 3; do
    pip3 "$@" "${extra_args[@]}" && return 0
    echo "  pip attempt $attempt/3 failed — retrying in 15s..."
    sleep 15
  done
  echo "  WARNING: pip install failed after 3 attempts (non-fatal): pip3 $*" >&2
  return 0
}

sudo_pip_retry() {
  local attempt
  local extra_args=()
  if [ "$1" = "install" ]; then
    extra_args=(--break-system-packages --ignore-installed)
    [ -f "$_PIP_CONSTRAINTS" ] && extra_args+=(-c "$_PIP_CONSTRAINTS")
  fi
  for attempt in 1 2 3; do
    sudo pip3 "$@" "${extra_args[@]}" && return 0
    echo "  pip attempt $attempt/3 failed — retrying in 15s..."
    sleep 15
  done
  echo "  WARNING: pip install failed after 3 attempts (non-fatal): sudo pip3 $*" >&2
  return 0
}

venv_pip_retry() {
  local pip_cmd="$1"
  shift
  local attempt
  local extra_args=()
  if [ "$1" = "install" ]; then
    extra_args=(--ignore-installed)
    [ -f "$_PIP_CONSTRAINTS" ] && extra_args+=(-c "$_PIP_CONSTRAINTS")
  fi
  for attempt in 1 2 3; do
    "$pip_cmd" "$@" "${extra_args[@]}" && return 0
    echo "  pip attempt $attempt/3 failed — retrying in 15s..."
    sleep 15
  done
  echo "  WARNING: pip install failed after 3 attempts (non-fatal): $pip_cmd $*" >&2
  return 0
}
