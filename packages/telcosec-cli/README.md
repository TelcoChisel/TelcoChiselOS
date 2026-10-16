# TelcoSec Operator CLI (`telcosec`)

[![License: Apache-2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Go Report Card](https://goreportcard.com/badge/github.com/TelcoChisel/telcosec-cli)](https://goreportcard.com/report/github.com/TelcoChisel/telcosec-cli)
[![Platform: Linux](https://img.shields.io/badge/Platform-Linux%20(x86__64%20%7C%20arm64)-informational.svg)](https://telcochisel.com)

The official standalone operator CLI and telemetry suite for telecom security engineers, cellular penetration testers, and SDR researchers. 

`telcosec` is designed to run natively on **TelcoChiselOS** or any Debian/Ubuntu-derived Linux distribution (Ubuntu 24.04/22.04, Debian 12, Kali Linux, DragonOS).

---

## Key Capabilities

- **Zero-Dependency Architecture**: Statically compiled binary requiring no external runtime dependencies; directly reads Linux kernel subsystems (`/proc`, `/sys`, PAM limits).
- **SDR & Radio Hardware Diagnostics**: Automated discovery and health audits for Ettus USRP (UHD), Great Scott Gadgets HackRF, Nuand BladeRF, LimeSDR, RTL-SDR, and ADALM-PLUTO.
- **10GbE Network Transceiver Optimization**: One-click Jumbo Frame configuration (MTU 9000), 4096 RX/TX ring buffer descriptors, and 64 MB socket buffers for high-bandwidth SDRs (USRP X310, N310).
- **5G Standalone Lifecycle Management**: Controls Open5GS core network services and provisions subscriber credentials (`IMSI`, `K`, `OPc`) via `open5gs-dbctl`.
- **11-Tier Modular Metapackage Management**: Seamless interface to inspect, install, and audit modular telecom suites (`telcosec pkg list`, `telcosec pkg info 5g`, `sudo telcosec pkg install sdr sim`).
- **Smartcard, SIM & eSIM Auditing**: Pure Go ISO/IEC 7816-3 Answer-to-Reset (ATR) decoding, PC/SC reader monitoring, Osmocom SIMtrace 2 sniffer control, and eSIM Local Profile Assistant (`lpac`) integration (`telcosec sim`).
- **Tool Catalog Keyword Search**: Instantly searches installed desktop tools and applications by protocol keyword (`sctp`, `diameter`, `ss7`, `nas`, `ran`).
- **Operational Profile Switching**: Toggles between Lab Mode (`rp_filter=0`, unrestricted packet crafting) and Field Mode (hardened reverse path filtering).

---

## Installation & Compilation

### Requirements
- Linux kernel 5.15+ (low-latency or PREEMPT_RT recommended for high-MSPS SDRs)
- Go 1.22+ (for building from source)

### Official APT Repository Installation (Ubuntu 24.04 / 22.04 & Debian 12)

Install `telcosec-cli` via the official Cloudflare Pages-backed APT edge repository (`meta.telcosec.net`):

```bash
# 1. Install TelcoSec APT keyring
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://meta.telcosec.net/public.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/telcosec.gpg

# 2. Add TelcoChisel repository source
echo "deb [signed-by=/etc/apt/keyrings/telcosec.gpg] https://meta.telcosec.net noble main" | sudo tee /etc/apt/sources.list.d/telcosec.list

# 3. Update package index and install telcosec-cli
sudo apt-get update && sudo apt-get install -y telcosec-cli
```

### macOS & Linux (Homebrew)

Install `telcosec` on macOS (Apple Silicon & Intel) or Linux via the official [TelcoChisel Homebrew tap](https://github.com/TelcoChisel/homebrew-tap):

```bash
# Tap the official TelcoChisel repository
brew tap telcochisel/tap

# Install telcosec (includes shell completions & man pages)
brew install telcosec

# Or install directly in a single command:
brew install telcochisel/tap/telcosec

# To compile bleeding-edge from trunk:
brew install --HEAD telcochisel/tap/telcosec
```

### Docker & Container Image (Multi-Architecture)

Official multi-architecture container images (`linux/amd64` and `linux/arm64`) are automatically published to the GitHub Container Registry:

```bash
# Pull and run directly
docker run --rm -it ghcr.io/telcochisel/telcosec-cli version

# Comprehensive telecom environment audit
docker run --rm -it ghcr.io/telcochisel/telcosec-cli check

# Decode SIM smartcard ATR
docker run --rm -it ghcr.io/telcochisel/telcosec-cli sim atr 3B9F95801FC78031E073FE211B674A4C7380110043

# Host hardware diagnostics (with direct USB SDR and smartcard passthrough)
docker run --rm -it --privileged --net=host -v /dev:/dev -v /sys:/sys ghcr.io/telcochisel/telcosec-cli hardware
```

### Manual Debian Package Installation (.deb)

Pre-built multi-architecture `.deb` packages (`amd64` and `arm64`) are available on the [GitHub Releases](https://github.com/TelcoChisel/telcosec-cli/releases) page:

```bash
# Install via dpkg
sudo dpkg -i telcosec-cli_2026.2-1_amd64.deb
```

### Building Debian Package (.deb)
```bash
# Build native Debian package (.deb)
make deb

# Or using dpkg-buildpackage directly
dpkg-buildpackage -us -uc -b
```

### Building from Source
```bash
git clone https://github.com/TelcoChisel/telcosec-cli.git
cd telcosec-cli
make build
sudo make install
```

---

## Command Reference

| Command | Subcommands / Flags | Description |
| :--- | :--- | :--- |
| `telcosec check` | `status` | Comprehensive audit of kernel architecture, PAM realtime limits, hugepages, USBFS buffers, and core services. |
| `telcosec hardware` | `hw`, `devices` | Enumerate and probe connected SDR transceivers, serial AT modems, and PC/SC smartcard readers. |
| `telcosec sdr` | `status`, `usb`, `10g`, `firmware` | SDR driver stack check, USB buffer tuning, 10GbE optimization, and FPGA bitstream inspection. |
| `telcosec 10g` | `status`, `tune <iface>`, `setup <iface> [preset]`, `probe [ip]` | 10Gbps SFP+ interface optimization for Ettus USRP X310/N310 transceivers. |
| `telcosec firmware` | | Inspect local offline FPGA bitstream caches for BladeRF (`.rbf`) and USRP (`.bin`). |
| `telcosec profile` | `lab`, `field`, `status` | Switch operational profiles (Lab Mode vs Field Mode). |
| `telcosec pkg` | `list [--json]`, `info <alias>`, `install <alias>`, `remove <alias>`, `check`, `repo [status\|enable]` | Official 10-tier modular metapackage manager connecting to meta.telcosec.net. |
| `telcosec sim` | `status`, `readers`, `atr [hex]`, `trace [list\|sniff]`, `lpac`, `shell` | Smartcard, SIM & eSIM auditing suite (PC/SC, ISO 7816-3 ATR decoder, SIMtrace 2, lpac). |
| `telcosec 5g-sa` | `start`, `stop`, `status`, `add-sub` | Manage local Open5GS 5G Standalone core network and provision test SIMs. |
| `telcosec scan` | `sctp`, `sip`, `asleap` | Launch telecom signaling assessment wizards and scanners. |
| `telcosec search` | `<query>` | Search the 100 installed telecom tools and desktop entries by keyword. |
| `telcosec docs` | | Open local offline documentation (`/usr/share/doc/telcosec/index.html`) or online docs portal. |
| `telcosec academy`| | Launch TelcoSec Academy interactive field labs bridge (`app.telcosec.net`). |
| `telcosec feedback`| `review` | Open SourceForge user reviews and community support channels. |
| `telcosec completion` | `bash`, `zsh`, `fish` | Output shell autocompletion script. |
| `telcosec version` | `-v`, `--version` | Display version, build commit, and kernel environment. |

---

## Shell Autocompletion

`telcosec` provides built-in autocompletion for **Bash**, **Zsh**, and **Fish**:

```bash
# Bash (current session)
source <(telcosec completion bash)

# Bash (permanent install)
telcosec completion bash | sudo tee /etc/bash_completion.d/telcosec > /dev/null

# Zsh (current session)
source <(telcosec completion zsh)

# Zsh (permanent install)
telcosec completion zsh > ~/.zsh/completion/_telcosec

# Fish (permanent install)
telcosec completion fish > ~/.config/fish/completions/telcosec.fish
```

---

## Manual Page

A comprehensive Section 1 manual page is provided:

```bash
# View local manpage
man telcosec
man telcochisel

# Read direct file
man ./docs/man/telcosec.1
```

---

## Package Structure

```text
telcosec-cli/
├── cmd/
│   └── telcosec/                     # CLI entrypoint and subcommand routing
│       └── main.go
├── pkg/
│   ├── cellular/                     # Open5GS 5G SA core lifecycle & subscriber provisioning
│   ├── docs/                         # Interactive offline/online documentation launcher
│   ├── network/                      # 10GbE MTU 9000, ring buffer & socket buffer tuning
│   ├── sdr/                          # USB & Network SDR discovery, FPGA bitstream management
│   ├── search/                       # Desktop launcher catalog parser and keyword search
│   └── telemetry/                    # Kernel latency, PAM limits, USBFS memory, hugepages
├── completions/                      # Embedded shell autocompletions (Bash, Zsh, Fish)
│   ├── telcosec.bash
│   ├── _telcosec
│   ├── telcosec.fish
│   └── completions.go
├── docs/
│   └── man/                          # Section 1 UNIX manual pages
│       └── telcosec.1
├── Makefile
├── LICENSE
└── README.md
```

---

## License

`telcosec-cli` is licensed under the [Apache License, Version 2.0](LICENSE).
