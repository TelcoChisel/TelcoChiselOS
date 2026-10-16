# shellcheck shell=bash
# =============================================================================
# build-tool.sh — shared git clone helpers for build-time provisioning
#
# NOTE: the first-run helper scripts (srsran-install, yatebts-install, ...)
# are generated from heredocs and execute after boot — they cannot source
# this lib and must stay self-contained. Use these helpers only in code that
# runs at build time.
#
#   clone_if_missing <url> <dir> [git-args...]   — fatal-on-failure clone guard
#   clone_bg <url> <dir>                          — start background clone
#   wait_clones <label>                           — wait, report failures, return rc
# =============================================================================

GIT_QUIET_ARGS=(--depth 1)

# Prevent git from ever prompting interactively for credentials during automated builds
export GIT_TERMINAL_PROMPT=0

# _clone_git <url> <dir> [ref] [extra git-args...]
# If ref is set and does not start with '-', clone that branch/tag (pinned).
# Falls back to unpinned depth-1 clone if the ref is missing (typo / renamed tag).
_clone_git() {
  local url="$1" dir="$2" ref="" 
  shift 2
  if [ $# -gt 0 ] && [[ "${1:-}" != -* ]]; then
    ref="$1"
    shift
  fi
  if [ -n "$ref" ]; then
    echo "  [clone] $dir @ $ref"
    if git clone "${GIT_QUIET_ARGS[@]}" --branch "$ref" "$@" "$url" "$dir"; then
      return 0
    fi
    echo "  [clone] WARN: ref '$ref' unavailable — falling back to default branch" >&2
    rm -rf "$dir"
  else
    echo "  [clone] $dir (floating default branch)"
  fi
  git clone "${GIT_QUIET_ARGS[@]}" "$@" "$url" "$dir"
}

clone_if_missing() {
  local url="$1" dir="$2"; shift 2
  if [ -d "$dir" ]; then
    echo "  [clone] $dir already present — skipping"
    return 0
  fi
  if ! _clone_git "$url" "$dir" "$@"; then
    echo "  [clone] FAILED: $url" >&2
    return 1
  fi
}

# Track in-flight background clones (bash arrays, name -> pid)
declare -A _BG_CLONE_PIDS 2>/dev/null || true

# clone_bg <url> <dir> [ref] [extra git-args...]
clone_bg() {
  local url="$1" dir="$2"; shift 2 || true
  if [ -d "$dir" ]; then
    echo "  [clone] $dir already present — skipping"
    return 0
  fi
  (
    local err_file
    err_file=$(mktemp)
    if ! _clone_git "$url" "$dir" "$@" >/dev/null 2>"$err_file"; then
      echo "  [clone] FAILED: $url" >&2
      if [ -s "$err_file" ]; then
        sed 's/^/    [git] /' "$err_file" >&2
      fi
      rm -f "$err_file"
      exit 1
    fi
    rm -f "$err_file"
  ) &
  _BG_CLONE_PIDS["$(basename "$dir")"]=$!
}

wait_clones() {
  local label="${1:-clones}" name fail=0
  for name in "${!_BG_CLONE_PIDS[@]}"; do
    if ! wait "${_BG_CLONE_PIDS[$name]}"; then
      echo "  $label: clone failed: $name" >&2
      fail=1
    fi
  done
  _BG_CLONE_PIDS=()
  return "$fail"
}

# ── CPU / Build Concurrency Limiter ──────────────────────────────────────────
# Guarantees that compilation jobs never starve host cores or lock up the machine.
# Leaves at least 2 cores free for the host OS when nproc > 4.
get_build_procs() {
  if [ -n "${BUILD_PROCS:-}" ]; then
    echo "$BUILD_PROCS"
    return
  fi
  local n
  n=$(nproc 2>/dev/null || echo 2)
  if [ "$n" -gt 4 ]; then
    echo $(( n - 2 ))
  elif [ "$n" -gt 1 ]; then
    echo $(( n - 1 ))
  else
    echo 1
  fi
}
