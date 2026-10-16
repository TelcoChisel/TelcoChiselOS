# DistroWatch Distribution Submission Specification: TelcoChisel OS

This document provides the complete, structured submission package for listing **TelcoChisel OS** on [DistroWatch.com](https://distrowatch.com) in accordance with the official DistroWatch submission guidelines.

---

## 1. General Distribution Information

| Field | Submission Value |
| :--- | :--- |
| **Distribution Name** | **TelcoChisel OS** |
| **Distribution Type** | Linux |
| **Based On** | Ubuntu 24.04 LTS (*Noble Numbat*) |
| **Origin** | International |
| **Architecture** | x86_64 (64-bit AMD/Intel) |
| **Desktop Environments** | XFCE 4.18, i3 4.23 (*RFS Style Tiling Window Manager*) |
| **Category** | Security, Telecommunications, Forensics, Live Medium, Data Rescue |
| **Status** | Active |
| **Release Model** | Fixed / Point Release (`2026.2`) with rolling security updates via APT |
| **Init System** | systemd |
| **Package Management** | `dpkg`, `apt`, `telcosec-pkg` |
| **Installation Method** | Calamares GUI Installer (Automated LUKS encryption, Btrfs subvolumes, UEFI/BIOS support) |
| **Default Login (Live)** | **Username:** `telcosec` / **Password:** `telcosec` *(Auto-login enabled in Live session)* |
| **Root Password (Live)** | `telcosec` *(Full sudo privileges)* |

---

## 2. Official Project URLs

| Resource | URL |
| :--- | :--- |
| **Official Homepage** | https://telcochisel.com |
| **Documentation Portal** | https://telcochisel.com |
| **Download Hub (SourceForge)** | https://sourceforge.net/projects/telcochisel/files/ |
| **Primary Repository** | https://github.com/TelcoChisel/TelcoChiselOS |
| **Issue / Bug Tracker** | https://github.com/TelcoChisel/TelcoChiselOS/issues |
| **RSS / Release Feed** | https://telcochisel.com/feed.xml |
| **Google News Sitemap** | https://telcochisel.com/sitemap-news.xml |

---

## 3. Distribution Description & Executive Summary

**TelcoChisel OS** is a specialized, security-hardened Linux distribution engineered specifically for **telecommunication security professionals, cellular red teams, radio frequency (RF) researchers, government defense auditors, and critical infrastructure pentesting teams**.

Built upon Ubuntu 24.04 LTS with an ultra-low-latency 1000Hz preemptible real-time Linux kernel, TelcoChisel OS bridges the gap between raw hardware Software-Defined Radios (SDR) and complex cellular signaling protocols. It ships with a curated, pre-compiled arsenal of **100 specialized telecom security tools** spanning 11 core operational domains:
1. **Radio Frequency & DSP**: GNU Radio 3.10, Gqrx, Inspectrum, URH, Gpredict, SoapySDR.
2. **2G / 3G / GSM Auditing**: Osmocom suite (OsmoBTS, OsmoNITB, OsmoBSC), OpenBTS, YateBTS, Kalibrate.
3. **4G / 5G RAN & Core**: Open5GS 2.7.2, UERANSIM, srsRAN, 5Ghoul Baseband Fuzzer, Free5GC testbeds.
4. **SIM & Smart Card Security**: pySim-shell, Osmocom SIMtrace 2, FirmWire, QCSuper APDU/DIAG loggers.
5. **Signaling & Core Network**: SigPloit (SS7/Diameter/GTP/SIP), DiaFuzzer, sctpscan, REST SBI APIs.
6. **Protocol Dissection**: Wireshark 4.2+ with GSMTAP, GSMTAPv3, and 3GPP 5G SBI OpenAPI YAML dissectors.
7. **O-RAN & Open Radio**: O-RAN Software Community E2/O1 protocol decoders and non-RT RIC auditors.
8. **Baseband Vulnerability Research**: Baseband firmware extraction tools, Shannon/Qualcomm loaders.
9. **Physical & Wireless Audit**: Proxmark3, NFC tools, Bluetooth Low Energy (BLE) cellular relay suites.
10. **Evidence Preservation**: Encrypted persistence, Toram zero-trace RAM mode, automated PCAP logging.
11. **Operator Diagnostics**: Unified `telcosec` CLI, real-time hardware doctor, and 10GbE network tuner.

---

## 4. Key Tracked Software Packages & Versions

DistroWatch tracks specific package versions across distributions. TelcoChisel OS `2026.2` ships with:

| DistroWatch Tracked Package | Upstream Name | Version in TelcoChisel OS 2026.2 |
| :--- | :--- | :--- |
| **Kernel** | `linux-image-lowlatency` | 6.8.0-lowlatency (1000Hz preemptible) |
| **Base System** | Ubuntu Linux | 24.04 LTS (*Noble Numbat*) |
| **X Server / Display** | `xorg-server` / `x11` | 21.1.11 |
| **Desktop 1** | `xfce4` | 4.18.1 |
| **Desktop 2** | `i3-wm` | 4.23 |
| **Compositor** | `picom` | 11.2 |
| **Installer** | `calamares` | 3.3.6 |
| **Display Manager** | `lightdm` | 1.30.0 |
| **C Library** | `glibc` | 2.39 |
| **Compiler Suite** | `gcc` / `g++` | 13.2.0 |
| **Python** | `python3` | 3.12.3 |
| **Go** | `golang` | 1.22.2 |
| **Network Manager** | `network-manager` | 1.46.0 |
| **Packet Analyzer** | `wireshark` | 4.2.4 (Pre-loaded with GSMTAP & 5G SBI OpenAPI schemas) |
| **SDR Framework** | `gnuradio` | 3.10.10 |
| **USRP Driver** | `uhd` | 4.6.0.0 (Pre-loaded FPGA images in `/usr/share/uhd/images/`) |
| **5G Core Network** | `open5gs` | 2.7.2 |
| **5G UE / gNB Simulator** | `ueransim` | 3.2.6 |
| **SCTP Kernel Stack** | `libsctp-dev` / `lksctp-tools` | 1.0.19 |

---

## 5. Live Media Boot Modes & Images

| Edition | ISO Image Filename | Size | Target Environment |
| :--- | :--- | :--- | :--- |
| **Flagship Field Edition** | `TelcoChisel-2026.2-amd64.iso` | ~5.5 GB | Full offline air-gapped field operations with all 100 tools, FPGA bitstreams, and offline documentation |
| **Modular Lite Edition** | `TelcoChisel-2026.2-lite-amd64.iso` | ~1.8 GB | Lightweight virtual machines and field laptops with on-demand `telcosec-pkg` modular suite fetching |

### Four High-Assurance Boot Modes in GRUB:
1. `TelcoChisel OS Live (Low-Latency Realtime — Default)`
2. `TelcoChisel OS Live (Encrypted Persistence)`
3. `TelcoChisel OS Live (RAM Mode — Zero Trace)`
4. `TelcoChisel OS Live (i3 Tiling Window Manager — RFS Style)`

---

## 6. Verification Checksums

```
SHA256 (TelcoChisel-2026.1-amd64.iso) = verified on SourceForge mirror
SHA256 (TelcoChisel-2026.1-lite-amd64.iso) = verified on SourceForge mirror
```

---

## 7. Submission Checklist Confirmation

- [x] Functional, dedicated website with comprehensive documentation ([telcochisel.com](https://telcochisel.com)).
- [x] Bootable ISO images downloadable without barriers from a global CDN ([SourceForge](https://sourceforge.net/projects/telcochisel/files/)).
- [x] Standardized package management (`APT` + `telcosec-pkg`).
- [x] Active development on public version control ([GitHub](https://github.com/TelcoChisel/TelcoChiselOS)).
- [x] Public issue tracker and security vulnerability disclosure policy ([SECURITY.md](https://github.com/TelcoChisel/TelcoChiselOS/blob/main/SECURITY.md)).
- [x] Open-source licensing compliance (GPL-3.0).
