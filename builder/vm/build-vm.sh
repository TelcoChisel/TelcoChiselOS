#!/usr/bin/env bash
# =============================================================================
# TelcoChisel OS — Virtual Machine Appliance Builder
#
# Builds turnkey virtual appliances for:
#   1. Proxmox VE / KVM (.qcow2 with Cloud-Init & QEMU Guest Agent)
#   2. VMware Workstation / Fusion / ESXi (.ova with streamOptimized VMDK)
#   3. Oracle VirtualBox (.ova with streamOptimized VMDK & xHCI USB 3.0)
#
# Usage:
#   sudo ./builder/vm/build-vm.sh [OPTIONS]
#
# Examples:
#   sudo ./builder/vm/build-vm.sh --iso TelcoChisel-2026.2-amd64.iso --target all
#   sudo ./builder/vm/build-vm.sh --target proxmox
#   sudo ./builder/vm/build-vm.sh --rootfs /var/tmp/live-iso-work/chroot --target vmware
#   sudo ./builder/vm/build-vm.sh --target virtualbox --output-dir ./dist/vm
# =============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ─── Defaults ─────────────────────────────────────────────────────────────────
SOURCE_ISO=""
SOURCE_ROOTFS=""
SOURCE_SQUASHFS=""
TARGET_PLATFORMS="all"
DISK_SIZE_GB=40
OUTPUT_DIR="${REPO_ROOT}/dist/vm"
WORK_DIR=""
VERSION=""
KEEP_RAW=false
COMPRESS_OUTPUT=false

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_info()  { echo -e "${CYAN}[*]${NC} $*"; }
log_step()  { echo -e "${GREEN}[+]${NC} ${BOLD}$*${NC}"; }
log_warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
log_error() { echo -e "${RED}[-]${NC} $*" >&2; }

# ─── Help ─────────────────────────────────────────────────────────────────────
show_help() {
  cat << 'EOF'
TelcoChisel OS — VM Appliance Builder

Usage: sudo ./builder/vm/build-vm.sh [OPTIONS]

Options:
  --iso <path>             Path to TelcoChisel Live ISO image
  --rootfs <path>          Path to built chroot directory
  --squashfs <path>        Path to filesystem.squashfs
  --target <platform>      Target hypervisors: all (default), proxmox, vmware, virtualbox
  --disk-size <gb>         Virtual disk capacity in GB (default: 40)
  --output-dir <path>      Directory for generated appliance files (default: dist/vm)
  --version <ver>          Appliance version string (default: read from VERSION file)
  --keep-raw               Retain the intermediate raw disk image
  --compress               Apply zstd compression to final archives (.qcow2.zst, .ova.zst)
  -h, --help               Show this help message

Supported Targets:
  proxmox                  Compressed QCOW2 with QEMU Guest Agent & Proxmox import script
  vmware                   OVF 1.0 OVA with streamOptimized VMDK, PVSCSI, VMXNET3, USB 3.1
  virtualbox               OVF 2.0 OVA with streamOptimized VMDK, AHCI, E1000, USB 3.0
  all                      Build all three appliances from a single raw master disk

Examples:
  sudo ./builder/vm/build-vm.sh --iso TelcoChisel-2026.2-amd64.iso
  sudo ./builder/vm/build-vm.sh --target proxmox --output-dir /mnt/storage/vm
  sudo ./builder/vm/build-vm.sh --rootfs live-iso-work/chroot --target vmware
EOF
  exit 0
}

# ─── Parse Arguments ──────────────────────────────────────────────────────────
while [ $# -gt 0 ]; do
  case "$1" in
    --iso)
      SOURCE_ISO="$2"
      shift 2
      ;;
    --iso=*)
      SOURCE_ISO="${1#*=}"
      shift
      ;;
    --rootfs)
      SOURCE_ROOTFS="$2"
      shift 2
      ;;
    --rootfs=*)
      SOURCE_ROOTFS="${1#*=}"
      shift
      ;;
    --squashfs)
      SOURCE_SQUASHFS="$2"
      shift 2
      ;;
    --squashfs=*)
      SOURCE_SQUASHFS="${1#*=}"
      shift
      ;;
    --target)
      TARGET_PLATFORMS="$2"
      shift 2
      ;;
    --target=*)
      TARGET_PLATFORMS="${1#*=}"
      shift
      ;;
    --disk-size)
      DISK_SIZE_GB="$2"
      shift 2
      ;;
    --disk-size=*)
      DISK_SIZE_GB="${1#*=}"
      shift
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --output-dir=*)
      OUTPUT_DIR="${1#*=}"
      shift
      ;;
    --version)
      VERSION="$2"
      shift 2
      ;;
    --version=*)
      VERSION="${1#*=}"
      shift
      ;;
    --keep-raw)
      KEEP_RAW=true
      shift
      ;;
    --compress)
      COMPRESS_OUTPUT=true
      shift
      ;;
    -h|--help)
      show_help
      ;;
    *)
      log_error "Unknown argument: $1"
      show_help
      ;;
  esac
done

# ─── Root Check ───────────────────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  log_error "This script requires root privileges to partition disks and mount loopback devices."
  echo "Please run: sudo $0 $*"
  exit 1
fi

# ─── Version Resolution ───────────────────────────────────────────────────────
if [ -z "$VERSION" ]; then
  if [ -f "${REPO_ROOT}/VERSION" ]; then
    VERSION=$(head -n 1 "${REPO_ROOT}/VERSION" | tr -d '[:space:]')
  else
    VERSION="2026.2"
  fi
fi
VERSION="${VERSION#v}"

# ─── Target Normalization ─────────────────────────────────────────────────────
TARGET_PLATFORMS="$(echo "$TARGET_PLATFORMS" | tr '[:upper:]' '[:lower:]')"
BUILD_PROXMOX=false
BUILD_VMWARE=false
BUILD_VIRTUALBOX=false

case "$TARGET_PLATFORMS" in
  all)
    BUILD_PROXMOX=true
    BUILD_VMWARE=true
    BUILD_VIRTUALBOX=true
    ;;
  proxmox|pve|kvm)
    BUILD_PROXMOX=true
    ;;
  vmware|esxi|workstation)
    BUILD_VMWARE=true
    ;;
  virtualbox|vbox)
    BUILD_VIRTUALBOX=true
    ;;
  *)
    log_error "Invalid target '$TARGET_PLATFORMS'. Supported: all, proxmox, vmware, virtualbox"
    exit 1
    ;;
esac

# ─── Prerequisite Validation ──────────────────────────────────────────────────
log_step "Checking host prerequisites..."
REQUIRED_TOOLS=(qemu-img sfdisk losetup mkfs.vfat mkfs.ext4 blkid rsync tar sha256sum)
MISSING_TOOLS=()

for tool in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    MISSING_TOOLS+=("$tool")
  fi
done

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
  log_error "Missing required utilities: ${MISSING_TOOLS[*]}"
  echo "Install on Debian/Ubuntu with: apt-get install -y qemu-utils fdisk util-linux dosfstools e2fsprogs rsync tar coreutils"
  exit 1
fi

# Check squashfs-tools if input is ISO or squashfs
if [ -n "$SOURCE_ISO" ] || [ -n "$SOURCE_SQUASHFS" ] || [ -z "$SOURCE_ROOTFS" ]; then
  if ! command -v unsquashfs >/dev/null 2>&1; then
    log_error "unsquashfs is required to unpack squashfs/ISO. Install with: apt-get install -y squashfs-tools"
    exit 1
  fi
fi

# ─── Source Discovery ─────────────────────────────────────────────────────────
if [ -z "$SOURCE_ROOTFS" ] && [ -z "$SOURCE_SQUASHFS" ] && [ -z "$SOURCE_ISO" ]; then
  log_info "No source explicitly specified; searching workspace..."
  if [ -d "/var/tmp/live-iso-work/chroot" ]; then
    SOURCE_ROOTFS="/var/tmp/live-iso-work/chroot"
    log_info "Found existing chroot at $SOURCE_ROOTFS"
  elif [ -d "${REPO_ROOT}/live-iso-work/chroot" ]; then
    SOURCE_ROOTFS="${REPO_ROOT}/live-iso-work/chroot"
    log_info "Found existing chroot at $SOURCE_ROOTFS"
  else
    # Search for built ISO in repo root
    POTENTIAL_ISOS=(
      "${REPO_ROOT}/TelcoChisel-${VERSION}-amd64.iso"
      "${REPO_ROOT}/TelcoChisel-live.iso"
      "${REPO_ROOT}"/TelcoChisel-*.iso
    )
    for iso in "${POTENTIAL_ISOS[@]}"; do
      if [ -f "$iso" ]; then
        SOURCE_ISO="$iso"
        log_info "Found existing ISO at $SOURCE_ISO"
        break
      fi
    done
  fi
fi

if [ -z "$SOURCE_ROOTFS" ] && [ -z "$SOURCE_SQUASHFS" ] && [ -z "$SOURCE_ISO" ]; then
  log_error "No valid source found! Please specify --iso <path>, --squashfs <path>, or --rootfs <path>."
  exit 1
fi

# ─── Work Directory Setup ─────────────────────────────────────────────────────
# Work directory should reside on a POSIX filesystem with sufficient free space (~60GB)
FS_TYPE=$(df -T . 2>/dev/null | awk 'NR==2 {print $2}')
if [[ "$FS_TYPE" =~ ^(9p|drvfs|vboxsf|fuse|cifs|nfs|vfat|ntfs|msdos)$ ]]; then
  WORK_DIR="/var/tmp/telcochisel-vm-work-$$"
else
  WORK_DIR="${REPO_ROOT}/.vm-work-$$"
fi

mkdir -p "$WORK_DIR"
mkdir -p "$OUTPUT_DIR"

log_info "Workspace: $WORK_DIR"
log_info "Output:    $OUTPUT_DIR"
log_info "Version:   $VERSION"
log_info "Disk Size: ${DISK_SIZE_GB} GiB"

# ─── Cleanup Trap ─────────────────────────────────────────────────────────────
LOOP_DEV=""
MNT_TARGET="${WORK_DIR}/mnt_target"
MNT_ISO="${WORK_DIR}/mnt_iso"

cleanup() {
  log_info "Running cleanup routines..."
  
  # Unmount chroot bind mounts
  if [ -d "$MNT_TARGET" ]; then
    umount -lf "${MNT_TARGET}/boot/efi" 2>/dev/null || true
    umount -lf "${MNT_TARGET}/dev/pts" 2>/dev/null || true
    umount -lf "${MNT_TARGET}/dev" 2>/dev/null || true
    umount -lf "${MNT_TARGET}/proc" 2>/dev/null || true
    umount -lf "${MNT_TARGET}/sys" 2>/dev/null || true
    umount -lf "$MNT_TARGET" 2>/dev/null || true
  fi

  # Unmount ISO if mounted
  if [ -d "$MNT_ISO" ]; then
    umount -lf "$MNT_ISO" 2>/dev/null || true
  fi

  # Detach loop device
  if [ -n "$LOOP_DEV" ] && losetup "$LOOP_DEV" >/dev/null 2>&1; then
    losetup -d "$LOOP_DEV" 2>/dev/null || true
  fi

  # Remove work dir if not keeping raw
  if [ "$KEEP_RAW" = false ] && [ -d "$WORK_DIR" ]; then
    rm -rf "$WORK_DIR" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

# ─── Step 1: Create Master Sparse Raw Virtual Disk ───────────────────────────
log_step "Creating ${DISK_SIZE_GB} GiB sparse raw master disk..."
RAW_DISK="${WORK_DIR}/telcochisel-master.raw"
truncate -s "${DISK_SIZE_GB}G" "$RAW_DISK"

log_info "Partitioning master disk with GPT (512MB EFI + Linux Root)..."
# Partition layout:
# Partition 1: EFI System Partition (type U in sfdisk = C12A7328-F81F-11D2-BA4B-00A0C93EC93B)
# Partition 2: Linux Root Filesystem (type L in sfdisk = 0FC63DAF-8483-4772-8E79-3D69D8477DE4)
sfdisk "$RAW_DISK" << 'EOF' >/dev/null 2>&1
label: gpt
size=512M, type=U, name="EFI System Partition"
size=+,    type=L, name="TelcoChisel Root"
EOF

log_info "Attaching raw disk to loopback device..."
LOOP_DEV=$(losetup -Pf --show "$RAW_DISK")
log_info "Attached to ${LOOP_DEV}"

PART_EFI="${LOOP_DEV}p1"
PART_ROOT="${LOOP_DEV}p2"

# Wait for kernel partition table notification
partprobe "$LOOP_DEV" 2>/dev/null || udevadm settle 2>/dev/null || sleep 2

if [ ! -b "$PART_EFI" ] || [ ! -b "$PART_ROOT" ]; then
  log_error "Partition nodes ${PART_EFI} or ${PART_ROOT} not found!"
  exit 1
fi

log_info "Formatting EFI partition (FAT32)..."
mkfs.vfat -F 32 -n "ESP" "$PART_EFI" >/dev/null

log_info "Formatting Root partition (ext4 with 4KB blocks & journal)..."
mkfs.ext4 -F -q -L "TelcoChisel" -b 4096 -E lazy_itable_init=0,lazy_journal_init=0 "$PART_ROOT"

# ─── Step 2: Mount Target Disk ────────────────────────────────────────────────
log_step "Mounting virtual disk partitions..."
mkdir -p "$MNT_TARGET"
mount "$PART_ROOT" "$MNT_TARGET"

mkdir -p "$MNT_TARGET/boot/efi"
mount "$PART_EFI" "$MNT_TARGET/boot/efi"

# ─── Step 3: Populate Rootfs ──────────────────────────────────────────────────
if [ -n "$SOURCE_ROOTFS" ]; then
  log_step "Synchronizing rootfs from ${SOURCE_ROOTFS}..."
  rsync -aHAXx \
    --exclude='/proc/*' \
    --exclude='/sys/*' \
    --exclude='/dev/*' \
    --exclude='/tmp/*' \
    --exclude='/run/*' \
    --exclude='/mnt/*' \
    --exclude='/media/*' \
    "${SOURCE_ROOTFS}/" "$MNT_TARGET/"

elif [ -n "$SOURCE_SQUASHFS" ]; then
  log_step "Extracting squashfs directly from ${SOURCE_SQUASHFS}..."
  unsquashfs -f -d "$MNT_TARGET" "$SOURCE_SQUASHFS"

elif [ -n "$SOURCE_ISO" ]; then
  log_step "Extracting rootfs from ISO: ${SOURCE_ISO}..."
  mkdir -p "$MNT_ISO"
  mount -o loop,ro "$SOURCE_ISO" "$MNT_ISO"
  
  SQUASH_PATH=""
  if [ -f "$MNT_ISO/casper/filesystem.squashfs" ]; then
    SQUASH_PATH="$MNT_ISO/casper/filesystem.squashfs"
  elif [ -f "$MNT_ISO/live/filesystem.squashfs" ]; then
    SQUASH_PATH="$MNT_ISO/live/filesystem.squashfs"
  else
    # Find any squashfs on ISO
    SQUASH_PATH=$(find "$MNT_ISO" -name "*.squashfs" | head -n 1)
  fi

  if [ -z "$SQUASH_PATH" ] || [ ! -f "$SQUASH_PATH" ]; then
    log_error "Could not locate filesystem.squashfs inside ${SOURCE_ISO}!"
    exit 1
  fi

  log_info "Unpacking squashfs image (${SQUASH_PATH})..."
  unsquashfs -f -d "$MNT_TARGET" "$SQUASH_PATH"
  umount "$MNT_ISO"
  rmdir "$MNT_ISO"
fi

# Ensure mandatory virtual directories exist
mkdir -p "$MNT_TARGET"/{dev,proc,sys,run,tmp,mnt,media,boot/efi}
chmod 1777 "$MNT_TARGET/tmp"

# ─── Step 4: Configure Filesystem & Bootloader ────────────────────────────────
log_step "Configuring filesystem table (/etc/fstab)..."
UUID_ROOT=$(blkid -s UUID -o value "$PART_ROOT")
UUID_EFI=$(blkid -s UUID -o value "$PART_EFI")

cat << EOF > "$MNT_TARGET/etc/fstab"
# /etc/fstab: static file system information for TelcoChisel OS VM
# <file system>                           <mount point>  <type>  <options>                  <dump>  <pass>
UUID=${UUID_ROOT}  /              ext4    errors=remount-ro,noatime  0       1
UUID=${UUID_EFI}   /boot/efi      vfat    umask=0077                 0       2
tmpfs                                     /tmp           tmpfs   mode=1777,nosuid,nodev     0       0
EOF

log_info "Configuring network interfaces (Cloud/DHCP)..."
mkdir -p "$MNT_TARGET/etc/netplan"
cat << 'EOF' > "$MNT_TARGET/etc/netplan/01-telcochisel-vm.yaml"
# TelcoChisel VM Network Configuration
network:
  version: 2
  renderer: NetworkManager
  ethernets:
    all-en:
      match:
        name: "en*|eth*"
      dhcp4: true
      dhcp6: true
      optional: true
EOF
chmod 600 "$MNT_TARGET/etc/netplan/01-telcochisel-vm.yaml"

log_info "Configuring Cloud-Init datasource and user defaults..."
mkdir -p "$MNT_TARGET/etc/cloud/cloud.cfg.d"
cat << 'EOF' > "$MNT_TARGET/etc/cloud/cloud.cfg.d/99-pve-nocloud.cfg"
# Allow Proxmox VE NoCloud and ConfigDrive metadata
datasource_list: [ NoCloud, ConfigDrive, None ]
manage_etc_hosts: true
EOF

cat << 'EOF' > "$MNT_TARGET/etc/cloud/cloud.cfg.d/99-telcosec-user.cfg"
# TelcoSec TelcoChisel VM default provisioning
# Password-required sudo (not NOPASSWD:ALL) — lab VMs still use the documented
# telcosec password; this blocks silent privilege escalation from malware/scripts.
system_info:
  default_user:
    name: telcosec
    gecos: TelcoSec Operator
    groups: [sudo, dialout, plugdev, netdev, wireshark]
    sudo: ["ALL=(ALL) ALL"]
    shell: /bin/bash
EOF

log_info "Configuring TelcoSec login issue and hostname..."
cat << 'EOF' > "$MNT_TARGET/etc/issue"
TelcoSec TelcoChisel OS \r (\l) - Telecom Security Operations
TelcoSec Academy: https://app.telcosec.net | ProLabs: https://app.telcosec.net/prolabs

EOF
cp -f "$MNT_TARGET/etc/issue" "$MNT_TARGET/etc/issue.net"

if [ ! -s "$MNT_TARGET/etc/hostname" ]; then
  echo "telcochisel" > "$MNT_TARGET/etc/hostname"
fi

log_step "Installing UEFI Bootloader (GRUB EFI)..."
mount --bind /dev "$MNT_TARGET/dev"
mount --bind /dev/pts "$MNT_TARGET/dev/pts"
mount --bind /proc "$MNT_TARGET/proc"
mount --bind /sys "$MNT_TARGET/sys"

# Configure GRUB defaults for VMs
cat << 'EOF' > "$MNT_TARGET/etc/default/grub.d/50-telcochisel-vm.cfg"
GRUB_DEFAULT=0
GRUB_TIMEOUT=3
GRUB_TIMEOUT_STYLE=menu
GRUB_DISTRIBUTOR="TelcoSec TelcoChisel OS"
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash console=tty1 net.ifnames=0 biosdevname=0"
GRUB_TERMINAL="console"
EOF

# Install GRUB inside chroot
log_info "Running grub-install in chroot target..."
chroot "$MNT_TARGET" /bin/bash -c "
  export DEBIAN_FRONTEND=noninteractive
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=TelcoChisel --recheck --no-nvram
  update-grub
"

# Create standard fallback bootloader (BOOTX64.EFI) so hypervisors without NVRAM state boot directly
mkdir -p "$MNT_TARGET/boot/efi/EFI/BOOT"
if [ -f "$MNT_TARGET/boot/efi/EFI/TelcoChisel/grubx64.efi" ]; then
  cp -f "$MNT_TARGET/boot/efi/EFI/TelcoChisel/grubx64.efi" "$MNT_TARGET/boot/efi/EFI/BOOT/BOOTX64.EFI"
elif [ -f "$MNT_TARGET/boot/efi/EFI/TelcoChisel/shimx64.efi" ]; then
  cp -f "$MNT_TARGET/boot/efi/EFI/TelcoChisel/shimx64.efi" "$MNT_TARGET/boot/efi/EFI/BOOT/BOOTX64.EFI"
  [ -f "$MNT_TARGET/boot/efi/EFI/TelcoChisel/grubx64.efi" ] && cp -f "$MNT_TARGET/boot/efi/EFI/TelcoChisel/grubx64.efi" "$MNT_TARGET/boot/efi/EFI/BOOT/grubx64.efi"
fi

# Enable guest services (they self-deactivate on mismatched hypervisors)
log_info "Enabling hypervisor guest agent services..."
chroot "$MNT_TARGET" /bin/bash -c "
  systemctl enable qemu-guest-agent 2>/dev/null || true
  systemctl enable open-vm-tools 2>/dev/null || true
  systemctl enable virtualbox-guest-utils 2>/dev/null || true
"

# Sync and unmount target
log_info "Flushing buffers and unmounting target disk..."
sync
umount -lf "${MNT_TARGET}/dev/pts" 2>/dev/null || true
umount -lf "${MNT_TARGET}/dev" 2>/dev/null || true
umount -lf "${MNT_TARGET}/proc" 2>/dev/null || true
umount -lf "${MNT_TARGET}/sys" 2>/dev/null || true
umount -lf "${MNT_TARGET}/boot/efi" 2>/dev/null || true
umount -lf "$MNT_TARGET" 2>/dev/null || true

# Detach loop device
losetup -d "$LOOP_DEV"
LOOP_DEV=""

# ─── Step 5: Convert and Package Appliances ───────────────────────────────────
CAPACITY_MB=$(( DISK_SIZE_GB * 1024 ))

# ── Target: Proxmox VE (QCOW2) ──
if [ "$BUILD_PROXMOX" = true ]; then
  log_step "Building Proxmox VE Appliance (.qcow2)..."
  PVE_QCOW2="${OUTPUT_DIR}/TelcoChisel-${VERSION}-Proxmox.qcow2"
  
  qemu-img convert -c -f raw -O qcow2 "$RAW_DISK" "$PVE_QCOW2"
  log_info "Generated Proxmox image: $(basename "$PVE_QCOW2") ($(du -h "$PVE_QCOW2" | cut -f1))"

  # Create Proxmox CLI import script helper
  PVE_SCRIPT="${OUTPUT_DIR}/TelcoChisel-${VERSION}-Proxmox-import.sh"
  cat << EOF > "$PVE_SCRIPT"
#!/usr/bin/env bash
# =============================================================================
# TelcoSec TelcoChisel OS ${VERSION} — Proxmox VE Import Helper Script
# Powered by TelcoSec | TelcoSec Academy: https://app.telcosec.net
#
# Run this script on your Proxmox VE cluster node to deploy the appliance.
# =============================================================================

set -e

VMID="\${1:-1000}"
STORAGE="\${2:-local-lvm}"
BRIDGE="\${3:-vmbr0}"

IMAGE_NAME="TelcoChisel-${VERSION}-Proxmox.qcow2"

if [ ! -f "\$IMAGE_NAME" ]; then
  echo "[-] ERROR: \$IMAGE_NAME not found in current directory!"
  exit 1
fi

echo "[*] Creating TelcoChisel VM \$VMID on storage \$STORAGE..."
qm create \$VMID \\
  --name "TelcoChisel-${VERSION}" \\
  --memory 8192 \\
  --cores 4 \\
  --cpu host \\
  --machine q35 \\
  --bios ovmf \\
  --efidisk0 \${STORAGE}:0,format=raw,efitype=4m,pre-enrolled-keys=0 \\
  --scsihw virtio-scsi-pci \\
  --net0 virtio,bridge=\${BRIDGE} \\
  --vga virtio \\
  --agent enabled=1

echo "[*] Importing QCOW2 virtual disk into \$STORAGE..."
qm importdisk \$VMID "\$IMAGE_NAME" "\$STORAGE" --format qcow2

echo "[*] Attaching imported disk as primary SCSI boot drive with SSD emulation & discard..."
qm set \$VMID --scsi0 \${STORAGE}:vm-\${VMID}-disk-1,discard=on,ssd=1
qm set \$VMID --boot order=scsi0

echo "[*] Adding Cloud-Init drive for automated expansion and user provisioning..."
qm set \$VMID --ide2 \${STORAGE}:cloudinit
qm set \$VMID --citype nocloud

echo ""
echo "[+] TelcoChisel OS VM \$VMID created successfully!"
echo "    Start VM:  qm start \$VMID"
echo "    Console:   qm terminal \$VMID"
EOF
  chmod +x "$PVE_SCRIPT"
  log_info "Created Proxmox import helper: $(basename "$PVE_SCRIPT")"

  if [ "$COMPRESS_OUTPUT" = true ] && command -v zstd >/dev/null 2>&1; then
    log_info "Compressing Proxmox image with zstd..."
    zstd --rm -15 -T0 "$PVE_QCOW2"
  fi
fi

# ── Target: VMware Workstation / ESXi (.ova) ──
if [ "$BUILD_VMWARE" = true ]; then
  log_step "Building VMware Workstation/ESXi Appliance (.ova)..."
  VMW_VMDK_NAME="TelcoChisel-${VERSION}-VMware-disk1.vmdk"
  VMW_VMDK="${OUTPUT_DIR}/${VMW_VMDK_NAME}"
  VMW_OVF="${OUTPUT_DIR}/TelcoChisel-${VERSION}-VMware.ovf"
  VMW_MF="${OUTPUT_DIR}/TelcoChisel-${VERSION}-VMware.mf"
  VMW_OVA="${OUTPUT_DIR}/TelcoChisel-${VERSION}-VMware.ova"

  log_info "Converting raw master disk to streamOptimized VMDK..."
  qemu-img convert -f raw -O vmdk -o subformat=streamOptimized "$RAW_DISK" "$VMW_VMDK"

  DISK_BYTES=$(stat -c%s "$VMW_VMDK")

  log_info "Generating VMware OVF 1.0 envelope..."
  sed \
    -e "s|@DISK_FILENAME@|${VMW_VMDK_NAME}|g" \
    -e "s|@DISK_SIZE@|${DISK_BYTES}|g" \
    -e "s|@CAPACITY_MB@|${CAPACITY_MB}|g" \
    -e "s|@VERSION@|${VERSION}|g" \
    "${SCRIPT_DIR}/templates/vmware.ovf.in" > "$VMW_OVF"

  log_info "Generating SHA-256 manifest (.mf)..."
  (
    cd "$OUTPUT_DIR"
    sha256sum "$(basename "$VMW_OVF")" "$VMW_VMDK_NAME" > "$(basename "$VMW_MF")"
  )

  log_info "Packaging VMware OVA archive..."
  (
    cd "$OUTPUT_DIR"
    # DMTF OVF Standard ordering: .ovf first, .mf second, disk files third
    tar -cf "$(basename "$VMW_OVA")" \
      "$(basename "$VMW_OVF")" \
      "$(basename "$VMW_MF")" \
      "$VMW_VMDK_NAME"
    rm -f "$(basename "$VMW_OVF")" "$(basename "$VMW_MF")" "$VMW_VMDK_NAME"
  )
  log_info "Generated VMware OVA: $(basename "$VMW_OVA") ($(du -h "$VMW_OVA" | cut -f1))"

  if [ "$COMPRESS_OUTPUT" = true ] && command -v zstd >/dev/null 2>&1; then
    log_info "Compressing VMware OVA with zstd..."
    zstd --rm -15 -T0 "$VMW_OVA"
  fi
fi

# ── Target: Oracle VirtualBox (.ova) ──
if [ "$BUILD_VIRTUALBOX" = true ]; then
  log_step "Building Oracle VirtualBox Appliance (.ova)..."
  VBOX_VMDK_NAME="TelcoChisel-${VERSION}-VirtualBox-disk1.vmdk"
  VBOX_VMDK="${OUTPUT_DIR}/${VBOX_VMDK_NAME}"
  VBOX_OVF="${OUTPUT_DIR}/TelcoChisel-${VERSION}-VirtualBox.ovf"
  VBOX_MF="${OUTPUT_DIR}/TelcoChisel-${VERSION}-VirtualBox.mf"
  VBOX_OVA="${OUTPUT_DIR}/TelcoChisel-${VERSION}-VirtualBox.ova"

  log_info "Converting raw master disk to streamOptimized VMDK..."
  qemu-img convert -f raw -O vmdk -o subformat=streamOptimized "$RAW_DISK" "$VBOX_VMDK"

  DISK_BYTES=$(stat -c%s "$VBOX_VMDK")

  log_info "Generating VirtualBox OVF 2.0 envelope..."
  sed \
    -e "s|@DISK_FILENAME@|${VBOX_VMDK_NAME}|g" \
    -e "s|@DISK_SIZE@|${DISK_BYTES}|g" \
    -e "s|@CAPACITY_MB@|${CAPACITY_MB}|g" \
    -e "s|@VERSION@|${VERSION}|g" \
    "${SCRIPT_DIR}/templates/virtualbox.ovf.in" > "$VBOX_OVF"

  log_info "Generating SHA-256 manifest (.mf)..."
  (
    cd "$OUTPUT_DIR"
    sha256sum "$(basename "$VBOX_OVF")" "$VBOX_VMDK_NAME" > "$(basename "$VBOX_MF")"
  )

  log_info "Packaging VirtualBox OVA archive..."
  (
    cd "$OUTPUT_DIR"
    tar -cf "$(basename "$VBOX_OVA")" \
      "$(basename "$VBOX_OVF")" \
      "$(basename "$VBOX_MF")" \
      "$VBOX_VMDK_NAME"
    rm -f "$(basename "$VBOX_OVF")" "$(basename "$VBOX_MF")" "$VBOX_VMDK_NAME"
  )
  log_info "Generated VirtualBox OVA: $(basename "$VBOX_OVA") ($(du -h "$VBOX_OVA" | cut -f1))"

  if [ "$COMPRESS_OUTPUT" = true ] && command -v zstd >/dev/null 2>&1; then
    log_info "Compressing VirtualBox OVA with zstd..."
    zstd --rm -15 -T0 "$VBOX_OVA"
  fi
fi

# ─── Step 6: Generate Checksums & Metadata ────────────────────────────────────
log_step "Generating SHA256 checksums..."
(
  cd "$OUTPUT_DIR"
  rm -f SHA256SUMS
  sha256sum TelcoChisel-* > SHA256SUMS 2>/dev/null || true
)

if [ "$KEEP_RAW" = true ]; then
  mv "$RAW_DISK" "${OUTPUT_DIR}/TelcoChisel-${VERSION}-master.raw"
  log_info "Preserved master raw disk at ${OUTPUT_DIR}/TelcoChisel-${VERSION}-master.raw"
fi

echo ""
echo -e "${GREEN}=====================================================================${NC}"
echo -e "${GREEN}${BOLD}TelcoChisel OS VM Appliances Built Successfully!${NC}"
echo -e "${GREEN}=====================================================================${NC}"
ls -lh "$OUTPUT_DIR"
echo ""
EOF
