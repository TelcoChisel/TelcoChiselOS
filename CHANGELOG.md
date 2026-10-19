# Changelog

All notable changes to the **TelcoChisel Live Linux Distribution** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- Dedicated 5Ghoul overlay at `packages/5ghoul-5g-nr-attacks` (pinned upstream commit, BladeRF/LimeSDR/USRP radio apply). Image: `telcochisel-5ghoul` (default radio BladeRF).

### Changed
- GitHub org for the distribution and packaging repos is [TelcoChisel](https://github.com/TelcoChisel): `TelcoChiselOS`, `5ghoul-5g-nr-attacks`, `telcosec-cli`, `homebrew-tap`, `telcochisel-metapackages`. Docs, compose, and GHCR paths use `ghcr.io/telcochisel/…` and `brew tap telcochisel/tap`.
- CI: single validate job (path-gated catalogs; Go CLI CI only in `telcosec-cli`). Docker: GHCR-first on tags, Hub/DO opt-in, GHA cache `mode=min`, `telcochisel` registry defaults. Release: weekly cron builds lite ISO; apt/ccache keys rotate weekly.
- Website (`telcochisel.com`) lives in [TelcoChisel/website](https://github.com/TelcoChisel/website); OS `deploy-docs` retired in favor of that repo + `notify-website.yml` on catalog changes.

### Security
- Dashboard: deny nginx serving of dotfiles (`.env`); generate per-install DB password at first boot; path-guarded mkdir/chown helpers (no sudoers `*` wildcards).
- Compose: remove default `docker.sock` mount; opt-in via `docker/compose.docker-sock.yaml`.
- Containers: replace `NOPASSWD:ALL` with scoped apt/install-helper sudoers.
- VMs: cloud-init uses password-required sudo (not `NOPASSWD:ALL`).
- K8s device-audit pod: non-privileged default; privileged variant is opt-in.
- CLI `pkg repo enable`: fingerprint-verified key install (no `curl | bash` from floating `main`).
- Docker base image: fingerprint-verify TelcoChisel APT key (parity with ISO).

### Changed
- ISO builds fail when `record_tool` reports FAIL (override: `TELCOSEC_ALLOW_TOOL_FAILURES=1`).
- Operator CLI layout: Go binary at `/usr/local/libexec/telcosec`; bash wrapper on PATH execs it.
- Critical upstream clones pinned to release tags where available (UERANSIM, gtp5g, srsRAN, SIPp, OAI, etc.).
- GitHub Actions in root and nested package workflows pinned to commit SHAs.
- Docs deploy uses `npm ci`; Dependabot + ShellCheck job added; SF secrets scoped to publish steps.
- Canonical messaging aligned to `2026.2` / 100-tool catalog (online sidebar + offline docs).
- Miniconda / rustup-init version-pinned; Docker clone pins aligned with ISO; container builds set `TELCOSEC_ALLOW_TOOL_FAILURES=1`.
- `docker_open5gs` pinned to commit `1f3bcf73f926…` (no upstream tags).

---

## [3.1.0] - 2026-09-26 (Noble Cellular)

### Added
- **Telecom Security Arsenal Expansion (100 Instruments)**:
  - Expanded the tool catalog across 11 domains to reach 100 specialized tools.
  - Added desktop launchers and interactive terminal wrappers for:
    - `falcon`: Falcon LTE/4G cellular security analyzer.
    - `lime-suite`: LimeSuite LimeUtil multi-device SDR manager.
    - `sdr-info`: Multi-SDR transceiver hardware prober.
    - `telcosec-ran-status`: RAN emission, frequency assignment, and gNodeB telemetry reporter.
    - `sctpscan`: SCTP raw port scanner and multi-homing analyzer.
    - `sipvicious`: SIPVicious VoIP and IMS penetration testing suite (`svmap`, `svwar`, `svcrack`).
    - `mausezahn`: High-speed hardware-rate carrier Ethernet and VLAN packet crafter.
    - `voiphopper`: Voice VLAN hopping security audit tool.
    - `rtpbleed`: Real-time RTP audio stream bleeding and interception scanner.
    - `sipsak`: SIP Swiss Army Knife for SIP server and PBX stress testing.
- **Tactical Cyberpunk XFCE Desktop Environment & Theme**:
  - **Full GTK3 Theme Integration (`gtk.css`)**: 450+ line tactical styling system applying obsidian `#0a0e17` canvas, cyan `#00ffd5` accents, amber `#e8921e` warnings, and coral `#ff4466` alerts across panel plugins, menus, text entries, buttons, notebooks, treeviews, and Whisker Menu.
  - **11-Domain XDG Whisker Menu Structure**: Built `telcosec-applications.menu` paired with 11 localized `.directory` metadata definitions mapping all 100 instruments into curated tactical operational categories.
  - **Live Genmon Panel Telemetry Widgets**:
    - `telcosec-genmon-sdr`: Real-time probe enumerating connected USRP, HackRF, BladeRF, LimeSDR, RTL-SDR, and PlutoSDR hardware transceivers directly on the XFCE panel.
    - `telcosec-genmon-core`: Live status indicator monitoring Open5GS and srsRAN systemd daemon lifecycle and active subscribers.
    - `telcosec-genmon-net`: Continuous monitor for WireGuard (`wg0`), OpenVPN (`tun0`), and cellular dialers (`wwan0`) displaying active tunnel IPs.
  - **Zero-Drop Picom GLX Compositor**: Configured `use-damage = false` and GLX XPresent vsync with comprehensive SDR window exclusions (`Gqrx`, `Inspectrum`, `URH`, `Wireshark`) to eliminate display tearing and waterfall packet-drop during high-bandwidth I/Q rendering.
  - **Low-Latency Xfwm4 Window Management**: Disabled internal compositor (`use_compositing = false`), enabled focus-follows-mouse, and configured edge snap resistance.
  - **Tactical Conky HUD (`telcosec-hud-sdr`)**: Translucent desktop head-up display providing live RF transceiver enumeration, Open5GS daemon matrix, CPU core load, and capture drive storage, toggleable via `Super + H` or `/usr/local/bin/telcosec-toggle-hud`.
  - **Forensic Thunar File Manager Enhancements**:
    - Deployed 8 custom context actions: Open Terminal Here, Dissect with Wireshark (GSMTAP), Inspect I/Q with Inspectrum, pySim-shell SIM Access, Calculate SHA-256 Evidence Hash, SCAT IMSI Extraction, TShark 5G NAS Filter, and Analyze with URH.
    - Deployed 8 pinned sidebar bookmarks pointing to `/home/telcosec/captures` (`pcap`, `iq`, `apdu`, `evidence`), `/opt/telcosec`, `/usr/share/wordlists/telecom`, and `/usr/share/doc/telcosec`.
  - **Polar Radar Calibrated Wallpaper**: Overhauled `generate-assets.py` to synthesize a 1920x1080 tactical radar display with calibrated dBm concentric rings, 30° radial bearing lines, cardinal markers, and radar sweep arc.
  - **Brand Vector Icons**: Scalable SVG brand icons (`telcosec.svg` and `telcochisel.svg`) installed to `/usr/share/icons/hicolor/scalable/apps/` and Papirus-Dark paths.
  - **Multi-Workspace Configuration**: 7-workspace pager pre-mapped to RF & SDR (WS1), Cellular RAN (WS2), Core Network (WS3), Firmware & BB (WS4), Wireline & VoIP (WS5), Hardware & SIM (WS6), and Evidence & Logs (WS7).
- **Calamares Installer Cyberpunk Redesign**:
  - Developed custom dark-mode Qt stylesheet (`stylesheet.qss`) matching the TelcoChisel obsidian `#0c0f16` and neon cyan `#00ffd5` palette.
  - Updated installer QML slideshow (`show.qml`) highlighting 100 tools, Falcon LTE, LimeSuite, VoIP tools, and modular metapackages.
  - Hardened post-installation cleanup hooks (`shellprocess-cleanup.conf`) to remove installer CLI wrappers and live environment artifacts from target drives.
  - Mapped branded `telcochisel` icon to the live desktop installer shortcut.
- **Bootloader & Plymouth Boot Enhancements**:
  - Created 1920x1080 GRUB splash screen (`grub_background.png`) with radar grid.
  - Configured `GRUB_GFXMODE="1920x1080,1280x720,auto"` and `GRUB_GFXPAYLOAD_LINUX="keep"` for seamless, flicker-free boot transitions.
  - Set menu highlight to brand neon cyan (`light-cyan/black`).
  - Aligned Plymouth boot theme branding to TelcoChisel OS.
- **Tool Permissions & Non-Root Capabilities**:
  - Configured Linux network capabilities (`setcap cap_net_raw,cap_net_admin+eip`) for `dumpcap`, `mz` (Mausezahn), `sctpscan`, and `tcpdump`.
  - Added PAM real-time scheduling priority limits (`rtprio 99`, `memlock unlimited`) for the `@usrp` group in `/etc/security/limits.d/99-realtime.conf`.
  - Guaranteed `chmod 755` executable permissions across all `/usr/local/bin/*` tool wrappers and `/opt/telcosec/` environments.
  - Enrolled user `telcosec` in `wireshark`, `netdev`, and `dialout` groups.

### Fixed
- **SourceForge Git Mirror Sync**: Reconciled divergent initial commit history between GitHub and SourceForge git remotes.
- **Desktop Entry BOMs**: Removed invisible UTF-8 Byte Order Marks (BOM) from desktop launchers and protocol wordlists that disrupted FreeDesktop parsers.
- **Asset Generator Encoding**: Added standard fallback handling in `generate-assets.py` to prevent UnicodeEncodeError on cp1252/ASCII terminals.

---

## [3.0.0] - 2026-09-05 (Noble Numbat)

### Added
- **Dual-Tier ISO Release Architecture**:
  - **Flagship Field Edition (Full)** (`TelcoChisel-3.0.0-amd64.iso`, ~5.0 GB): 100% offline air-gapped readiness with all 88 pre-installed telecom tools, UHD FPGA firmware images (`/usr/share/uhd/images/`), GNU Radio 3.10 Conda environment, Open5GS, srsRAN, and FirmWire baseband emulation.
  - **Modular Lite Edition (Lite)** (`TelcoChisel-3.0.0-lite-amd64.iso`, ~1.8 GB): Clean base XFCE desktop, 1000Hz Low-Latency kernel, Wireshark/TShark, Python runtime, and the `telcosec-pkg` CLI client for pulling modular suites on demand.
- **Base Distribution & Kernel**:
  - Upgraded to **Ubuntu 24.04 LTS (Noble Numbat)** base with real-time `linux-image-lowlatency` (1000Hz timer, preemptible) as the default boot kernel.
  - Dual-kernel fallback architecture (`linux-image-generic` alongside low-latency kernel).
  - SCTP kernel tuning, unlimited `RLIMIT_MEMLOCK`, and `SCHED_RR` real-time scheduling for drop-free SDR streaming.
- **Debian Metapackages (`meta.telcochisel.com`)**:
  - Introduced 8 modular domain packages in `debian/control`: `telcochisel-base`, `telcochisel-sdr`, `telcochisel-5g-sa`, `telcochisel-4g-lte`, `telcochisel-sim`, `telcochisel-baseband`, `telcochisel-wireline`, and `telcochisel-all`.
  - Built custom CLI package manager `telcosec-pkg` with interactive curses menu, search, installation, and dependency management.
- **Hardware & Driver Stacks**:
  - Out-of-the-box hardware drivers compiled from source: Ettus USRP (UHD 4.6.0), Great Scott Gadgets HackRF (`libhackrf` 2024.02.1), Nuand BladeRF 2.0 micro (`libbladeRF` 2.5.0), LimeSDR (`LimeSuite` 23.11.0), and RTL-SDR v3/v4.
  - Smart card audit suite: Sysmocom SIMtrace 2, Osmocom SIMtrace, and Omnikey/Identiv/ACS PCSC readers.
  - Baseband reverse engineering interfaces: Qualcomm EDL / QCSuper, MediaTek `mtkclient`, and Samsung Shannon FirmWire emulator.
- **Automated CI/CD Pipelines**:
  - `.github/workflows/ci.yml`: Sub-45s automated pre-merge CI validating `bash -n` across all 35 provisioning scripts, three-way tool catalog parity, YAML schemas, and Unix LF line endings.
  - `.github/workflows/docker.yml`: Unified container pipeline building 4 multi-platform images (`base`, `sdr`, `core-network`, `device-tools`) with GHA caching, simultaneously publishing to GHCR and Docker Hub.
  - `.github/workflows/deploy-docs.yml`: Optimized Nuxt 3 documentation build with pnpm store caching and automated deployment to both GitHub Pages and SourceForge Project Web.
- **SourceForge Integration & UX**:
  - Automated REST API default download pinning with custom label `Download TelcoChisel Flagship Field Edition (${VERSION})`.
  - Enriched `docs/SOURCEFORGE_FILES_README.md` with hardware compatibility matrix, operator first 60 seconds cheatsheet, and direct review call-to-action.
  - Live desktop application launcher `Rate TelcoChisel on SourceForge` (`builder/menu/applications/telcosec-feedback.desktop`).
  - Synced offline documentation (`builder/docs/index.html`) with online portal, featuring v3.0.0 dual-edition modal and community cards.
- **Installation & Persistence**:
  - Calamares GUI live-to-disk installer with customized TelcoChisel dark theme and automated user creation.
  - Dedicated LUKS-encrypted persistence utility (`telcosec-create-usb`) creating AES-XTS encrypted `casper-rw` partitions.
  - Copy-to-RAM (`toram`) boot mode for maximum I/O performance on systems with 16GB+ RAM.

### Changed
- Refactored `build-iso.sh` with `--flavor=full|lite` dynamic build phasing, package filtering, and automatic compiler cache purging.
- Optimized `release.yml` to generate ISO split chunks once into the workspace, eliminating redundant 5GB multi-part splitting.
- Upgraded tool catalog to 88 tools with unified metadata synchronized across JSON, Vue 3, and static offline HTML.

### Removed
- Standalone 500 KB `yaru-theme-gtk_25.10.3-3_all.deb` (installed via standard APT repository).
- Compiled Python bytecode accidentally tracked in git (`generate-assets.cpython-312.pyc`).
- Redundant `.github/workflows/docker-hub.yml` workflow (merged into `docker.yml`).
- Obsolete one-off maintenance scripts (`update_desktop.py`, redundant `docs/CNAME`).

---

## [1.1.0] - 2026-08-15

### Added
- Expanded tool suite to 75 tools covering 2G/3G/4G cellular protocols.
- Integrated Conda environment `telcosec-sdr` for isolated GNU Radio 3.10 and PySDR dependencies.
- Added Open5GS 5G Standalone core network pre-configuration with MongoDB persistence.
- Added 5Ghoul 5G NR over-the-air fuzzing framework.
- Preliminary SourceForge File Release System distribution.

### Changed
- Migrated default shell configuration to Zsh with Powerline prompt and telecom command completions.
- Improved udev rules coverage for Nuand BladeRF 2.0 micro and RTL-SDR v4.

---

## [1.0.0] - 2026-07-01

### Added
- Initial proof-of-concept Live Linux ISO release based on Ubuntu 22.04 LTS.
- XFCE4 desktop environment with dark telecom styling.
- Core SDR drivers: UHD, HackRF, and RTL-SDR.
- Wireshark with preliminary GSMTAP dissector configuration.
- Basic live boot with credentials `telcosec` / `telcosec`.
