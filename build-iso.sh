#!/bin/bash
set -eo pipefail

# ─── Argument parsing ─────────────────────────────────────────────────────────
RESUME=false
RESUME_FROM=0
PACK_ONLY=false
ISO_VERSION="${ISO_VERSION:-}"

# ─── Build tuning (override via env) ──────────────────────────────────────────
# SQUASHFS_LEVEL: zstd compression level (1-19). 3=fast/CI, 6=balanced (default, 8-10x faster), 19=max.
SQUASHFS_LEVEL="${SQUASHFS_LEVEL:-6}"
# USE_CCACHE=1: bind-mount host ccache into chroot; speeds up repeated C++ builds.
USE_CCACHE="${USE_CCACHE:-0}"
CCACHE_DIR_HOST="${CCACHE_DIR:-/root/.ccache}"
# APT_PROXY: apt-cacher-ng proxy URL, e.g. http://localhost:3142
APT_PROXY="${APT_PROXY:-}"
BUILD_FLAVOR="${BUILD_FLAVOR:-full}"

while [ $# -gt 0 ]; do
  case "$1" in
    --version=*)
      ISO_VERSION="${1#--version=}"
      shift
      ;;
    --version)
      if [ -n "$2" ] && [[ "$2" != --* ]]; then
        ISO_VERSION="$2"
        shift 2
      else
        echo "ERROR: --version requires an argument" >&2
        exit 1
      fi
      ;;
    --flavor=*)
      BUILD_FLAVOR="${1#--flavor=}"
      shift
      ;;
    --flavor)
      if [ -n "$2" ] && [[ "$2" != --* ]]; then
        BUILD_FLAVOR="$2"
        shift 2
      else
        echo "ERROR: --flavor requires an argument (full or lite)" >&2
        exit 1
      fi
      ;;
    --lite)
      BUILD_FLAVOR="lite"
      shift
      ;;
    --full)
      BUILD_FLAVOR="full"
      shift
      ;;
    --resume)
      RESUME=true
      shift
      ;;
    --resume-from=*)
      RESUME=true
      RESUME_FROM="${1#--resume-from=}"
      # Strip leading zeros for numeric comparison, keep at least "0"
      RESUME_FROM=$(( 10#${RESUME_FROM} ))
      shift
      ;;
    --resume-from)
      if [ -n "$2" ] && [[ "$2" != --* ]]; then
        RESUME=true
        RESUME_FROM=$(( 10#${2} ))
        shift 2
      else
        echo "ERROR: --resume-from requires a phase number" >&2
        exit 1
      fi
      ;;
    --pack-only)
      PACK_ONLY=true
      shift
      ;;
    --help|-h)
      cat << 'HELP'
Usage: sudo ./build-iso.sh [OPTIONS]

  (no options)           Full clean build — wipes chroot and starts fresh
  --flavor=FLAVOR        Build flavor: full (default, all 100 tools offline) or
                           lite (~1.8 GB, base desktop + telcosec-pkg)
  --lite                 Shortcut for --flavor=lite
  --full                 Shortcut for --flavor=full
  --version=VER          Specify release version (e.g. v1.2.0, 1.2.0, nightly)
  --resume               Keep existing chroot; re-run all provisioning phases
  --resume-from=N        Keep existing chroot; skip phases before N
                           e.g. --resume-from=03  resumes from phase 03
                           e.g. --resume-from=7   resumes from phase 07
  --pack-only            Skip provisioning entirely; pack existing chroot into
                           squashfs + ISO (useful for re-signing or re-branding)

Examples:
  sudo ./build-iso.sh                    # fresh full Field Edition build (~5.0 GB)
  sudo ./build-iso.sh --lite             # build Modular Lite Edition ISO (~1.8 GB)
  sudo ./build-iso.sh --version=2026.2   # build versioned TelcoChisel-2026.2-amd64.iso
  sudo ./build-iso.sh --resume           # re-run everything on existing chroot
  sudo ./build-iso.sh --resume-from=04   # skip 00-03, resume from 04 onward
  sudo ./build-iso.sh --pack-only        # just repack squashfs → ISO

HELP
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option: $1  (try --help)"
      exit 1
      ;;
  esac
done

if [ "$BUILD_FLAVOR" != "full" ] && [ "$BUILD_FLAVOR" != "lite" ]; then
  echo "ERROR: Unsupported flavor '$BUILD_FLAVOR'. Valid options: full, lite." >&2
  exit 1
fi
export BUILD_FLAVOR

if [ "$BUILD_FLAVOR" = "lite" ]; then
  DISTRO_FLAVOR_LABEL="Lite Edition"
else
  DISTRO_FLAVOR_LABEL="Field Edition"
fi

# Resolve version if unset
if [ -z "$ISO_VERSION" ]; then
  git config --global --add safe.directory "$PWD" 2>/dev/null || true
  if [ -f "VERSION" ]; then
    ISO_VERSION=$(head -n 1 VERSION | tr -d '[:space:]')
  else
    ISO_VERSION=$(git describe --tags --abbrev=0 2>/dev/null || git describe --tags --always 2>/dev/null || echo "2026.1")
  fi
fi
# Normalize version: strip leading 'v'
ISO_VERSION="${ISO_VERSION#v}"

# Resolve human-readable flavor label
if [ "$BUILD_FLAVOR" = "lite" ]; then
  DISTRO_FLAVOR_LABEL="Lite Edition"
else
  DISTRO_FLAVOR_LABEL="Field Edition"
fi

# ─── Header ───────────────────────────────────────────────────────────────────
echo "=== TelcoChisel ISO Builder ==="
echo "    Version: $ISO_VERSION"
echo "    Flavor:  $BUILD_FLAVOR ($DISTRO_FLAVOR_LABEL)"
if $PACK_ONLY; then
  echo "    Mode: pack-only (repack existing chroot)"
elif $RESUME && [ "$RESUME_FROM" -gt 0 ]; then
  echo "    Mode: resume from phase $(printf '%02d' $RESUME_FROM)"
elif $RESUME; then
  echo "    Mode: resume (keep chroot, re-run all phases)"
else
  echo "    Mode: full clean build"
fi
BUILD_START=$(date +%s)

# ─── Root check ───────────────────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  echo "ERROR: Run as root (sudo ./build-iso.sh)"
  exit 1
fi

# ─── Prerequisite check ───────────────────────────────────────────────────────
echo "--> Checking prerequisites..."
MISSING=()
for tool in debootstrap mksquashfs grub-mkrescue xorriso mformat; do
  command -v "$tool" >/dev/null 2>&1 || MISSING+=("$tool")
done
if [ ${#MISSING[@]} -gt 0 ]; then
  echo "ERROR: Missing required tools: ${MISSING[*]}"
  echo "Install with: apt-get install debootstrap squashfs-tools grub-pc-bin grub-efi-amd64-bin xorriso mtools"
  exit 1
fi

# Secure Boot support is optional at the tool-check level (the ISO still boots
# fine on non-Secure-Boot UEFI and legacy BIOS without it) but recommended —
# without shim-signed + grub-efi-amd64-signed on the HOST, modern UEFI machines
# with Secure Boot enabled will refuse to boot this ISO. See the retrofit step
# after grub-mkrescue below.
if ! dpkg -s shim-signed >/dev/null 2>&1 || ! dpkg -s grub-efi-amd64-signed >/dev/null 2>&1; then
  echo "  WARNING: shim-signed / grub-efi-amd64-signed not installed on this host —"
  echo "  the built ISO will NOT boot on Secure-Boot-enabled UEFI machines."
  echo "  Install with: apt-get install shim-signed grub-efi-amd64-signed"
fi

# ─── Work directory ───────────────────────────────────────────────────────────
# 9p/drvfs/NTFS mounts don't support POSIX special files needed by debootstrap.
FS_TYPE=$(df -T . | awk 'NR==2 {print $2}')
if [[ "$FS_TYPE" =~ ^(9p|drvfs|vboxsf|fuse|cifs|nfs|vfat|ntfs|msdos)$ ]]; then
  echo "--> Non-POSIX filesystem ($FS_TYPE) — redirecting build to /var/tmp/live-iso-work"
  WORKDIR="/var/tmp/live-iso-work"
else
  WORKDIR="live-iso-work"
fi

ROOTFS="$WORKDIR/chroot"

# Shared chroot service-suppression helpers (builder/scripts/lib/)
source "$(pwd)/builder/scripts/lib/chroot-suppress.sh"
if [ "$BUILD_FLAVOR" = "lite" ]; then
  IMAGE_NAME="TelcoChisel-${ISO_VERSION}-lite-amd64.iso"
else
  IMAGE_NAME="TelcoChisel-${ISO_VERSION}-amd64.iso"
fi

# ─── Mount cleanup ────────────────────────────────────────────────────────────
cleanup() {
  restore_chroot_services "$ROOTFS"
  if [ -d "$ROOTFS" ]; then
    awk -v r="$ROOTFS" '$2 ~ "^"r {print $2}' /proc/mounts 2>/dev/null | sort -r | while read -r mnt; do
      fuser -k -9 "$mnt" 2>/dev/null || true
      umount -lf "$mnt" 2>/dev/null || true
    done
  fi
  umount -lf "$ROOTFS/root/.ccache" 2>/dev/null || true
  umount -lf "$ROOTFS/dev/pts" 2>/dev/null || true
  umount -lf "$ROOTFS/dev"     2>/dev/null || true
  umount -lf "$ROOTFS/sys"     2>/dev/null || true
  umount -lf "$ROOTFS/proc"    2>/dev/null || true
}
trap cleanup EXIT

# ─── Chroot setup ─────────────────────────────────────────────────────────────
if $PACK_ONLY; then
  # ── pack-only: existing chroot must exist ───────────────────────────────────
  if [ ! -d "$ROOTFS" ]; then
    echo "ERROR: --pack-only requires an existing chroot at $ROOTFS"
    echo "       Run without flags to create one first."
    exit 1
  fi
  echo "--> Using existing chroot at $ROOTFS (pack-only mode)"

elif $RESUME; then
  # ── resume: keep existing chroot ────────────────────────────────────────────
  if [ ! -d "$ROOTFS" ]; then
    echo "ERROR: --resume requires an existing chroot at $ROOTFS"
    echo "       Run without flags to create one first."
    exit 1
  fi
  echo "--> Resuming with existing chroot at $ROOTFS"

  # Tear down any lingering mounts from a previous interrupted run
  cleanup

  # ── Re-apply service suppression (removed at end of each run) ───────────────
  echo "--> Re-applying chroot service suppression..."
  suppress_chroot_services "$ROOTFS"

  # Re-copy builder assets (scripts may have changed since last run)
  echo "--> Re-syncing builder assets into chroot..."
  rm -rf "$ROOTFS/tmp/scripts" && cp -r builder/scripts "$ROOTFS/tmp/scripts"
  rm -rf "$ROOTFS/tmp/calamares-config" && cp -r builder/calamares "$ROOTFS/tmp/calamares-config"
  rm -rf "$ROOTFS/tmp/docs" && cp -r builder/docs "$ROOTFS/tmp/docs"
  rm -rf "$ROOTFS/tmp/udev" && cp -r builder/udev "$ROOTFS/tmp/udev"
  rm -rf "$ROOTFS/tmp/modprobe" && cp -r builder/modprobe "$ROOTFS/tmp/modprobe"
  rm -rf "$ROOTFS/tmp/security" && cp -r builder/security "$ROOTFS/tmp/security"
  rm -rf "$ROOTFS/tmp/menu" && cp -r builder/menu "$ROOTFS/tmp/menu"
  rm -rf "$ROOTFS/tmp/wireshark" && cp -r builder/wireshark "$ROOTFS/tmp/wireshark"
  rm -rf "$ROOTFS/tmp/boot" && cp -r builder/boot "$ROOTFS/tmp/boot"
  rm -rf "$ROOTFS/tmp/wordlists" && cp -r builder/wordlists "$ROOTFS/tmp/wordlists"
  rm -rf "$ROOTFS/tmp/icons" && cp -r builder/icons "$ROOTFS/tmp/icons" 2>/dev/null || true
  # Bug 4 fix: sync telcosec-cli package (was missing from the resume path
  # even though the full-build path copies it — any resumed build that needs
  # /tmp/telcosec-cli inside the chroot was reading a stale/empty directory).
  if [ -d packages/telcosec-cli ]; then
    rm -rf "$ROOTFS/tmp/telcosec-cli" && cp -r packages/telcosec-cli "$ROOTFS/tmp/telcosec-cli"
  fi
  if [ -d packages/5ghoul-5g-nr-attacks/scripts ]; then
    rm -rf "$ROOTFS/tmp/5ghoul-overlay"
    mkdir -p "$ROOTFS/tmp/5ghoul-overlay"
    cp -a packages/5ghoul-5g-nr-attacks/UPSTREAM packages/5ghoul-5g-nr-attacks/scripts "$ROOTFS/tmp/5ghoul-overlay/"
  fi
  # Guarantee Unix LF line endings across all copied builder assets inside chroot
  find "$ROOTFS/tmp" -type f -exec sed -i -e 's/\r$//' {} + 2>/dev/null || true

  # Re-mount virtual filesystems
  echo "--> Mounting virtual filesystems..."
  mkdir -p "$ROOTFS/proc" "$ROOTFS/sys" "$ROOTFS/dev"
  mount -t proc  /proc "$ROOTFS/proc"
  mount -t sysfs /sys  "$ROOTFS/sys"
  mount --bind   /dev  "$ROOTFS/dev"
  mount --bind   /dev/pts "$ROOTFS/dev/pts"

  # Recover from any interrupted dpkg transactions from previous runs
  echo "--> Checking chroot package manager state..."
  chroot "$ROOTFS" dpkg --configure -a 2>/dev/null || true

else
  # ── Full clean build ─────────────────────────────────────────────────────────
  cleanup  # clear any leftover mounts from a previous run

  if [ -d "$ROOTFS" ]; then
    echo "--> Removing old chroot..."
    rm -rf "$ROOTFS"
  fi
  mkdir -p "$ROOTFS"

  # Debootstrap
  echo "--> Bootstrapping Ubuntu 24.04 Noble..."
  debootstrap \
    --arch=amd64 \
    --include=ca-certificates,locales \
    noble "$ROOTFS" http://archive.ubuntu.com/ubuntu/

  # APT sources
  echo "--> Configuring APT sources..."
  cat > "$ROOTFS/etc/apt/sources.list" << 'SOURCES'
deb http://archive.ubuntu.com/ubuntu noble           main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu noble-updates   main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu noble-security main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu noble-backports main restricted universe multiverse
SOURCES

  # Basic chroot environment
  echo "--> Preparing chroot environment..."
  echo "TelcoChisel" > "$ROOTFS/etc/hostname"
  cat > "$ROOTFS/etc/hosts" << 'HOSTS'
127.0.0.1   localhost
127.0.1.1   TelcoChisel
::1         localhost ip6-localhost ip6-loopback
HOSTS
  cp /etc/resolv.conf "$ROOTFS/etc/resolv.conf" 2>/dev/null || true

  # Locale generation
  # debootstrap includes the locales package but doesn't generate any locale
  # files. Package postinstalls (kismet, etc.) fail with "Cannot set LC_ALL"
  # until at least one locale exists.
  echo "en_US.UTF-8 UTF-8" > "$ROOTFS/etc/locale.gen"
  chroot "$ROOTFS" locale-gen
  chroot "$ROOTFS" update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 LC_CTYPE=en_US.UTF-8

  # Chroot service suppression
  # Hardware package postinstalls call udevadm/invoke-rc.d which fail inside
  # a chroot. Suppress them for the entire provisioning phase.
  suppress_chroot_services "$ROOTFS"

  # Copy builder assets
  echo "--> Copying builder assets..."
  cp -r builder/scripts   "$ROOTFS/tmp/scripts"
  cp -r builder/calamares "$ROOTFS/tmp/calamares-config"
  cp -r builder/docs      "$ROOTFS/tmp/docs"
  cp -r builder/udev      "$ROOTFS/tmp/udev"
  cp -r builder/modprobe  "$ROOTFS/tmp/modprobe"
  cp -r builder/security  "$ROOTFS/tmp/security"
  cp -r builder/menu      "$ROOTFS/tmp/menu"
  cp -r builder/wireshark "$ROOTFS/tmp/wireshark"
  cp -r builder/boot      "$ROOTFS/tmp/boot"
  cp -r builder/wordlists "$ROOTFS/tmp/wordlists"
  if [ -d builder/icons ]; then
    cp -r builder/icons "$ROOTFS/tmp/icons"
  fi
  if [ -d packages/telcosec-cli ]; then
    cp -r packages/telcosec-cli "$ROOTFS/tmp/telcosec-cli"
  fi
  if [ -d packages/5ghoul-5g-nr-attacks/scripts ]; then
    rm -rf "$ROOTFS/tmp/5ghoul-overlay"
    mkdir -p "$ROOTFS/tmp/5ghoul-overlay"
    cp -a packages/5ghoul-5g-nr-attacks/UPSTREAM packages/5ghoul-5g-nr-attacks/scripts "$ROOTFS/tmp/5ghoul-overlay/"
  fi
  # Guarantee Unix LF line endings across all copied builder assets inside chroot
  find "$ROOTFS/tmp" -type f -exec sed -i -e 's/\r$//' {} + 2>/dev/null || true

  # Mount virtual filesystems
  echo "--> Mounting virtual filesystems..."
  mkdir -p "$ROOTFS/proc" "$ROOTFS/sys" "$ROOTFS/dev"
  mount -t proc  /proc "$ROOTFS/proc"
  mount -t sysfs /sys  "$ROOTFS/sys"
  mount --bind   /dev  "$ROOTFS/dev"
  mount --bind   /dev/pts "$ROOTFS/dev/pts"
fi

# ─── Provisioning ─────────────────────────────────────────────────────────────
if ! $PACK_ONLY; then
  echo "--> Running provisioning scripts..."

  # ── APT proxy (apt-cacher-ng) ────────────────────────────────────────────────
  if [ -n "$APT_PROXY" ]; then
    echo "Acquire::http::Proxy \"$APT_PROXY\";" > "$ROOTFS/etc/apt/apt.conf.d/00proxy"
    echo "--> APT proxy: $APT_PROXY"
  fi

  # ── ccache: inject via PATH so all gcc/g++ calls go through ccache wrappers ──
  # /usr/lib/ccache/ contains symlinks: gcc→ccache, g++→ccache, clang→ccache, etc.
  # No cmake flag changes needed — any compiler invocation is transparently cached.
  CHROOT_PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
  if [ "${USE_CCACHE:-0}" = "1" ]; then
    mkdir -p "$CCACHE_DIR_HOST" "$ROOTFS/root/.ccache"
    mount --bind "$CCACHE_DIR_HOST" "$ROOTFS/root/.ccache"
    CHROOT_PATH="/usr/lib/ccache:$CHROOT_PATH"
    echo "--> ccache enabled (cache dir: $CCACHE_DIR_HOST)"
  fi

  _phase() {
    local num="$1"; local label="$2"; shift 2
    if $RESUME && [ "$num" -lt "$RESUME_FROM" ]; then
      printf '\n┌─ %-50s [skipped]\n' "$label"
      return 0
    fi
    local t0; t0=$(date +%s)
    printf '\n┌─ %-50s\n' "$label"
    "$@"
    printf '└─ done in %dm%02ds\n' \
      $(( ($(date +%s)-t0) / 60 )) $(( ($(date +%s)-t0) % 60 ))
  }

  chroot_run() {
    chroot "$ROOTFS" env \
      PATH="$CHROOT_PATH" \
      CCACHE_DIR=/root/.ccache \
      /bin/bash -e "/tmp/scripts/$1"
  }

  if [ "$BUILD_FLAVOR" = "lite" ]; then
    echo "--> Running provisioning scripts (Lite Edition: base desktop + installer + telcosec-pkg)..."
    _phase  0 "00 · Consolidated package install"    chroot_run 00-install-all-packages.sh
    _phase  1 "01 · Base system + desktop"           chroot_run 01-install-base.sh
    _phase  5 "05 · Desktop customization"           chroot_run 05-desktop-customization.sh
    _phase  7 "07 · Calamares installer"             chroot_run 07-install-installer.sh
    _phase  8 "08 · System optimization"             chroot_run 08-system-optimization.sh
  else
    echo "--> Running provisioning scripts (Field Full Edition: all 100 telecom tools)..."
    _phase  0 "00 · Consolidated package install"    chroot_run 00-install-all-packages.sh
    _phase  1 "01 · Base system + desktop"           chroot_run 01-install-base.sh
    _phase  2 "02 · SDR drivers + conda env"         chroot_run 02-install-sdr.sh
    _phase  3 "03 · Core network (srsRAN/Open5GS)"   chroot_run 03-install-core-network.sh
    _phase  4 "04 · Security tools"                  chroot_run 04-install-tools.sh
    _phase  5 "05 · Desktop customization"           chroot_run 05-desktop-customization.sh
    _phase  6 "06 · UE analysis + baseband"          chroot_run 06-install-ue-analysis.sh
    _phase  7 "07 · Calamares installer"             chroot_run 07-install-installer.sh
    _phase  8 "08 · System optimization"             chroot_run 08-system-optimization.sh
    _phase  9 "09 · 5Ghoul helpers"                  chroot_run 09-install-5ghoul.sh
    _phase 10 "10 · Advanced telecom tools"          chroot_run 10-install-telecom-advanced.sh
    _phase 11 "11 · Device flash tools"              chroot_run 11-install-device-tools.sh
  fi

  # ── Tool build manifest summary ─────────────────────────────────────────────
  # Print PASS/FAIL results for every tool instrumented with record_tool().
  # Source the helper into the host shell so record_tool_summary() is available.
  SCRIPT_DIR_HOST="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/builder/scripts"
  # shellcheck source=builder/scripts/lib/record-tool.sh
  source "${SCRIPT_DIR_HOST}/lib/record-tool.sh"
  # Copy the manifest out of the chroot for the summary (the log lives inside rootfs)
  if [ -f "${ROOTFS}/usr/share/telcosec/tool-manifest.txt" ]; then
    cp "${ROOTFS}/usr/share/telcosec/tool-manifest.txt" /tmp/tool-manifest.txt
    # Override manifest path for summary
    _TELCOSEC_MANIFEST=/tmp/tool-manifest.txt
    # Fatal by default when any record_tool() artifact is missing.
    # TELCOSEC_ALLOW_TOOL_FAILURES=1 continues (best-effort / nightlies).
    record_tool_summary || {
      echo "ERROR: tool build summary reported failures — aborting ISO build." >&2
      exit 1
    }
  else
    echo "  (no tool manifest found — record_tool may not have run)"
  fi

  # Remove chroot service suppression
  restore_chroot_services "$ROOTFS"

  # ── Live-boot fixups ───────────────────────────────────────────────────────
  # casper.conf: sourced by casper initramfs hooks — must use 'export' syntax so
  # child processes (lightdm, adduser hooks) inherit the variables.
  cat > "$ROOTFS/etc/casper.conf" << 'CASPER_CONF'
export USERNAME=telcosec
export USERFULLNAME="TelcoSec Researcher"
export HOST=TelcoChisel
export BUILD_SYSTEM=Ubuntu
export FLAVOUR=ubuntu
CASPER_CONF

  # Ensure casper is selected as the initramfs BOOT method.
  # The casper package postinstall normally writes this, but a chroot postinstall
  # failure would silently leave BOOT=local, causing the initramfs to skip all
  # casper premount/bottom scripts and never find filesystem.squashfs.
  mkdir -p "$ROOTFS/etc/initramfs-tools/conf.d"
  echo "BOOT=casper" > "$ROOTFS/etc/initramfs-tools/conf.d/casper-boot"

  # Force essential live-boot kernel modules into the initramfs.
  # overlay is required by casper for the writable tmpfs layer.
  # Use a sentinel to avoid duplicate entries on --resume builds.
  if ! grep -q "^# telcosec-modules" "$ROOTFS/etc/initramfs-tools/modules" 2>/dev/null; then
    cat >> "$ROOTFS/etc/initramfs-tools/modules" << 'MODULES_EOF'
# telcosec-modules
overlay
isofs
squashfs
loop
cdrom
sr_mod
ata_piix
ahci
xhci_pci
ehci_pci
uhci_hcd
usb_storage
uas
vfat
fat
nls_cp437
nls_iso8859_1
nls_utf8
MODULES_EOF
  fi

  # Reinstall casper to ensure initramfs hooks are fully present after all the
  # provisioning apt transactions (some transactions may have left hooks stale).
  # This is load-bearing for boot — a stale/incomplete set of casper hooks
  # produces a live image that fails at boot with "Unable to find a medium".
  # NOTE: the previous `| tail -3 || true` checked tail's exit code (always 0),
  # not apt-get's, so a failure here was never actually detected or surfaced —
  # capture and check the real exit status instead.
  echo "--> Reinstalling casper to refresh initramfs hooks..."
  CASPER_REINSTALL_LOG=$(mktemp)
  if ! chroot "$ROOTFS" env DEBIAN_FRONTEND=noninteractive \
      apt-get install -y --reinstall casper > "$CASPER_REINSTALL_LOG" 2>&1; then
    echo "ERROR: casper reinstall failed — initramfs hooks may be incomplete, producing a non-booting live image."
    tail -20 "$CASPER_REINSTALL_LOG"
    rm -f "$CASPER_REINSTALL_LOG"
    exit 1
  fi
  tail -3 "$CASPER_REINSTALL_LOG"
  rm -f "$CASPER_REINSTALL_LOG"

  # Add blkid to the initramfs explicitly. casper's get_fstype() calls blkid to
  # identify block device filesystems; if blkid is absent the scan silently
  # skips all devices, producing "Unable to find a medium". blkid is in
  # util-linux which may not be pulled into the initramfs by default hooks.
  cat > "$ROOTFS/etc/initramfs-tools/hooks/blkid-for-casper" << 'BLKID_HOOK'
#!/bin/sh
PREREQ=""
prereqs() { echo "$PREREQ"; }
case $1 in prereqs) prereqs; exit 0;; esac
. /usr/share/initramfs-tools/hook-functions
copy_exec /sbin/blkid /sbin
copy_exec /usr/sbin/blkid /sbin 2>/dev/null || true
# util-linux blkid depends on libblkid
for lib in /lib/x86_64-linux-gnu/libblkid.so.* /usr/lib/x86_64-linux-gnu/libblkid.so.*; do
    [ -f "$lib" ] && copy_exec "$lib" || true
done
BLKID_HOOK
  chmod +x "$ROOTFS/etc/initramfs-tools/hooks/blkid-for-casper"

  # Ensure overlay.ko is physically present in the initramfs. casper checks
  # /proc/filesystems for 'overlay' before mounting the CoW layer; if the
  # module isn't loaded at that point it prints "/cow format specified as
  # 'overlay' and no support found" and drops to a shell. manual_add_modules
  # copies the module + all its firmware/deps into the cpio archive.
  cat > "$ROOTFS/etc/initramfs-tools/hooks/overlay-for-casper" << 'OVERLAY_HOOK'
#!/bin/sh
PREREQ=""
prereqs() { echo "$PREREQ"; }
case $1 in prereqs) prereqs; exit 0;; esac
. /usr/share/initramfs-tools/hook-functions
manual_add_modules overlay
OVERLAY_HOOK
  chmod +x "$ROOTFS/etc/initramfs-tools/hooks/overlay-for-casper"

  # casper-premount script: load overlay before casper's main body checks
  # /proc/filesystems. Scripts in casper-premount/ run just before casper
  # attempts to mount the CoW filesystem. Numbered 00- so it runs first.
  mkdir -p "$ROOTFS/etc/initramfs-tools/scripts/casper-premount"
  cat > "$ROOTFS/etc/initramfs-tools/scripts/casper-premount/00-load-overlay" << 'OVERLAY_PREMOUNT'
#!/bin/sh
PREREQ=""
prereqs() { echo "$PREREQ"; }
case $1 in prereqs) prereqs; exit 0;; esac
modprobe overlay 2>/dev/null || true
OVERLAY_PREMOUNT
  chmod +x "$ROOTFS/etc/initramfs-tools/scripts/casper-premount/00-load-overlay"

  echo "--> Regenerating initrd (BOOT=casper, all hooks)..."
  chroot "$ROOTFS" update-initramfs -u -k all 2>&1
  echo "--> initrd regeneration complete."

  # Cleanup inside chroot to reduce squashfs size
  echo ""
  echo "--> Cleaning up chroot..."
  chroot "$ROOTFS" /bin/bash -e << 'CLEANUP'
export DEBIAN_FRONTEND=noninteractive
apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/*
# ── Deep Cache Cleanup (npm, cargo, go, global cache) ──────────────────────
rm -rf /root/.cache /home/telcosec/.cache 2>/dev/null || true
rm -rf /root/.npm /home/telcosec/.npm 2>/dev/null || true
rm -rf /root/.cargo/registry /home/telcosec/.cargo/registry 2>/dev/null || true

# ── Conda cleanup ──────────────────────────────────────────────────────────
if [ -x /opt/telcosec/miniconda/bin/conda ]; then
  /opt/telcosec/miniconda/bin/conda clean -afy || true
fi
# Remove conda package cache and tarballs (pkgs/ is the biggest hidden cost)
rm -rf /opt/telcosec/miniconda/pkgs/ 2>/dev/null || true

# ── Conda env runtime-trim (ISO-size reduction, target <5 GB) ───────────────
# The telcosec-sdr env (GNU Radio, gqrx, SoapySDR, numpy, boost) ships dev
# artifacts with no runtime value: static libs, C/C++ headers, test suites,
# CMake/pkg-config metadata, bundled docs/examples, and man pages. Removing
# them does not affect running the SDR tools. Scope strictly to the conda
# tree so nothing system-wide is touched.
_CONDA_ENVS=/opt/telcosec/miniconda/envs
if [ -d "$_CONDA_ENVS" ]; then
  find "$_CONDA_ENVS" -type f -name '*.a' -delete 2>/dev/null || true
  # C/C++ headers: only needed to *build* against the env (GNU Radio OOT modules,
  # SWIG/pybind). That is an advanced dev task; a user who needs it can
  # `conda install` the -dev packages back. Removing include/ reclaims ~200 MB
  # and is what brings the full ISO under the 5 GB SourceForge budget.
  find "$_CONDA_ENVS" -type d -name include -prune -exec rm -rf {} + 2>/dev/null || true
  # Byte-compiled Python caches inside the env (regenerated on demand).
  find "$_CONDA_ENVS" -type d -name '__pycache__' -prune -exec rm -rf {} + 2>/dev/null || true
  find "$_CONDA_ENVS" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete 2>/dev/null || true
  # Python test suites inside the env's site-packages (numpy/scipy/etc.).
  find "$_CONDA_ENVS" -type d \( -name tests -o -name test \) \
    -path '*/site-packages/*' -prune -exec rm -rf {} + 2>/dev/null || true
  # Bundled docs / examples / man pages inside the env share tree.
  rm -rf "$_CONDA_ENVS"/*/share/man "$_CONDA_ENVS"/*/share/doc \
         "$_CONDA_ENVS"/*/share/gtk-doc "$_CONDA_ENVS"/*/share/info 2>/dev/null || true
  # Strip the env's ELF binaries and shared libs (biggest single win after .a).
  find "$_CONDA_ENVS" -type f \( -name '*.so' -o -name '*.so.*' \) \
    -exec strip --strip-unneeded {} + 2>/dev/null || true
  find "$_CONDA_ENVS"/*/bin -type f -executable \
    -exec strip --strip-unneeded {} + 2>/dev/null || true
fi

# ── Git history (no runtime value) ────────────────────────────────────────
find /opt/telcosec     -name '.git'       -type d -exec rm -rf {} + 2>/dev/null || true

# ── CMake / Meson build directories ────────────────────────────────────────
# build/ dirs under /opt/telcosec can be 500-700 MB of object files + CMakeFiles
find /opt/telcosec -type d -name 'build'      -exec rm -rf {} + 2>/dev/null || true
find /opt/telcosec -type d -name '_build'     -exec rm -rf {} + 2>/dev/null || true
find /opt/telcosec -type d -name 'CMakeFiles' -exec rm -rf {} + 2>/dev/null || true
find /opt/telcosec -type f -name 'CMakeCache.txt' -delete 2>/dev/null || true
find /opt/telcosec -type f -name '*.o'        -delete 2>/dev/null || true
find /opt/telcosec -type f -name '*.a'        -delete 2>/dev/null || true

# ── Strip Binaries (removes debug symbols) ─────────────────────────────────
# Many tools compiled from source leave heavy debug symbols in their binaries
find /opt/telcosec /usr/local/bin /usr/local/lib -type f -executable -exec strip --strip-unneeded {} + 2>/dev/null || true
find /usr/lib/x86_64-linux-gnu /usr/bin -name 'srs*' -type f -executable -exec strip --strip-unneeded {} + 2>/dev/null || true

# ── Python caches and build artifacts ─────────────────────────────────────
# Include /usr/lib/python3.* to clear system-wide pip/apt generated bytecodes
find /opt/telcosec /usr/local/lib /root /home /usr/lib/python3* -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
find /opt/telcosec /usr/local/lib /root /home /usr/lib/python3* -type d -name '*.egg-info'  -exec rm -rf {} + 2>/dev/null || true
find /opt/telcosec /usr/local/lib /root /home /usr/lib/python3* -type d -name '*.dist-info' -prune -o -type f \( -name '*.pyc' -o -name '*.pyo' \) -print -delete 2>/dev/null || true

# ── Java/Maven local repository (~250 MB) ─────────────────────────────────
rm -rf /root/.m2 /home/telcosec/.m2 2>/dev/null || true

# ── Redundant LLVM & Compiler Cache Trimming ──────────────────────────────
if dpkg -s llvm-16 >/dev/null 2>&1 && dpkg -s llvm-15 >/dev/null 2>&1; then
  apt-get purge -y llvm-15 llvm-15-runtime clang-15 2>/dev/null || true
fi
rm -rf /root/go/pkg /root/.cache/go-build /root/.cargo/registry 2>/dev/null || true
rm -rf /root/.cache/pip /home/*/.cache/pip 2>/dev/null || true

# ── Cross-compiler sysroots and debug libraries ────────────────────────────
# arm-none-eabi and mipsel headers/specs not needed at runtime (~200 MB)
find /usr/lib/gcc-cross -name '*.o' -delete 2>/dev/null || true
rm -rf /usr/arm-none-eabi/lib/*.a /usr/mipsel-linux-gnu/lib/*.a 2>/dev/null || true

# ── Locale trimming (~80 MB) ──────────────────────────────────────────────
find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en' ! -name 'en_US' ! -name 'locale.alias' -exec rm -rf {} + 2>/dev/null || true
find /usr/share/i18n/locales -mindepth 1 ! -name 'en_US' ! -name 'en_GB' -delete 2>/dev/null || true

# ── Man pages and docs (except telcosec) ─────────────────────────────────
find /usr/share/doc -mindepth 1 -maxdepth 1 ! -name 'telcosec' -exec rm -rf {} +
rm -rf /usr/share/man/*
rm -rf /usr/share/groff /usr/share/info 2>/dev/null || true

# ── Logs and temp ─────────────────────────────────────────────────────────
find /var/log -type f \( -name '*.log' -o -name '*.gz' \) -delete 2>/dev/null || true
rm -rf /var/log/journal/* 2>/dev/null || true
rm -rf /tmp/scripts /tmp/calamares-config /tmp/docs
rm -rf /tmp/udev /tmp/modprobe /tmp/security /tmp/menu /tmp/wireshark /tmp/boot
rm -rf /tmp/wordlists
rm -f  /tmp/.packages-installed
rm -rf /tmp/*
CLEANUP
fi

# ─── OS Identity & Versioning ─────────────────────────────────────────────────
echo "--> Stamping TelcoChisel OS version ($ISO_VERSION) into target system..."
BUILD_DATE_UTC=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
git config --global --add safe.directory "$PWD" 2>/dev/null || true
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
CLEAN_VERSION="${ISO_VERSION#v}"

# /etc/telcochisel-version
cat > "$ROOTFS/etc/telcochisel-version" << EOF
VERSION=${ISO_VERSION}
VERSION_ID=${CLEAN_VERSION}
FLAVOR=${BUILD_FLAVOR}
FLAVOR_LABEL=${DISTRO_FLAVOR_LABEL}
BUILD_DATE_UTC=${BUILD_DATE_UTC}
GIT_COMMIT=${GIT_COMMIT}
ARCHITECTURE=amd64
DISTRO=TelcoChisel
BASE_DISTRO=Ubuntu 24.04 LTS (noble)
EOF
chmod 644 "$ROOTFS/etc/telcochisel-version"

# /etc/os-release & /usr/lib/os-release
cat > "$ROOTFS/etc/os-release" << EOF
NAME="TelcoChisel OS"
VERSION="${ISO_VERSION} (${DISTRO_FLAVOR_LABEL}, Noble Numbat)"
ID=telcochisel
ID_LIKE="ubuntu debian"
PRETTY_NAME="TelcoChisel OS ${ISO_VERSION} (${DISTRO_FLAVOR_LABEL})"
VERSION_ID="${CLEAN_VERSION}"
VARIANT="${DISTRO_FLAVOR_LABEL}"
VARIANT_ID="${BUILD_FLAVOR}"
HOME_URL="https://telcochisel.com"
SUPPORT_URL="https://community.telcosec.net/"
BUG_REPORT_URL="https://github.com/TelcoChisel/TelcoChiselOS/issues"
PRIVACY_POLICY_URL="https://telcosec.net/privacy"
UBUNTU_CODENAME=noble
EOF
cp -f "$ROOTFS/etc/os-release" "$ROOTFS/usr/lib/os-release" 2>/dev/null || true

# /etc/issue and /etc/issue.net
cat > "$ROOTFS/etc/issue" << EOF
TelcoChisel OS ${ISO_VERSION} (${DISTRO_FLAVOR_LABEL}) \n \l

EOF
cat > "$ROOTFS/etc/issue.net" << EOF
TelcoChisel OS ${ISO_VERSION} (${DISTRO_FLAVOR_LABEL})
EOF

# Update Calamares branding with current ISO_VERSION and flavor
for desc in "$ROOTFS/etc/calamares/branding/telcosec/branding.desc" \
            "$ROOTFS/usr/share/calamares/branding/telcosec/branding.desc"; do
  if [ -f "$desc" ]; then
    sed -i -e "s/^    version:.*/    version:             ${ISO_VERSION}/" \
           -e "s/^    shortVersion:.*/    shortVersion:        ${CLEAN_VERSION}/" \
           -e "s/^    versionedName:.*/    versionedName:       TelcoChisel OS ${ISO_VERSION} (${DISTRO_FLAVOR_LABEL})/" \
           -e "s/^    shortVersionedName:.*/    shortVersionedName:  TelcoSec ${CLEAN_VERSION} ${DISTRO_FLAVOR_LABEL}/" \
           "$desc"
  fi
done

# ─── Unmount before packing ───────────────────────────────────────────────────
cleanup
trap - EXIT

# From here on (squashfs pack, grub-mkrescue, Secure Boot retrofit, ISO
# integrity check), install a lighter trap covering ONLY the packing phase's
# own temp resources. Previously the trap was disabled entirely at this
# point, so a failure anywhere in this phase leaked /tmp/xorriso-wrap and,
# worse, a stale loop mount from the integrity check below (loop devices
# don't clean themselves up and can block a later `losetup -f`/retry).
# $ROOTFS is already unmounted above, so the original cleanup() no longer
# applies here — this is a separate, narrower function.
_PACKING_LOOP_MOUNT=""
cleanup_packing() {
  if [ -n "$_PACKING_LOOP_MOUNT" ]; then
    umount -lf "$_PACKING_LOOP_MOUNT" 2>/dev/null || true
    rmdir "$_PACKING_LOOP_MOUNT" 2>/dev/null || true
  fi
  rm -rf /tmp/xorriso-wrap "${SB_TMP:-}" 2>/dev/null || true
}
trap cleanup_packing EXIT

# ─── Squashfs ─────────────────────────────────────────────────────────────────
mkdir -p "$WORKDIR/image/casper"
# Derive CPU and memory limits from the host at pack time.
# Allow environment override via SQUASHFS_PROCS; guarantee at least 2 cores remain free for host responsiveness.
_HOST_NPROC=$(nproc 2>/dev/null || echo 4)
if [ -n "${SQUASHFS_PROCS:-}" ]; then
  _SQUASHFS_PROCS="$SQUASHFS_PROCS"
elif [ "$_HOST_NPROC" -gt 4 ]; then
  _SQUASHFS_PROCS=$(( _HOST_NPROC - 2 ))
elif [ "$_HOST_NPROC" -gt 1 ]; then
  _SQUASHFS_PROCS=$(( _HOST_NPROC - 1 ))
else
  _SQUASHFS_PROCS=1
fi
# Cap at 12 by default to prevent CPU thrashing and memory exhaustion
[ "$_SQUASHFS_PROCS" -gt 12 ] && _SQUASHFS_PROCS=12

# Derive per-processor memory budget (mksquashfs -mem is per-processor).
# Use ~60% of available RAM divided across processors; floor at 512M, cap at 4G.
_AVAIL_KB=$(awk '/MemAvailable/{print $2}' /proc/meminfo 2>/dev/null || echo 4194304)
_MEM_MB=$(( (_AVAIL_KB / 1024) * 60 / 100 / _SQUASHFS_PROCS ))
[ "$_MEM_MB" -lt 512 ]  && _MEM_MB=512
[ "$_MEM_MB" -gt 4096 ] && _MEM_MB=4096

echo "--> Packing filesystem into squashfs (zstd-${SQUASHFS_LEVEL}, procs=${_SQUASHFS_PROCS}, mem-per-proc=${_MEM_MB}M)..."
nice -n 10 mksquashfs "$ROOTFS" "$WORKDIR/image/casper/filesystem.squashfs" \
  -comp zstd -Xcompression-level "${SQUASHFS_LEVEL}" \
  -b 1M \
  -processors "${_SQUASHFS_PROCS}" -mem "${_MEM_MB}M" \
  -no-exports \
  -noappend

# filesystem.size — casper/live-boot uses this for install size estimation
printf '%s' "$(du -sx --block-size=1 "$ROOTFS" | cut -f1)" \
  > "$WORKDIR/image/casper/filesystem.size"

# filesystem.manifest — package list used by casper to validate the medium
# and by the installer to compute what to remove from the installed system.
chroot "$ROOTFS" dpkg-query -W --showformat='${Package}\t${Version}\n' \
  > "$WORKDIR/image/casper/filesystem.manifest" 2>/dev/null || true

# ─── Create .disk/info required by Ubuntu casper ─────────────
mkdir -p "$WORKDIR/image/.disk"
echo "TelcoChisel OS ${ISO_VERSION} Live CD" > "$WORKDIR/image/.disk/info"
touch "$WORKDIR/image/.disk/base_installable"

# ─── Kernel + initrd ──────────────────────────────────────────────────────────
# Prioritize linux-image-lowlatency as primary kernel for real-time SDR/5G operations.
# Also preserve generic kernel as /casper/vmlinuz-generic for fallback.
echo "--> Copying kernel and initrd..."
vmlinuz_lowlatency=$(find "$ROOTFS/boot/" -name "vmlinuz-*lowlatency*" -type f 2>/dev/null | sort -V | tail -1 || true)
vmlinuz_generic=$(find "$ROOTFS/boot/" -name "vmlinuz-*generic*" -type f 2>/dev/null | sort -V | tail -1 || true)

if [ -n "$vmlinuz_lowlatency" ]; then
  vmlinuz="$vmlinuz_lowlatency"
  echo "    Selected Low-Latency kernel: $(basename "$vmlinuz") (SDR/5G optimized)"
elif [ -n "$vmlinuz_generic" ]; then
  vmlinuz="$vmlinuz_generic"
  echo "    Selected Generic kernel: $(basename "$vmlinuz")"
else
  vmlinuz=$(find "$ROOTFS/boot/" -name "vmlinuz-*" -type f | sort -V | tail -1)
fi

if [ -z "$vmlinuz" ]; then
  echo "ERROR: kernel (vmlinuz-*) not found in $ROOTFS/boot/"
  exit 1
fi
kver="${vmlinuz##*/vmlinuz-}"
initrd="$ROOTFS/boot/initrd.img-${kver}"
if [ ! -f "$initrd" ]; then
  echo "ERROR: initrd.img-${kver} not found in $ROOTFS/boot/ (mismatched with vmlinuz-${kver})"
  exit 1
fi
cp "$vmlinuz" "$WORKDIR/image/casper/vmlinuz"
cp "$initrd"  "$WORKDIR/image/casper/initrd"

# If a distinct generic kernel exists, copy it as secondary fallback
if [ -n "$vmlinuz_generic" ] && [ "$vmlinuz_generic" != "$vmlinuz" ]; then
  kver_gen="${vmlinuz_generic##*/vmlinuz-}"
  initrd_gen="$ROOTFS/boot/initrd.img-${kver_gen}"
  if [ -f "$initrd_gen" ]; then
    echo "    Packing Generic fallback kernel: $(basename "$vmlinuz_generic")"
    cp "$vmlinuz_generic" "$WORKDIR/image/casper/vmlinuz-generic"
    cp "$initrd_gen"      "$WORKDIR/image/casper/initrd-generic"
  fi
fi

# ─── GRUB config ──────────────────────────────────────────────────────────────
echo "--> Generating GRUB boot menu..."
mkdir -p "$WORKDIR/image/boot/grub"
# Copy branding logo for GRUB background
if [ -f "builder/boot/grub_background.png" ]; then
  cp "builder/boot/grub_background.png" "$WORKDIR/image/boot/grub/logo.png"
elif [ -f "$ROOTFS/usr/share/backgrounds/telcosec/logo.png" ]; then
  cp "$ROOTFS/usr/share/backgrounds/telcosec/logo.png" "$WORKDIR/image/boot/grub/logo.png"
fi
cat > "$WORKDIR/image/boot/grub/grub.cfg" << GRUB
set default=0
set timeout=3

insmod all_video
insmod font
if loadfont /boot/grub/fonts/unicode.pf2 ; then
  set gfxmode=auto
  insmod gfxterm
  insmod png
  terminal_output gfxterm
  if background_image /boot/grub/logo.png ; then
    set color_normal=light-gray/black
    set color_highlight=yellow/black
  fi
fi

# Ubuntu 24.04 casper: boot=casper activates the live-boot scripts.
# username/hostname are set here so casper's 10adduser hook picks them up.
# noeject/noprompt: suppress casper's "remove disc and press enter" prompts.

menuentry "TelcoChisel OS Live (Low-Latency Realtime — Default)" --class telcochisel --class os {
    set gfxpayload=keep
    linux /casper/vmlinuz boot=casper noeject noprompt username=telcosec hostname=TelcoChisel quiet splash fastboot loglevel=3 usbcore.usbfs_memory_mb=1000 ---
    initrd /casper/initrd
}

menuentry "TelcoChisel OS Live (Encrypted Persistence)" --class telcochisel --class os {
    set gfxpayload=keep
    linux /casper/vmlinuz boot=casper persistent noeject noprompt username=telcosec hostname=TelcoChisel quiet splash fastboot loglevel=3 usbcore.usbfs_memory_mb=1000 ---
    initrd /casper/initrd
}

menuentry "TelcoChisel OS Live (RAM Mode — Zero Trace)" --class telcochisel --class os {
    set gfxpayload=keep
    linux /casper/vmlinuz boot=casper noeject noprompt username=telcosec hostname=TelcoChisel quiet splash fastboot loglevel=3 usbcore.usbfs_memory_mb=1000 toram ---
    initrd /casper/initrd
}

menuentry "TelcoChisel OS Live RFS Style" --class telcochisel --class os {
    set gfxpayload=keep
    linux /casper/vmlinuz boot=casper desktop=i3 noeject noprompt username=telcosec hostname=TelcoChisel quiet splash fastboot loglevel=3 usbcore.usbfs_memory_mb=1000 ---
    initrd /casper/initrd
}

menuentry "Install TelcoChisel OS to Hard Disk (Calamares Installer)" --class calamares --class os {
    set gfxpayload=keep
    linux /casper/vmlinuz boot=casper noeject noprompt username=telcosec hostname=TelcoChisel calamares quiet splash fastboot loglevel=3 usbcore.usbfs_memory_mb=1000 ---
    initrd /casper/initrd
}

submenu "Advanced Hardware & Diagnostic Options..." --class submenu {
    menuentry "TelcoChisel OS Live (Safe Graphics — nomodeset)" --class recovery {
        set gfxpayload=keep
        linux /casper/vmlinuz boot=casper noeject noprompt username=telcosec hostname=TelcoChisel nomodeset usbcore.usbfs_memory_mb=1000 ---
        initrd /casper/initrd
    }

    if [ -f /casper/vmlinuz-generic ]; then
    menuentry "TelcoChisel OS Live (Generic Kernel Compatibility)" --class recovery {
        set gfxpayload=keep
        linux /casper/vmlinuz-generic boot=casper noeject noprompt username=telcosec hostname=TelcoChisel quiet splash fastboot loglevel=3 usbcore.usbfs_memory_mb=1000 ---
        initrd /casper/initrd-generic
    }
    fi

    menuentry "TelcoChisel OS Live (Verbose Debug Boot)" --class recovery {
        set gfxpayload=keep
        linux /casper/vmlinuz boot=casper noeject noprompt username=telcosec hostname=TelcoChisel debug systemd.log_level=debug usbcore.usbfs_memory_mb=1000 ---
        initrd /casper/initrd
    }

    if [ "\$grub_platform" = "efi" ]; then
    menuentry "UEFI Firmware Settings" --class uefi {
        fwsetup
    }
    fi

    menuentry "Reboot System" --class reboot {
        reboot
    }

    menuentry "Power Off System" --class shutdown {
        halt
    }
}
GRUB

# ─── Build ISO ────────────────────────────────────────────────────────────────
echo "--> Building ISO with grub-mkrescue..."
# grub-mkrescue pipes args to xorriso via its own "--" (interpreter/stdin mode).
# In that context "-iso-level 3" is not a recognized interpreter command, only a
# command-line flag. Intercept xorriso via PATH and inject the flag right after
# "-as mkisofs" before xorriso sees any content args.
mkdir -p /tmp/xorriso-wrap
cat > /tmp/xorriso-wrap/xorriso << 'XWRAP'
#!/bin/bash
args=("$@")
for i in "${!args[@]}"; do
  if [ "${args[$i]}" = "mkisofs" ] && [ "${args[$((i-1))]:-}" = "-as" ]; then
    args=("${args[@]:0:$((i+1))}" "-iso-level" "3" "${args[@]:$((i+1))}")
    break
  fi
done
exec /usr/bin/xorriso "${args[@]}"
XWRAP
chmod +x /tmp/xorriso-wrap/xorriso
PATH="/tmp/xorriso-wrap:$PATH" grub-mkrescue -o "$IMAGE_NAME" "$WORKDIR/image/"
# Verify the injected flag actually reached xorriso and squashfs is intact
SQUASHFS_IN_ISO_SZ=$(xorriso -indev "$IMAGE_NAME" -lsl /casper 2>/dev/null | grep 'filesystem.squashfs' | awk '{print $5}' || true)
if [ -n "$SQUASHFS_IN_ISO_SZ" ] && [ "$SQUASHFS_IN_ISO_SZ" -gt 0 ]; then
  echo "    ISO Level 3 & filesystem.squashfs confirmed ($SQUASHFS_IN_ISO_SZ bytes) ✓"
else
  echo "    WARNING: could not confirm filesystem.squashfs inside $IMAGE_NAME" >&2
fi

# ─── Secure Boot retrofit (best-effort) ───────────────────────────────────────
# grub-mkrescue's own EFI image is unsigned, so Secure-Boot-enabled UEFI
# firmware refuses to boot it. If shim-signed + grub-efi-amd64-signed are
# installed on this host, patch the ISO's embedded EFI system partition
# in place: replace BOOTX64.EFI with the signed shim (the Secure Boot chain
# root) and add a signed grubx64.efi for shim to chainload. Everything here
# is best-effort and non-fatal — if any step fails (path differs across grub
# versions, mtools error, etc.) the original unsigned-but-working ISO from
# grub-mkrescue above is left untouched, so BIOS and non-Secure-Boot UEFI
# boot are never put at risk by this step.
echo "--> Attempting Secure Boot retrofit (signed shim + grub)..."
SHIM_SRC=$(dpkg -L shim-signed 2>/dev/null | grep -E 'shimx64\.efi\.signed(\.latest)?$' | head -1 || true)
GRUB_SIGNED_SRC=$(dpkg -L grub-efi-amd64-signed 2>/dev/null | grep -E 'grubx64\.efi\.signed$' | head -1 || true)

if [ -z "$SHIM_SRC" ] || [ -z "$GRUB_SIGNED_SRC" ]; then
  echo "  SKIPPED: shim-signed / grub-efi-amd64-signed not installed on this host —"
  echo "  ISO will boot via legacy BIOS and non-Secure-Boot UEFI only."
else
  SB_TMP=$(mktemp -d)
  EFI_IMG_ISO_PATH="boot/grub/efi.img"
  if xorriso -indev "$IMAGE_NAME" -osirrox on -extract "/$EFI_IMG_ISO_PATH" "$SB_TMP/efi.img" 2>/dev/null \
      && [ -s "$SB_TMP/efi.img" ]; then
    if mcopy -i "$SB_TMP/efi.img" -o "$SHIM_SRC"        ::EFI/BOOT/BOOTX64.EFI 2>/dev/null \
        && mcopy -i "$SB_TMP/efi.img" -o "$GRUB_SIGNED_SRC" ::EFI/BOOT/grubx64.efi 2>/dev/null; then
      if xorriso -indev "$IMAGE_NAME" -outdev "$IMAGE_NAME" -boot_image any replay \
           -update "$SB_TMP/efi.img" "/$EFI_IMG_ISO_PATH" -commit 2>/dev/null; then
        echo "  Secure Boot retrofit OK — signed shim + grub embedded in $EFI_IMG_ISO_PATH"
      else
        echo "  WARNING: failed to write patched efi.img back into the ISO — Secure Boot NOT enabled (ISO still boots via BIOS/non-SB UEFI, unaffected)"
      fi
    else
      echo "  WARNING: mtools could not inject signed shim/grub into efi.img — Secure Boot NOT enabled (ISO unaffected)"
    fi
  else
    echo "  WARNING: could not locate/extract $EFI_IMG_ISO_PATH inside the ISO (grub version may use a different path) — Secure Boot NOT enabled (ISO unaffected)"
  fi
  rm -rf "$SB_TMP"
fi

# ─── ISO integrity check ──────────────────────────────────────────────────────
# Verify that filesystem.squashfs is accessible inside the ISO (not just present
# in the source tree). If the ISO was built without Level 3 support, the
# squashfs directory entry would be truncated and casper would fail at boot.
#
# A failed check here now FAILS THE BUILD (exit 1). Previously this printed
# "ERROR:" but let the script continue to print "Build complete" — a broken,
# unbootable ISO was indistinguishable from a good one in the build log.
echo "--> Verifying ISO integrity (squashfs accessible inside ISO)..."
ISO_CHECK_DIR=$(mktemp -d)
if mount -o loop,ro "$IMAGE_NAME" "$ISO_CHECK_DIR" 2>/dev/null; then
  _PACKING_LOOP_MOUNT="$ISO_CHECK_DIR"
  SQUASHFS_SIZE=$(stat -c '%s' "$ISO_CHECK_DIR/casper/filesystem.squashfs" 2>/dev/null || echo 0)
  if [ "$SQUASHFS_SIZE" -gt 0 ]; then
    printf '    filesystem.squashfs visible inside ISO: %s bytes ✓\n' "$SQUASHFS_SIZE"
  else
    echo "    ERROR: filesystem.squashfs NOT accessible inside ISO — Level 3 may have failed!"
    umount "$ISO_CHECK_DIR" 2>/dev/null || true
    _PACKING_LOOP_MOUNT=""
    rmdir "$ISO_CHECK_DIR" 2>/dev/null || true
    echo "ERROR: ISO integrity check failed — squashfs is not readable inside the built ISO. Aborting build."
    exit 1
  fi
  # Verify casper init scripts are in the initrd — an invalid/missing initrd
  # is just as unbootable as a missing squashfs, so this is fatal too.
  INITRD_FILE="$ISO_CHECK_DIR/casper/initrd"
  if file "$INITRD_FILE" 2>/dev/null | grep -q "gzip\|cpio\|Zstandard"; then
    echo "    initrd present and appears valid ✓"
  else
    echo "    ERROR: initrd missing or not a valid archive inside the ISO!"
    umount "$ISO_CHECK_DIR" 2>/dev/null || true
    _PACKING_LOOP_MOUNT=""
    rmdir "$ISO_CHECK_DIR" 2>/dev/null || true
    echo "ERROR: ISO integrity check failed — initrd is invalid. Aborting build."
    exit 1
  fi
  umount "$ISO_CHECK_DIR" 2>/dev/null || true
  _PACKING_LOOP_MOUNT=""
else
  # Loop-mount itself may be unavailable in some restricted build
  # environments (not every host/container permits it) — treat that
  # specific case as non-fatal rather than assuming the ISO is broken.
  echo "    WARNING: Could not loop-mount ISO to verify (non-fatal — loop mount unavailable in this environment)"
fi
rmdir "$ISO_CHECK_DIR" 2>/dev/null || true

# ─── Checksum Generation & Compatibility Symlinks ─────────────────────────────
# Fatal on failure — release tooling consumes the .sha256 file; shipping an
# image without a verifiable checksum is worse than failing the build.
echo "--> Generating SHA256 and MD5 checksums..."
sha256sum "$IMAGE_NAME" > "${IMAGE_NAME}.sha256" || { echo "FATAL: sha256sum failed for $IMAGE_NAME" >&2; exit 1; }
md5sum "$IMAGE_NAME" > "${IMAGE_NAME}.md5" || { echo "FATAL: md5sum failed for $IMAGE_NAME" >&2; exit 1; }
SHA256_VAL=$(cut -d' ' -f1 < "${IMAGE_NAME}.sha256")
ISO_SIZE=$(du -sh "$IMAGE_NAME" | cut -f1)

# Maintain backward compatibility with scripts expecting TelcoChisel-live.iso
if [ "$IMAGE_NAME" != "TelcoChisel-live.iso" ]; then
  echo "--> Creating backward-compatible link TelcoChisel-live.iso -> $IMAGE_NAME..."
  rm -f "TelcoChisel-live.iso"
  ln -f "$IMAGE_NAME" "TelcoChisel-live.iso" 2>/dev/null || \
  ln -sf "$IMAGE_NAME" "TelcoChisel-live.iso" 2>/dev/null || \
  cp -f "$IMAGE_NAME" "TelcoChisel-live.iso" 2>/dev/null || true
  cp -f "${IMAGE_NAME}.sha256" "TelcoChisel-live.iso.sha256"
  cp -f "${IMAGE_NAME}.md5" "TelcoChisel-live.iso.md5"
fi

# ─── Build Metadata Manifest ──────────────────────────────────────────────────
BUILD_INFO_FILE="${IMAGE_NAME}.build-info.json"
cat > "$BUILD_INFO_FILE" << EOF
{
  "distro": "TelcoChisel OS",
  "version": "${ISO_VERSION}",
  "version_id": "${CLEAN_VERSION}",
  "flavor": "${BUILD_FLAVOR}",
  "flavor_label": "${DISTRO_FLAVOR_LABEL}",
  "arch": "amd64",
  "base": "Ubuntu 24.04 LTS (noble)",
  "build_date_utc": "${BUILD_DATE_UTC}",
  "git_commit": "${GIT_COMMIT}",
  "kernel": "${kver}",
  "iso_filename": "${IMAGE_NAME}",
  "sha256": "${SHA256_VAL}",
  "iso_size": "${ISO_SIZE}"
}
EOF
if [ "$IMAGE_NAME" != "TelcoChisel-live.iso" ]; then
  cp -f "$BUILD_INFO_FILE" "TelcoChisel-live.iso.build-info.json"
fi

# If executed via sudo, restore ownership to the invoking user
if [ -n "${SUDO_UID:-}" ] && [ -n "${SUDO_GID:-}" ]; then
  chown -h "${SUDO_UID}:${SUDO_GID}" \
    "$IMAGE_NAME" "${IMAGE_NAME}.sha256" "${IMAGE_NAME}.md5" "$BUILD_INFO_FILE" \
    "TelcoChisel-live.iso" "TelcoChisel-live.iso.sha256" "TelcoChisel-live.iso.md5" "TelcoChisel-live.iso.build-info.json" 2>/dev/null || true
fi

# ─── Summary ──────────────────────────────────────────────────────────────────
ELAPSED=$(( $(date +%s) - BUILD_START ))
printf '\n╔══════════════════════════════════════════════════════╗\n'
printf '║  %-52s║\n' "Build complete: $IMAGE_NAME"
printf '║  %-52s║\n' "Version:        $ISO_VERSION"
printf '║  %-52s║\n' "ISO size:       $ISO_SIZE"
printf '║  %-52s║\n' "SHA256:         ${SHA256_VAL:0:16}..."
printf '║  %-52s║\n' "Build info:     $BUILD_INFO_FILE"
printf '║  %-52s║\n' "Total time:     $(( ELAPSED/60 ))m$(( ELAPSED%60 ))s"
printf '╚══════════════════════════════════════════════════════╝\n'
