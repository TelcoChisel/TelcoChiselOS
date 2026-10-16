#!/bin/bash
set -e

echo "=== Running TelcoSec Professional System Optimizations ==="

# 1. Hardware Access & Udev Rules
echo "Deploying hardware udev rules..."
mkdir -p /etc/udev/rules.d/
if [ -f /etc/udev/rules.d/50-telcosec-hw.rules ]; then
  echo "  udev rules already provided by telcochisel-hardware-sdr package."
elif [ -f /tmp/udev/50-telcosec-hw.rules ]; then
  cp /tmp/udev/50-telcosec-hw.rules /etc/udev/rules.d/
  chmod 644 /etc/udev/rules.d/50-telcosec-hw.rules
fi

# RTL-SDR: block the DVB-T kernel driver from grabbing the dongle
if [ -f /etc/modprobe.d/blacklist-rtlsdr.conf ]; then
  echo "  RTL-SDR blacklist already provided by telcochisel-hardware-sdr package."
elif [ -f /tmp/modprobe/blacklist-rtlsdr.conf ]; then
  cp /tmp/modprobe/blacklist-rtlsdr.conf /etc/modprobe.d/blacklist-rtlsdr.conf
fi

# 2. PAM Real-time Scheduling Priority Limits
echo "Deploying real-time limits and configuring groups..."
mkdir -p /etc/security/limits.d/
if [ -f /etc/security/limits.d/99-telcochisel-rt.conf ]; then
  echo "  Real-time limits already provided by telcochisel-base package."
elif [ -f /tmp/security/99-realtime.conf ]; then
  cp /tmp/security/99-realtime.conf /etc/security/limits.d/
  chmod 644 /etc/security/limits.d/99-realtime.conf
fi
# Add realtime, usrp, plugdev, and wireshark groups and ensure telcosec user is enrolled
groupadd -r realtime 2>/dev/null || true
groupadd -r usrp 2>/dev/null || true
groupadd -r plugdev 2>/dev/null || true
groupadd -r wireshark 2>/dev/null || true
usermod -aG realtime,usrp,plugdev,wireshark,netdev,dialout telcosec 2>/dev/null || true

# 3. Custom Desktop Menu & Tool Categories
echo "Deploying custom XFCE tool menus and categories..."
rm -f /etc/xdg/menus/applications-merged/telcosec.menu
# Deploy XFCE applications menu (XFCE's menu system reads $XDG_MENU_PREFIX-applications.menu,
# i.e. xfce-applications.menu, via xfdesktop/xfce4-panel's whiskermenu/applicationsmenu plugins).
if [ -f /tmp/menu/xfce-applications.menu ]; then
  mkdir -p /etc/xdg/menus
  cp /tmp/menu/xfce-applications.menu /etc/xdg/menus/xfce-applications.menu
  chmod 644 /etc/xdg/menus/xfce-applications.menu
fi

mkdir -p /usr/share/desktop-directories/
if [ -d /tmp/menu/directories ]; then
  cp -rf /tmp/menu/directories/. /usr/share/desktop-directories/
fi

mkdir -p /usr/share/applications/
if [ -d /tmp/menu/applications ]; then
  cp -rf /tmp/menu/applications/. /usr/share/applications/
  chmod 644 /usr/share/applications/*.desktop || true
  chmod +x /usr/share/applications/*.desktop || true
fi

# Deploy Dedicated TelcoSec Category & Brand Vector Icons
echo "Deploying custom TelcoSec category and brand icons and refreshing icon cache..."
mkdir -p /usr/share/icons/hicolor/scalable/categories/
mkdir -p /usr/share/icons/hicolor/scalable/apps/
mkdir -p /usr/share/icons/hicolor/48x48/apps/
mkdir -p /usr/share/pixmaps/

if [ -d /tmp/icons ]; then
  cp -rf /tmp/icons/*.svg /usr/share/icons/hicolor/scalable/apps/ 2>/dev/null || true
  cp -rf /tmp/icons/*.svg /usr/share/pixmaps/ 2>/dev/null || true
fi

if [ -d /tmp/icons/categories ]; then
  cp -rf /tmp/icons/categories/*.svg /usr/share/icons/hicolor/scalable/categories/
  cp -rf /tmp/icons/categories/*.svg /usr/share/icons/hicolor/scalable/apps/
  chmod 644 /usr/share/icons/hicolor/scalable/categories/*.svg || true
  chmod 644 /usr/share/icons/hicolor/scalable/apps/*.svg || true
  
  # Also link into active Papirus/Yaru themes if present
  if [ -d /usr/share/icons/Papirus-Dark ]; then
    mkdir -p /usr/share/icons/Papirus-Dark/48x48/categories/
    mkdir -p /usr/share/icons/Papirus-Dark/48x48/apps/
    cp -rf /tmp/icons/categories/*.svg /usr/share/icons/Papirus-Dark/48x48/categories/ 2>/dev/null || true
    cp -rf /tmp/icons/*.svg /usr/share/icons/Papirus-Dark/48x48/apps/ 2>/dev/null || true
  fi
  if [ -d /usr/share/icons/Papirus ]; then
    mkdir -p /usr/share/icons/Papirus/48x48/categories/
    mkdir -p /usr/share/icons/Papirus/48x48/apps/
    cp -rf /tmp/icons/categories/*.svg /usr/share/icons/Papirus/48x48/categories/ 2>/dev/null || true
    cp -rf /tmp/icons/*.svg /usr/share/icons/Papirus/48x48/apps/ 2>/dev/null || true
  fi
fi

# Deploy branding logo as telcosec.png and telcochisel.png
if [ -f /tmp/calamares-config/branding/telcosec/logo.png ]; then
  cp -f /tmp/calamares-config/branding/telcosec/logo.png /usr/share/pixmaps/telcosec.png
  cp -f /tmp/calamares-config/branding/telcosec/logo.png /usr/share/pixmaps/telcochisel.png
  cp -f /tmp/calamares-config/branding/telcosec/logo.png /usr/share/icons/hicolor/48x48/apps/telcosec.png
  cp -f /tmp/calamares-config/branding/telcosec/logo.png /usr/share/icons/hicolor/48x48/apps/telcochisel.png
  if [ -d /usr/share/icons/Papirus-Dark ]; then
    cp -f /tmp/calamares-config/branding/telcosec/logo.png /usr/share/icons/Papirus-Dark/48x48/apps/telcosec.png
    cp -f /tmp/calamares-config/branding/telcosec/logo.png /usr/share/icons/Papirus-Dark/48x48/apps/telcochisel.png
  fi
fi

gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
gtk-update-icon-cache -f -t /usr/share/icons/Papirus-Dark 2>/dev/null || true

# 4. Wireshark Dissector Profile & Plugins
echo "Configuring default Wireshark telecom profile, custom Lua plugins, and OpenAPI schemas..."
mkdir -p /etc/skel/.config/wireshark/ /home/telcosec/.config/wireshark/
if [ -f /tmp/wireshark/preferences ]; then
  # For future users created via Calamares
  cp /tmp/wireshark/preferences /etc/skel/.config/wireshark/preferences
  # For the pre-created live user
  cp /tmp/wireshark/preferences /home/telcosec/.config/wireshark/preferences
fi
if [ -f /tmp/wireshark/colorfilters ]; then
  cp /tmp/wireshark/colorfilters /etc/skel/.config/wireshark/colorfilters
  cp /tmp/wireshark/colorfilters /home/telcosec/.config/wireshark/colorfilters
fi
chown -R telcosec:telcosec /home/telcosec/.config 2>/dev/null || true

# Deploy custom Lua plugins system-wide
mkdir -p /usr/share/wireshark/plugins/
if [ -d /tmp/wireshark/plugins ]; then
  cp -rf /tmp/wireshark/plugins/. /usr/share/wireshark/plugins/
  chmod 644 /usr/share/wireshark/plugins/*.lua || true
fi

# Create directory for 5G SBI OpenAPI YAML definitions and deploy downloader
mkdir -p /etc/wireshark/openapi/
chmod 755 /etc/wireshark/openapi/
if [ -f /tmp/scripts/bin/telcosec-download-openapi ]; then
  cp -f /tmp/scripts/bin/telcosec-download-openapi /usr/local/bin/telcosec-download-openapi
  chmod 755 /usr/local/bin/telcosec-download-openapi
fi

# 5. Boot Theme (GRUB & Plymouth Customization)
echo "Deploying custom boot styling (GRUB & Plymouth)..."
mkdir -p /etc/default/grub.d/
if [ -f /tmp/boot/grub-theme.conf ]; then
  cp /tmp/boot/grub-theme.conf /etc/default/grub.d/99-telcosec.cfg
  chmod 644 /etc/default/grub.d/99-telcosec.cfg
fi

# Deploy the logo, GRUB splash, and desktop wallpaper backgrounds
mkdir -p /usr/share/backgrounds/telcosec/
if [ -f /tmp/calamares-config/branding/telcosec/logo.png ]; then
  cp /tmp/calamares-config/branding/telcosec/logo.png /usr/share/backgrounds/telcosec/logo.png
fi
if [ -f /tmp/boot/grub_background.png ]; then
  cp /tmp/boot/grub_background.png /usr/share/backgrounds/telcosec/grub_background.png
fi
if [ -f /tmp/boot/wallpaper.jpg ]; then
  cp /tmp/boot/wallpaper.jpg /usr/share/backgrounds/telcosec/wallpaper.jpg
elif [ -f /tmp/calamares-config/branding/telcosec/logo.png ]; then
  cp /tmp/calamares-config/branding/telcosec/logo.png /usr/share/backgrounds/telcosec/wallpaper.jpg
fi
chmod 644 /usr/share/backgrounds/telcosec/* 2>/dev/null || true

# Refresh GRUB configurations inside the chroot
if command -v update-grub &> /dev/null; then
  update-grub || true
fi

# Deploy custom Plymouth boot theme
echo "Deploying custom Plymouth boot animation..."
mkdir -p /usr/share/plymouth/themes/telcosec/
# Copy our custom Plymouth files (includes the locally-generated
# password_field.png / password_dot.png used by the LUKS unlock dialogue —
# see builder/boot/plymouth/telcosec.script). These are staged from the repo,
# not pulled from a theme that may not exist on this distro/release.
if [ -d /tmp/boot/plymouth ]; then
  cp -rf /tmp/boot/plymouth/. /usr/share/plymouth/themes/telcosec/
fi
# Belt-and-braces: if the repo assets were somehow missing from the staged
# copy above, guard-copy them individually so a partial checkout doesn't
# silently ship a theme with no password prompt assets.
for asset in password_field.png password_dot.png; do
  if [ ! -f "/usr/share/plymouth/themes/telcosec/${asset}" ] && [ -f "/tmp/boot/plymouth/${asset}" ]; then
    cp "/tmp/boot/plymouth/${asset}" "/usr/share/plymouth/themes/telcosec/${asset}"
  fi
done
# Set the official TelcoSec logo for the boot splash logo
if [ -f /usr/share/backgrounds/telcosec/logo.png ]; then
  cp /usr/share/backgrounds/telcosec/logo.png /usr/share/plymouth/themes/telcosec/logo.png
fi
# Set telcosec as the default theme
mkdir -p /etc/plymouth/
cat << 'EOF' > /etc/plymouth/plymouthd.conf
[Daemon]
Theme=telcosec
ShowDelay=0
DeviceTimeout=8
EOF

# Register and set the theme via update-alternatives
if [ -f /usr/share/plymouth/themes/telcosec/telcosec.plymouth ]; then
  update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/telcosec/telcosec.plymouth 100
  update-alternatives --set default.plymouth /usr/share/plymouth/themes/telcosec/telcosec.plymouth
fi

# 6. SCTP Stack Optimizations
echo "Deploying SCTP module loading and sysctl tuning..."
# Enable auto-loading of the sctp kernel module at boot (if not already handled by telcochisel-base)
if [ -f /etc/modules-load.d/telcochisel-sctp.conf ]; then
  echo "  SCTP module auto-loading already configured by telcochisel-base package."
elif [ -f /etc/modules ]; then
  if ! grep -q "^sctp$" /etc/modules 2>/dev/null; then
    echo "sctp" >> /etc/modules
  fi
else
  echo "sctp" > /etc/modules
fi

# Deploy kernel sysctl settings
mkdir -p /etc/sysctl.d/
if [ -f /tmp/security/99-sctp-tuning.conf ]; then
  cp /tmp/security/99-sctp-tuning.conf /etc/sysctl.d/
  chmod 644 /etc/sysctl.d/99-sctp-tuning.conf
fi
if [ -f /tmp/security/99-security-hardening.conf ]; then
  cp /tmp/security/99-security-hardening.conf /etc/sysctl.d/
  chmod 644 /etc/sysctl.d/99-security-hardening.conf
fi

# Attempt to load module and apply sysctl settings (ignores failures in chroot)
modprobe sctp 2>/dev/null || true
if command -v sysctl &> /dev/null; then
  sysctl --system 2>/dev/null || true
fi

# 7. Real-time & Low-latency Tuning for 5G NR / 5Ghoul
# OAI requires tight timing budgets (~1 ms TTI). We use 'tuned' to manage
# CPU governors, IRQ affinity, hugepages, and USB latency in one profile.
echo "Deploying real-time and low-latency tuned profile..."

mkdir -p /etc/tuned/telcosec-sdr

cat << 'EOF' > /etc/tuned/telcosec-sdr/tuned.conf
[main]
summary=Optimize for SDR and 5G Fuzzing (Low Latency, High Performance)
include=network-latency

[cpu]
governor=performance
energy_perf_bias=performance
min_perf_pct=100

[sysctl]
vm.swappiness=10
kernel.sched_min_granularity_ns=10000000
kernel.sched_wakeup_granularity_ns=15000000
vm.nr_hugepages=512
vm.hugetlb_shm_group=0

[bootloader]
cmdline=mitigations=off clocksource=tsc tsc=reliable intel_idle.max_cstate=1 processor.max_cstate=1 usbcore.usbfs_memory_mb=1000

[script]
script=tuned-sdr.sh
EOF

cat << 'EOF' > /etc/tuned/telcosec-sdr/tuned-sdr.sh
#!/bin/bash

# USB latency: reduce polling interval for SDR hardware
if [ "$1" = "start" ]; then
    # Disable autosuspend for generic USB hubs to prevent SDR disconnects
    for dev in /sys/bus/usb/devices/*/power/autosuspend_delay_ms; do
        echo 0 > "$dev" 2>/dev/null || true
    done
    for control in /sys/bus/usb/devices/*/power/control; do
        echo on > "$control" 2>/dev/null || true
    done
fi
EOF
chmod +x /etc/tuned/telcosec-sdr/tuned-sdr.sh

# Enable the profile in the chroot. It will apply on boot.
if command -v tuned-adm &> /dev/null; then
  tuned-adm profile telcosec-sdr 2>/dev/null || true
fi

# Ensure the service actually starts on the installed/live system so the
# telcosec-sdr profile (governor=performance, hugepages, bootloader cmdline) applies.
systemctl enable tuned.service 2>/dev/null || true

# 8. Firewall Hardening
echo "Configuring default firewall policies..."
if command -v ufw &> /dev/null; then
  ufw default deny incoming || true
  ufw default allow outgoing || true
  ufw allow ssh || true
  ufw enable || true
  echo "  UFW firewall enabled with secure defaults (deny incoming, allow outgoing)"
fi

# 8.5. NetworkManager Cellular Interfaces Override
echo "Configuring NetworkManager to ignore virtual cellular interfaces..."
mkdir -p /etc/NetworkManager/conf.d/
cat << 'EOF' > /etc/NetworkManager/conf.d/99-telcosec-unmanaged.conf
[keyfile]
# Ignore cellular network virtual interfaces to prevent DHCP/MTU hijacking
unmanaged-devices=interface-name:ogstun*;interface-name:srs*;interface-name:uesimtun*;interface-name:oaitun*;interface-name:tun_srsue

[device]
# Disable MAC randomization during Wi-Fi scans to prevent testbed connectivity issues
wifi.scan-rand-mac-address=no
EOF


# 9. Bluetooth: Off by Default
echo "Disabling Bluetooth by default..."
rfkill block bluetooth 2>/dev/null || true

# 10. Restrictive Default Umask
echo "Setting restrictive default umask (027)..."
echo 'umask 027' > /etc/profile.d/telcosec_umask.sh
chmod 644 /etc/profile.d/telcosec_umask.sh

# 11. Disable Unnecessary GNOME Background Daemons
echo "Disabling unnecessary GNOME and network daemons..."
# Disable GNOME color profile daemon — only needed for monitor calibration
systemctl disable colord 2>/dev/null || true
# Disable GNOME remote login
systemctl disable gnome-remote-desktop 2>/dev/null || true
# Disable Avahi mDNS — unwanted network advertisement on a research host
systemctl disable avahi-daemon 2>/dev/null || true
systemctl mask avahi-daemon 2>/dev/null || true
# Nothing on the path to the desktop needs network-online; docker pulls it in
# and it stalls boot up to 2 min with no carrier. Mask it.
systemctl mask NetworkManager-wait-online.service 2>/dev/null || true

# 11b. Systemd-resolved DNS privacy configuration
echo "Harden systemd-resolved (disable LLMNR and mDNS)..."
mkdir -p /etc/systemd/resolved.conf.d
cat << 'EOF' > /etc/systemd/resolved.conf.d/telcosec-privacy.conf
[Resolve]
LLMNR=no
MulticastDNS=no
EOF

# 11c. Security & Performance Profile Switcher (telcosec-profile)
echo "Deploying telcosec-profile CLI utility (Lab Mode vs Field Mode)..."
cat << 'PROFILESCRIPT' > /usr/local/bin/telcosec-profile
#!/bin/bash
# telcosec-profile — Security & Performance Profile Switcher for TelcoChiselOS
# Allows switching between Lab Mode (optimized for SDR / low-latency research)
# and Field Mode (hardened firewall, strict reverse path filtering, rate-limited SSH).

set -e

SHOW_HELP() {
  cat << 'HELP'
Usage: sudo telcosec-profile [COMMAND]

Commands:
  status        Display current operational profile and active settings
  set lab       Activate Lab Mode (SDR low-latency tuned profile, rp_filter=0, open SDR routing)
  set field     Activate Field Mode (hardened firewall, strict rp_filter=1, standard scheduler)
  help          Show this help dialogue

Profiles:
  lab   (Default) High performance & low latency: tuned telcosec-sdr profile active,
                  rp_filter=0 for packet crafting/spoofing, cellular TUN unmanaged.
  field Hardened for untrusted/conference networks: strict reverse-path filtering,
                  UFW strict deny incoming, balanced power profile.
HELP
}

CMD="${1:-status}"
ARG="${2:-}"

case "$CMD" in
  status)
    echo "=== TelcoChisel Operational Profile Status ==="
    RP=$(sysctl -n net.ipv4.conf.all.rp_filter 2>/dev/null || echo "unknown")
    TUNED_ACT=$(tuned-adm active 2>/dev/null | awk -F': ' '{print $2}' || echo "inactive")
    UFW_STATUS=$(ufw status 2>/dev/null | grep -i "Status:" | awk '{print $2}' || echo "inactive")
    
    echo "  Current Tuned Profile : ${TUNED_ACT:-none}"
    echo "  Reverse Path Filter   : net.ipv4.conf.all.rp_filter = ${RP}"
    echo "  UFW Firewall Status   : ${UFW_STATUS:-unknown}"
    if [ "$RP" = "0" ]; then
      echo "  Active Profile Mode   : [ LAB MODE (SDR / Research Optimized) ]"
    else
      echo "  Active Profile Mode   : [ FIELD MODE (Hardened / Untrusted Network) ]"
    fi
    ;;

  set)
    if [ "$(id -u)" -ne 0 ]; then
      echo "ERROR: Run with sudo (e.g. sudo telcosec-profile set $ARG)"
      exit 1
    fi
    case "$ARG" in
      lab)
        echo "--> Switching to Lab Mode (SDR / Research Optimized)..."
        tuned-adm profile telcosec-sdr 2>/dev/null || true
        sysctl -w net.ipv4.conf.all.rp_filter=0 >/dev/null 2>&1 || true
        sysctl -w net.ipv4.conf.default.rp_filter=0 >/dev/null 2>&1 || true
        ufw allow ssh >/dev/null 2>&1 || true
        echo "✓ Lab Mode active: Real-time tuned profile loaded, packet spoofing/routing unblocked."
        ;;
      field)
        echo "--> Switching to Field Mode (Hardened / Field Security)..."
        tuned-adm profile balanced 2>/dev/null || tuned-adm profile throughput-performance 2>/dev/null || true
        sysctl -w net.ipv4.conf.all.rp_filter=1 >/dev/null 2>&1 || true
        sysctl -w net.ipv4.conf.default.rp_filter=1 >/dev/null 2>&1 || true
        ufw limit ssh >/dev/null 2>&1 || true
        echo "✓ Field Mode active: Strict reverse-path filtering enabled, SSH rate-limited."
        ;;
      *)
        echo "ERROR: Unknown profile: '$ARG' (options: lab | field)"
        exit 1
        ;;
    esac
    ;;

  help|--help|-h)
    SHOW_HELP
    ;;

  *)
    echo "ERROR: Unknown command: '$CMD'"
    SHOW_HELP
    exit 1
    ;;
esac
PROFILESCRIPT
chmod +x /usr/local/bin/telcosec-profile

# 11d. Unified TelcoSec Operator CLI, Shell Completions & Manual Pages
# Layout:
#   /usr/local/bin/telcosec       — bash wrapper (execs Go when present)
#   /usr/local/libexec/telcosec   — Go binary (preferred implementation)
#   /usr/local/bin/telcosec.bash  — explicit bash (TELCOSEC_FORCE_BASH=1 also works)
echo "Deploying unified telcosec operator CLI, shell completions, and manpages..."
CLI_DEPLOYED=0
mkdir -p /usr/local/libexec
if [ -f /tmp/scripts/bin/telcosec ]; then
  install -m 755 /tmp/scripts/bin/telcosec /usr/local/bin/telcosec
  install -m 755 /tmp/scripts/bin/telcosec /usr/local/bin/telcosec.bash
  ln -sf /usr/local/bin/telcosec /usr/local/bin/telcochisel
  echo "  Installed bash wrapper at /usr/local/bin/telcosec (+ telcosec.bash)"
fi

if [ -d /tmp/telcosec-cli ] && command -v go >/dev/null 2>&1; then
  echo "  Building standalone telcosec Go binary from source..."
  (
    cd /tmp/telcosec-cli
    make build
    make install-completions
    make install-man
    install -m 755 bin/telcosec /usr/local/libexec/telcosec
  ) && CLI_DEPLOYED=1 || echo "  Warning: In-chroot Go compilation failed — bash wrapper will run natively."
fi

if [ "$CLI_DEPLOYED" -eq 1 ]; then
  echo "  Go CLI installed at /usr/local/libexec/telcosec (PATH wrapper will exec it)"
elif [ -d /tmp/telcosec-cli ]; then
  (
    cd /tmp/telcosec-cli
    make install-completions 2>/dev/null || true
    make install-man 2>/dev/null || true
  )
fi

if [ -f /tmp/scripts/bin/telcosec-create-usb ]; then
  cp -f /tmp/scripts/bin/telcosec-create-usb /usr/local/bin/telcosec-create-usb
  chmod 755 /usr/local/bin/telcosec-create-usb
fi

if [ -f /tmp/scripts/bin/telcosec-pkg ]; then
  cp -f /tmp/scripts/bin/telcosec-pkg /usr/local/bin/telcosec-pkg
  chmod 755 /usr/local/bin/telcosec-pkg
  ln -sf /usr/local/bin/telcosec-pkg /usr/local/bin/telcochisel-pkg
fi

if [ -f /tmp/scripts/bin/telcosec-sdr ]; then
  cp -f /tmp/scripts/bin/telcosec-sdr /usr/local/bin/telcosec-sdr
  chmod 755 /usr/local/bin/telcosec-sdr
  ln -sf /usr/local/bin/telcosec-sdr /usr/local/bin/telcochisel-sdr
fi

# 11e. APT Repository Pinning
echo "Deploying TelcoChisel APT repository pinning preferences..."
mkdir -p /etc/apt/preferences.d/
if [ -f /tmp/security/99-telcochisel.pref ]; then
  cp -f /tmp/security/99-telcochisel.pref /etc/apt/preferences.d/99-telcochisel.pref
  chmod 644 /etc/apt/preferences.d/99-telcochisel.pref
fi

# 12. Custom Domain Certificates Trust
# If a custom Root/Intermediate CA cert exists, install it to system CA trust store
if [ -f /tmp/security/telcosec-ca.crt ]; then
  echo "Installing TelcoSec domain CA certificate..."
  cp /tmp/security/telcosec-ca.crt /usr/local/share/ca-certificates/
  chmod 644 /usr/local/share/ca-certificates/telcosec-ca.crt
fi

# Install Cloudflare Origin CA root certificates
echo "Installing Cloudflare Origin CA certificates..."
_CF_SRC_DIR=/tmp/security/cloudflare
_CF_FAIL=0

if [ -d "$_CF_SRC_DIR" ] && [ -f "$_CF_SRC_DIR/SHA256SUMS" ]; then
  mkdir -p /usr/local/share/ca-certificates
  if (cd "$_CF_SRC_DIR" && sha256sum -c SHA256SUMS --quiet); then
    for crt in cloudflare_origin_ecc.crt cloudflare_origin_rsa.crt; do
      cp "$_CF_SRC_DIR/$crt" "/usr/local/share/ca-certificates/$crt"
      chmod 644 "/usr/local/share/ca-certificates/$crt"
      echo "  ${crt}: OK (checksum verified)"
    done
  else
    echo "  WARNING: Cloudflare CA checksum verification FAILED — refusing to install (possible tampering or stale vendored file)"
    _CF_FAIL=1
  fi
else
  echo "  WARNING: vendored Cloudflare CA certs not found at $_CF_SRC_DIR — Cloudflare-origin certs will not be trusted"
  _CF_FAIL=1
fi

update-ca-certificates 2>/dev/null || true
if [ "$_CF_FAIL" = "1" ]; then
  echo "  !! BUILD WARNING: Cloudflare CA install failed — live image may reject Cloudflare-origin TLS certs" >&2
fi

# 12.5. Terminal Aliases & Tool Shortcuts
echo "Deploying global terminal aliases..."
cat << 'EOF' > /etc/profile.d/telcosec-aliases.sh
#!/bin/sh
# TelcoSec Professional Terminal Aliases

# YateBTS
alias yate-logs="tail -f /var/log/yate.log"

# SDR & Firmware
alias update-sdr="sudo /usr/local/bin/uhd-download-images && sudo /usr/local/bin/LimeUtil --update"

# Networking & Utils
alias ports="sudo netstat -tulpn"
EOF
# Deploy all helper binaries from /tmp/scripts/bin
echo "Deploying system CLI tools from /tmp/scripts/bin..."
if [ -d /tmp/scripts/bin ]; then
  cp -rf /tmp/scripts/bin/* /usr/local/bin/ 2>/dev/null || true
fi
chmod 755 /usr/local/bin/* 2>/dev/null || true

# Enforce execute permissions across all /opt/telcosec tool repositories and venvs
if [ -d /opt/telcosec ]; then
  echo "Ensuring execute permissions across /opt/telcosec tools and environments..."
  find /opt/telcosec -type d -exec chmod 755 {} + 2>/dev/null || true
  find /opt/telcosec -type f \( -name "*.sh" -o -name "*.py" -o -path "*/bin/*" \) -exec chmod +x {} + 2>/dev/null || true
fi

# Configure Linux network capabilities for non-root packet injection & sniffing
echo "Configuring Linux capabilities for non-root telecom network capture & packet crafting..."
if command -v dumpcap &>/dev/null; then
  chgrp wireshark "$(command -v dumpcap)" 2>/dev/null || true
  chmod 750 "$(command -v dumpcap)" 2>/dev/null || true
  setcap cap_net_raw,cap_net_admin+eip "$(command -v dumpcap)" 2>/dev/null || true
fi
if command -v mz &>/dev/null; then
  setcap cap_net_raw,cap_net_admin+eip "$(command -v mz)" 2>/dev/null || true
fi
if command -v sctpscan &>/dev/null; then
  setcap cap_net_raw+eip "$(command -v sctpscan)" 2>/dev/null || true
fi
if command -v tcpdump &>/dev/null; then
  setcap cap_net_raw,cap_net_admin+eip "$(command -v tcpdump)" 2>/dev/null || true
fi

echo "Deploying global tool PATH environment..."
cat << 'EOF' > /etc/profile.d/telcosec-env.sh
#!/bin/sh
# TelcoSec Professional Tool Paths & Environment Setup

# Standard System & Conda & Opt Tool Paths
export PATH="/opt/telcosec/miniconda/envs/telcosec-sdr/bin:/opt/telcosec/miniconda/bin:/opt/telcosec/bin:/usr/local/sbin:/usr/local/bin:$PATH"

if [ -d "/opt/telcosec" ]; then
    for tool_dir in /opt/telcosec/*; do
        if [ -d "$tool_dir" ]; then
            if [ -d "$tool_dir/bin" ]; then
                PATH="$PATH:$tool_dir/bin"
            fi
        fi
    done
    export PATH
fi

# Auto-source Conda profile integration if present
if [ -f "/opt/telcosec/miniconda/etc/profile.d/conda.sh" ]; then
    . /opt/telcosec/miniconda/etc/profile.d/conda.sh 2>/dev/null || true
fi

# Telecom Hardware & SDR Environment Variables
export UHD_IMAGES_DIR="/usr/share/uhd/images:/opt/telcosec/uhd/share/uhd/images"
export SOAPY_SDR_PLUGIN_PATH="/usr/lib/x86_64-linux-gnu/SoapySDR/modules0.8:/usr/local/lib/SoapySDR/modules0.8"
export PYTHONPATH="/opt/telcosec/lib/python3/dist-packages:/usr/local/lib/python3/dist-packages:${PYTHONPATH}"

# Cellular Core & RAN Configuration Paths
export OPEN5GS_CONFIG_DIR="/etc/open5gs"
export UERANSIM_CONFIG_DIR="/etc/ueransim"
export VOLK_CONFIG_DIR="/etc/volk"

# GSMTAP & Protocol Dissection Defaults
export GSMTAP_DEFAULT_PORT=4729
export GSMTAP_V3_DEFAULT_PORT=47290
export TELCOSEC_CATALOG="/usr/share/telcosec/tools.json"

# Terminal & Editor Defaults
export TERMINAL="terminator"
export EDITOR="nano"

# General Linux Environment Defaults
export PYTHONUNBUFFERED=1
export LANG=${LANG:-en_US.UTF-8}
export LC_ALL=${LC_ALL:-en_US.UTF-8}
EOF
chmod 644 /etc/profile.d/telcosec-env.sh


# 13. SSH Host Keys Cleanup
# Deletes any build-time SSH keys to ensure that OpenSSH regenerates unique,
# fresh host keys upon the first boot of the live ISO or installed system.
if [ -d /etc/ssh ]; then
  echo "Cleaning up build-time SSH host keys to trigger regeneration on first boot..."
  rm -f /etc/ssh/ssh_host_*_key*
fi

# 14. Ensure All Desktop Shortcuts Have Proper Permissions and Trust
echo "Applying final desktop shortcut trust and permissions..."
chmod 755 /etc/skel/Desktop/*.desktop /home/telcosec/Desktop/*.desktop 2>/dev/null || true
for f in /etc/skel/Desktop/*.desktop /home/telcosec/Desktop/*.desktop; do
  [ -f "$f" ] || continue
  gio set -t string "$f" metadata::trusted true 2>/dev/null || true
  gio set -t string "$f" metadata::trusted yes 2>/dev/null || true
done
if [ -d /home/telcosec ]; then
  chown -R telcosec:telcosec /home/telcosec/Desktop /home/telcosec/.config 2>/dev/null || true
fi

echo "=== System Optimizations Applied Successfully ==="
