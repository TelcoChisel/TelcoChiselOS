#!/bin/bash
# =============================================================================
# lib/packages.sh — TelcoChisel shared package arrays
#
# SINGLE SOURCE OF TRUTH for per-script APT package sets.
# Used in two contexts:
#   1. 00-install-all-packages.sh  — sources this file and installs the union
#      in one consolidated apt-get transaction (fast path, normal build).
#   2. Each provisioning script    — sources this file and installs only its
#      own group when running standalone (no /tmp/.packages-installed sentinel).
#
# To add/change a package:
#   • Edit the relevant PKGS_* array below.
#   • That's it — both 00 and the standalone fallback pick it up automatically.
#
# DO NOT call apt-get here; this file is sourced, not executed.
# =============================================================================

# ─── 01-install-base.sh ──────────────────────────────────────────────────────
PKGS_BASE=(
  # Live boot infrastructure (must precede kernel)
  casper initramfs-tools
  # Kernel (Low-latency default for SDR & 5G real-time operations + Generic fallback)
  linux-image-lowlatency linux-headers-lowlatency
  linux-image-generic linux-headers-generic
  # Bootloader & Filesystem / Partitioning Tools (Required for Calamares installation & EFI setup)
  grub-pc-bin grub-efi-amd64-bin shim-signed grub-efi-amd64-signed
  rsync squashfs-tools dosfstools e2fsprogs parted gparted
  # Desktop (XFCE + i3 Tiling WM + LightDM)
  xfce4 xfce4-goodies xfce4-genmon-plugin lightdm thunar
  i3 i3status i3lock rofi feh picom conky-all
  xserver-xorg xserver-xorg-input-all
  # GPU Drivers, OpenCL & Hardware Acceleration (Intel, AMD, NVIDIA, Vulkan, VA-API)
  xserver-xorg-video-all xserver-xorg-video-nouveau
  mesa-vulkan-drivers mesa-va-drivers mesa-vdpau-drivers mesa-utils
  intel-media-va-driver i965-va-driver
  vulkan-tools
  ocl-icd-libopencl1 opencl-headers ocl-icd-opencl-dev pocl-opencl-icd
  ubuntu-drivers-common
  network-manager-gnome
  terminator firefox
  # Hypervisor guest integrations (VMware, Proxmox/KVM, VirtualBox, Cloud-Init)
  open-vm-tools open-vm-tools-desktop
  qemu-guest-agent spice-vdagent
  virtualbox-guest-utils virtualbox-guest-x11
  cloud-init cloud-initramfs-growroot
  # Themes
  yaru-theme-gtk yaru-theme-icon papirus-icon-theme
  # Boot splash (telcosec Plymouth theme — see builder/boot/plymouth/)
  plymouth plymouth-themes
  # Core system & terminal productivity tools
  git vim nano htop fzf tmux zsh zsh-autosuggestions zsh-syntax-highlighting
  bat ripgrep jq tree xclip
  # Desktop/terminal monospace fonts — the 05-desktop-customization.sh XFCE,
  # terminator, conky, i3 and rofi configs reference these by family name, so
  # they must actually be installed or the UI silently falls back. Ubuntu Mono
  # for desktop/terminal; Fira Code for the glyph-heavy HUD surfaces.
  fonts-ubuntu fonts-firacode
  build-essential cmake pkg-config golang-go
  ufw openssh-server
  openvpn network-manager-openvpn network-manager-openvpn-gnome
  wireguard wireguard-tools resolvconf
  docker.io docker-compose-v2
  sudo tuned
)

# ─── 02-install-sdr.sh ───────────────────────────────────────────────────────
# Note: GNU Radio ecosystem (gnuradio, gqrx, gr-osmosdr) is installed inside
# the dedicated telcosec-sdr Conda environment (see 02-install-sdr.sh) to resolve
# the Noble librtlsdr ABI clash and avoid shipping duplicate multi-GB stacks.
PKGS_SDR=(
  wget libusb-1.0-0-dev
  libfftw3-double3 libfftw3-dev libfftw3-bin
  autoconf automake libtool
  libsqlite3-dev libwxgtk3.2-dev freeglut3-dev
  libbladerf2 libbladerf-dev bladerf
  inspectrum gpredict
)

# ─── 03-install-core-network.sh ──────────────────────────────────────────────
# Build & protocol headers for core network stacks.
# Note: libbladerf is covered in PKGS_SDR, libfftw3-dev is in PKGS_SDR,
# and libboost-all-dev is declared in PKGS_ADVANCED.
PKGS_CORE_NETWORK=(
  cmake ninja-build
  clang-15 lld-15 lldb-15
  liblapacke-dev libblas-dev liblapack-dev
  libsctp-dev lksctp-tools
  libzmq3-dev libczmq-dev
  libjson-c-dev
  libglib2.0-dev
  libconfig-dev
  libyaml-cpp-dev
  libssl-dev
  libmbedtls-dev
  libnuma-dev
  python3-yaml
)

# ─── 04-install-tools.sh ─────────────────────────────────────────────────────
PKGS_TOOLS=(
  wireshark tshark
  nmap
  macchanger vlan freeradius-utils hashcat john pppoe nikto gobuster
  lksctp-tools libsctp-dev libgsl-dev libnet1-dev libglib2.0-dev
  libitpp-dev cargo rustc libhackrf-dev
  ruby ruby-snmp
  sipsak
  netsniff-ng mitmproxy
  python3-pip python3-venv
  wireguard
  twinkle baresip linphone-desktop
)

# ─── 06-install-ue-analysis.sh ───────────────────────────────────────────────
PKGS_UE_ANALYSIS=(
  pcscd pcsc-tools opensc libpcsclite-dev libccid
  python3-pyscard python3-dev
  libosmocore-dev libmd-dev librocksdb-dev
  git wget unzip cmake pkg-config build-essential gnupg autoconf automake libtool
  qemu-system-arm qemu-system-mips qemu-system-x86 qemu-utils
  libglib2.0-dev bison flex libpcap-dev libgcrypt20-dev libpugixml-dev libgtest-dev
  qtbase5-dev qttools5-dev qtmultimedia5-dev libqt5svg5-dev libc-ares-dev
  libsdl2-mixer-2.0-0 libsdl2-image-2.0-0 libsdl2-2.0-0
  libcurl4-openssl-dev
  libelf-dev libffi-dev libdwarf-dev libwiretap-dev wireshark-dev python3-pycparser
  protobuf-compiler protobuf-c-compiler libprotoc-dev libprotobuf-dev libprotobuf-c-dev libjsoncpp-dev
  gdb-multiarch libcapstone-dev gcc-mipsel-linux-gnu gcc-arm-none-eabi
  scons g++ make dfu-util autoconf-archive
  libtalloc-dev libgnutls28-dev liburing-dev
)

# ─── 09-install-5ghoul.sh — build toolchain ──────────────────────────────────
PKGS_5GHOUL_BUILD=(
  git git-lfs
  cmake ninja-build meson
  ccache
  python3-pip python3-dev python3-numpy python3-pandas python3-scapy
  nodejs npm
  wireshark-dev
  libqt5websockets5-dev
)

# ─── 09-install-5ghoul.sh — fuzzer runtime ───────────────────────────────────
PKGS_5GHOUL_RUNTIME=(
  libglib2.0-dev
  libsnappy-dev
  liblua5.2-dev
  libc-ares-dev
  libnl-3-dev libnl-route-3-dev libnl-genl-3-dev
  libnghttp2-dev
  libnss3-dev
  libtbb-dev
  libdouble-conversion-dev
  libdwarf-dev libelf-dev libiberty-dev
  libunwind-dev
  libgflags-dev
  libevent-dev
  libfmt-dev
  libpcap-dev
  libasan6 libubsan1
)

# ─── 5Ghoul requirements.sh pre-deps ─────────────────────────────────────────
PKGS_5GHOUL_REQS=(
  bc swig graphviz libgraphviz-dev
  libspandsp-dev
  libsbc-dev libspeexdsp-dev
  libxrandr-dev libxinerama-dev libxcursor-dev libxi-dev
  libmaxminddb-dev
  libfreetype-dev
  libgl-dev
  libpcre2-dev
  libxss1
  sshpass
  libgoogle-glog-dev libzstd-dev
)

# ─── Developer tools & advanced build deps (10/11) ───────────────────────────
PKGS_ADVANCED=(
  openjdk-17-jdk maven
  ccache
  tmux
  # Modem & AT command tools
  minicom gammu modem-manager-gui screen picocom python3-serial
  modemmanager libqmi-utils libmbim-utils
  usb-modeswitch usb-modeswitch-data
  # Network analysis
  tcpdump iw aircrack-ng
  # Device flashing
  heimdall-flash adb fastboot
  # DOCSIS / HFC
  tftpd-hpa tftp-hpa isc-dhcp-server yersinia ettercap-text-only
  # VoIP extras (not covered by PKGS_TOOLS)
  ppp wvdial
  # SNMP / BSS management
  snmp snmp-mibs-downloader snmpd libsnmp-dev
  # Calamares installer & Unpack/Partitioning Tools
  calamares rsync squashfs-tools dosfstools e2fsprogs parted
  qml-module-qtquick-controls qml-module-qtquick-controls2
  qml-module-qtquick-dialogs qml-module-qtquick-layouts
  qml-module-qtquick-window2
  upower os-prober python3-jsonschema
  # Telecom tool build deps (10-install-telecom-advanced.sh)
  linux-headers-generic
  libconfig++-dev
  libliquid-dev
  libtalloc2 libtalloc-dev
  libqwt-qt5-dev librtlsdr-dev libboost-all-dev libitpp-dev
  libncurses-dev cargo libcrypt-dev libqt5charts5-dev
)

# ─── TelcoChisel Official Metapackages (meta.telcosec.net) ───────────────────
PKGS_TELCOCHISEL_META=(
  telcochisel-base
  telcochisel-hardware-sdr
  telcochisel-tools-sdr
  telcochisel-tools-2g-3g
  telcochisel-tools-4g
  telcochisel-tools-5g
  telcochisel-tools-sim
  telcochisel-tools-pstn-adsl
  telcochisel-tools-ue
  telcochisel-meta-full
)

# ─── Modular Lite Edition Base Packages (~1.8 GB ISO) ────────────────────────
# Minimal footprint: XFCE desktop, Low-Latency kernel, Wireshark,
# Calamares installer, Python runtime, and telcosec-pkg client to pull
# modular domain suites (SDR, 5G, SIM, UE, etc.) on-demand from meta.telcosec.net.
PKGS_LITE_BASE=(
  "${PKGS_BASE[@]}"
  wireshark tshark tcpdump
  nmap macchanger netsniff-ng
  python3-pip python3-venv python3-apt
  # Calamares installer
  calamares
  qml-module-qtquick-controls qml-module-qtquick-controls2
  qml-module-qtquick-dialogs qml-module-qtquick-layouts
  qml-module-qtquick-window2
  upower os-prober python3-jsonschema
)



