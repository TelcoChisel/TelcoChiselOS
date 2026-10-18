# Contributing to TelcoChisel

Thank you for your interest in contributing to **TelcoChisel**, the open-source live Linux distribution purpose-built for 5G/4G telecom security research, SDR analysis, and baseband auditing.

This document outlines the workflow, architecture, and standards for proposing changes, submitting bug reports, and adding new telecom security tools.

---

## Code of Conduct

TelcoChisel is committed to providing a welcoming, inclusive, and professional environment for all contributors. We expect all participants in discussions, issues, and pull requests to adhere to respectful communication standards.

> [!IMPORTANT]
> **Responsible & Ethical Research**: TelcoChisel is intended exclusively for authorized security research, penetration testing under written authorization, academic study, and defensive evaluation. Tools or PRs designed purely for destructive, unlawful, or unmitigated denial-of-service against commercial cellular infrastructure will not be accepted.

---

## Architecture Overview

Understanding how TelcoChisel is built helps in making effective contributions:

```text
TelcoChiselOS/
├── build-iso.sh               # Root live-build orchestrator (debootstrap, chroot, squashfs, xorriso)
├── build-wsl.sh               # Host-side wrapper for building under WSL 2 Ubuntu
├── VERSION                    # Canonical release id (YYYY.R, e.g. 2026.2)
├── builder/
│   ├── scripts/               # Sequential chroot provisioning phases (note: 06 runs before 05):
│   │   ├── 00-install-all-packages.sh   # Base APT package provisioning & flavor branching
│   │   ├── 01-install-base.sh           # Users, locales, display manager, kernel modules
│   │   ├── 02-install-sdr.sh            # UHD, HackRF, BladeRF, LimeSDR, Conda GNU Radio
│   │   ├── 03-install-core-network.sh   # Open5GS, srsRAN, free5GC, Osmocom CNI
│   │   ├── 04-install-tools.sh          # Protocol analyzers (Wireshark, QCSuper, PySIM)
│   │   ├── 05-desktop-customization.sh  # XFCE themes, wallpapers, panel layouts, i3
│   │   ├── 06-install-ue-analysis.sh    # Mobile baseband tools, ADB, scrcpy
│   │   ├── 07-install-installer.sh      # Calamares GUI installer configuration
│   │   ├── 08-system-optimization.sh    # Real-time kernel tuning, udev rules, limits
│   │   ├── 09-install-5ghoul.sh         # 5Ghoul 5G NR fuzzer framework
│   │   ├── 10-install-telecom-advanced.sh # Advanced telecom tools (SigPloit, SCAT, etc.)
│   │   └── 11-install-device-tools.sh   # Firmware flashing (EDL, MTKClient, Heimdall)
│   ├── menu/applications/     # XDG .desktop launcher shortcuts for the XFCE menu
│   └── docs/                  # Offline HTML documentation (/usr/share/doc/telcosec/)
├── data/
│   └── tools.json             # Canonical single source of truth for the 100-tool catalog
├── packages/
│   ├── metapackages/          # Debian metapackages (telcochisel-*) → meta.telcosec.net
│   ├── telcosec-cli/          # Go operator CLI → `/usr/local/libexec/telcosec`
│   │                          # PATH: bash wrapper at `/usr/local/bin/telcosec`
│   │                          # Explicit bash: `telcosec.bash` or TELCOSEC_FORCE_BASH=1
│   └── homebrew-tap/          # Homebrew Formula distribution
├── docker/                    # Podman & Docker container suites + K8s/Podman pods
├── docs/                      # Online documentation portal (Nuxt 3)
└── scripts/                   # Validation, catalog sync, and maintenance utilities
```

---

## Upstream clone pins

When adding a `git clone` for a new tool, prefer a **release tag** (or commit SHA) over a floating default branch:

```bash
# Preferred — pin via build-tool.sh helper (3rd arg = tag/branch)
clone_bg https://github.com/example/tool "${TELCOSEC_OPT}/tool" v1.2.3

# Or inline with fallback
git clone --depth 1 --branch v1.2.3 https://github.com/example/tool /opt/telcosec/tool \
  || git clone --depth 1 https://github.com/example/tool /opt/telcosec/tool
```

See `RELEASES.md` §5 for the current pin policy and the `TELCOSEC_ALLOW_TOOL_FAILURES` build gate.

---

## The 5-Step Checklist: Adding a New Telecom Tool

To add a new tool to TelcoChisel, follow these 5 mandatory steps to ensure system consistency and catalog synchronization:

### Step 1: Add Installation Commands to Builder Scripts
Identify the appropriate provisioning phase in `builder/scripts/`:
- SDR or Radio driver: `builder/scripts/02-install-sdr.sh`
- Core network stack (5G SA, 4G EPC): `builder/scripts/03-install-core-network.sh`
- Protocol analysis or sniffing: `builder/scripts/04-install-tools.sh`
- Baseband or firmware flashing: `builder/scripts/11-install-device-tools.sh`
- General / Advanced telecom auditing: `builder/scripts/10-install-telecom-advanced.sh`

Use our standard compilation helpers where applicable:
```bash
# Example clone and build pattern
build_from_source "mytool" "https://github.com/example/mytool.git" "v1.2.0" \
    "cmake -B build -DCMAKE_INSTALL_PREFIX=/usr/local && make -C build -j\$(nproc) && make -C build install"
```

### Step 2: Create an XDG `.desktop` Launcher
Create a descriptive `.desktop` file in `builder/menu/applications/<tool-name>.desktop`:
```ini
[Desktop Entry]
Version=1.0
Type=Application
Name=My Telecom Tool
Comment=Interactive 5G Protocol Inspector
Exec=mytool-gui
Icon=utilities-terminal
Terminal=false
Categories=TelcoSec-Tools;
Keywords=5g;telecom;protocol;sdr;
```

### Step 3: Add Hardware udev Rules (If Hardware-Related)
If the tool communicates with specialized USB, PCIe, or Ethernet hardware (SDR, SIM reader, diagnostic interface), add the udev vendor/product rules in `builder/scripts/08-system-optimization.sh` so the unprivileged `telcosec` user can access the device without `sudo`:
```bash
ATTRS{idVendor}=="1234", ATTRS{idProduct}=="5678", MODE="0666", GROUP="telcosec", TAG+="uaccess"
```

### Step 4: Register Tool in Canonical Catalog
Add the tool entry to `data/tools.json`:
```json
{
  "id": "mytool",
  "name": "My Telecom Tool",
  "category": "5g-sa",
  "domain": "5g",
  "summary": "Short one-sentence functional summary",
  "description": "Detailed explanation of what the tool accomplishes and how it is used in audits.",
  "cli_command": "mytool --help",
  "github_url": "https://github.com/example/mytool",
  "license": "GPL-3.0",
  "installed_by_default": true,
  "metapackage": "telcochisel-5g-sa"
}
```

Then synchronize all documentation and application mirrors:
```bash
node scripts/sync-catalogs.js
```
This updates `docs/data/tools.js` and `builder/docs/app.js` automatically.

### Step 5: Map Package in Debian Metapackages
Add the tool's package or binary dependency to the appropriate metapackage in `debian/control` and `builder/scripts/lib/packages.sh`.

---

## Pre-Merge Quality Checks

Before committing or opening a pull request, run the following automated checks locally:

```bash
# 1. Validate Bash syntax across all 35 provisioning scripts
wsl bash scripts/test_syntax.sh

# 2. Check catalog parity across JSON and documentation bundles
node scripts/sync-catalogs.js
node scripts/validate_all_tools.js

# 3. Verify Unix LF line endings (zero CRLF allowed in scripts)
python scripts/fix_crlf.py --check

# 4. Verify YAML schema validity
python -c "import yaml, glob; [yaml.safe_load(open(f, encoding='utf-8')) for f in glob.glob('.github/workflows/*.yml') + glob.glob('docker/pods/*.yaml')]; print('All YAMLs valid!')"
```

All of these checks run automatically in GitHub Actions under `.github/workflows/ci.yml` in less than 45 seconds on every PR.

---

## Building & Testing an ISO Locally

### Prerequisites
- Native Ubuntu 24.04 LTS or Windows WSL 2 (Ubuntu 24.04).
- At least 40 GB of free disk space.
- Root / sudo privileges.

### Fast Build: Modular Lite Edition (~15–20 minutes)
The Lite edition builds in a fraction of the time because it skips massive tool compilation phases:
```bash
# In native Ubuntu / Linux:
sudo ./build-iso.sh --flavor=lite

# In Windows using the WSL wrapper:
./build-wsl.sh --flavor=lite
```

### Full Build: Flagship Field Edition (~45–90 minutes)
```bash
# In native Ubuntu / Linux:
sudo ./build-iso.sh --flavor=full

# In Windows using the WSL wrapper:
./build-wsl.sh --flavor=full
```

### Boot Testing in QEMU
Test your newly built ISO in a virtual machine:
```bash
./scripts/test-iso-boot.sh TelcoChisel-2026.2-lite-amd64.iso
```

---

## Pull Request Guidelines

1. **Branch Naming**: Use descriptive branch names like `feature/add-5g-trace`, `fix/uhd-firmware-path`, or `docs/update-cheatsheet`.
2. **Commit Messages**: Follow [Conventional Commits](https://www.conventionalcommits.org/) format:
   - `feat(tools): add srsran-project 24.10 gNodeB support`
   - `fix(kernel): adjust SCTP buffer allocation limits`
   - `docs(readme): update SourceForge download links`
3. **PR Description**: Fill out the structured PR template detailing what changes were made, what hardware was tested, and confirmation of passing checks.
