# TelcoChisel Live Linux OS

**Official SourceForge File Release Repository**  
*Advanced 5G/4G Cellular Security & Telecom Auditing Live Operating System by TelcoSec*

[![Download TelcoChisel](https://img.shields.io/sourceforge/dt/telcochisel?logo=sourceforge&label=Downloads&color=00ffd5)](https://sourceforge.net/projects/telcochisel/files/latest/download)
[![SourceForge Reviews](https://img.shields.io/sourceforge/reviews/telcochisel?logo=sourceforge&label=User%20Reviews&color=f59e0b)](https://sourceforge.net/projects/telcochisel/reviews/new)
[![DistroWatch](https://img.shields.io/badge/DistroWatch-Specification_Ready-00ffd5?logo=linux&logoColor=black)](https://github.com/TelcoChisel/TelcoChiselOS/blob/main/DISTROWATCH.md)
[![News Feed](https://img.shields.io/badge/News_Feed-RSS_2.0-ff6600?logo=rss&logoColor=white)](https://telcochisel.com/feed.xml)
[![GitHub Stars](https://img.shields.io/github/stars/TelcoChisel/TelcoChiselOS?logo=github&label=GitHub%20Stars&color=6366f1)](https://github.com/TelcoChisel/TelcoChiselOS)

> **One-click download:** [**sourceforge.net/projects/telcochisel/files/latest/download**](https://sourceforge.net/projects/telcochisel/files/latest/download) — always serves the current stable ISO.
> **Latest stable:** `@VERSION@` · **ISO size:** @SIZE@ · **Built:** @DATE@

---

### Editions

TelcoChisel ships in two official editions for offensive security researchers, telecom operators, and radio engineers. Each release folder (`vX.Y.Z/`) contains a single, ready-to-write ISO — no reassembly needed.

| Edition | ISO File (in the newest `vX.Y.Z/` folder) | Target Profile | Key Capabilities |
| :--- | :--- | :--- | :--- |
| **Flagship Field Edition (Full)** | `TelcoChisel-<version>-amd64.iso` | Field auditing, air-gapped cellular testing, complete radio labs | All 100 telecom security tools across 10 domains; GNU Radio SDR stack, Open5GS, srsRAN, O-RAN E2/O1, 5G SBI fuzzers, FirmWire, 5Ghoul, pySim, Wireshark dissectors. Heavy RAN tools build on first run via `sudo <tool>-install`. |
| **Modular Lite Edition (Lite)** | `TelcoChisel-<version>-lite-amd64.iso` | Lightweight deployments, VMs, custom toolsets | Clean base XFCE desktop, low-latency kernel, Wireshark, Python runtime + `telcosec-pkg` CLI to pull modular domain metapackages on demand. |

- **Base Distribution:** Ubuntu 24.04 LTS (*Noble Numbat*)
- **Kernel:** Linux low-latency (`linux-image-lowlatency`, 1000 Hz, preemptible)
- **Desktop:** XFCE4 + i3 (LightDM; Ubuntu Mono / Fira Code terminal fonts)
- **Default live credentials:** `telcosec` / `telcosec` (graphical auto-login in Live Mode)

---

### Hardware Compatibility & Driver Matrix

Device drivers are pre-configured with udev rules (`/etc/udev/rules.d/`) granting the unprivileged `telcosec` user access:

| Hardware Category | Supported Models / Chipsets | Driver & Runtime Stack | Use Cases |
| :--- | :--- | :--- | :--- |
| **Software-Defined Radio (SDR)** | Ettus Research USRP B200, B210, N210, X310 | UHD + FPGA images (fetched on first use via `uhd-download-images`) | 5G NR / 4G LTE gNodeB/eNodeB simulation, wideband spectrum recording |
| **Sub-GHz & Portable SDR** | Great Scott Gadgets HackRF One, Rad1o | `libhackrf` + `hackrf-tools` | GSM/LTE downlink sniffing, IMSI-catcher discovery, replay testing |
| **MIMO Transceiver SDR** | Nuand BladeRF 2.0 micro (xA4, xA9) | `libbladeRF` + FPGA auto-loader | Full-duplex cellular base stations, 5Ghoul over-the-air fuzzing |
| **Broadband SDR** | Lime Microsystems LimeSDR USB, LimeSDR Mini | `LimeSuite` + SoapySDR bindings | Cellular carrier frequency surveying, multi-carrier monitoring |
| **Low-Cost Receiver** | RTL-SDR v3 / v4 (R820T2, R828D) | `librtlsdr` with direct-sampling patches | Broadcast FM, ADS-B, GSM 900/1800 control-channel monitoring |
| **Smart Card & SIM Audit** | Sysmocom SIMtrace 2, Osmocom SIMtrace | `simtrace2-remsim` + SPI/ISO-7816 firmware | Intercepting APDUs between handset and physical SIM |
| **PCSC Smart Card Readers** | Omnikey 3021/3121, Identiv uTrust 2700R, ACR38U | `pcscd`, `pcsc-tools`, `pySim-shell` | SIM/USIM/ISIM extraction, Ki/OPc programming, eSIM LPA |
| **Cellular Basebands & Modems** | Qualcomm Snapdragon, MediaTek Helio/Dimensity, Shannon | `edl`, `qcsuper`, `mtkclient`, `firmwire` | Baseband firmware reverse engineering, DIAG trace logging, crash fuzzing |

---

### System Requirements

- **Processor:** 64-bit x86_64 with SSE4.2 / AVX2 (AVX2 recommended for 5G NR LDPC acceleration).
- **Memory:** Lite — 4 GB min (8 GB recommended). Full — 8 GB min (16 GB recommended for concurrent 5G SA Core + srsRAN gNB).
- **Bootable storage:** USB 3.x flash drive or portable SSD, 16 GB (Lite) or 32 GB (Full).
- **Firmware:** UEFI (Secure Boot disabled) or Legacy BIOS.

---

### First 60 Seconds: Field Operator Cheatsheet

Boot into the live environment, open a terminal (`Ctrl+Alt+T`) and run:

```bash
telcosec check              # inspect attached SDRs, kernel modules, SCTP tuning
telcosec sdr                # test connected SDR transceiver (USRP B210, HackRF, ...)
sudo telcosec 5g-sa start   # spin up a local 5G Standalone core (Open5GS)
telcosec search gsm         # search and verify the 100-tool catalog
telcosec docs               # open offline documentation and lab scenarios
```

---

### Verify Your Download

Each `vX.Y.Z/` folder ships the ISO plus `.sha256` and `.md5`. Verify before writing to USB (replace `<iso>` with the downloaded filename):

```bash
# Linux / macOS
sha256sum -c <iso>.sha256

# Windows PowerShell
Get-FileHash .\<iso> -Algorithm SHA256
```

---

### Create Bootable Live Media

**Option A — `dd` (Linux / macOS):**
```bash
lsblk                                   # identify the target USB (e.g. /dev/sdX)
sudo dd if=<iso> of=/dev/sdX bs=4M status=progress conv=fsync
```

**Option B — GUI flashers:**
- **BalenaEtcher** (any OS): select the ISO, choose the USB, click **Flash!**
- **Rufus** (Windows): select the USB, browse to the ISO, write mode **DD Image**.

**Option C — LUKS-encrypted persistence:** boot Live Mode, then:
```bash
sudo telcosec-create-usb /dev/sdX
```
Partitions the drive, deploys the ISO, and creates an AES-XTS LUKS-encrypted `casper-rw` persistence partition.

---

### ⭐ Rate & Review on SourceForge

If TelcoChisel helped your telecom research, SDR work, or security audits, please take 30 seconds to rate it:

👉 **[Leave a review on SourceForge](https://sourceforge.net/projects/telcochisel/reviews/new)**

Your feedback supports continued maintenance and helps other engineers discover open-source wireless security tooling.

---

### Quick Links

- **Documentation & reference:** [telcochisel.com](https://telcochisel.com)
- **TelcoSec Academy (field labs):** [app.telcosec.net](https://app.telcosec.net)
- **Community forum & Q&A:** [community.telcosec.net](https://community.telcosec.net)
- **GitHub repository:** [github.com/TelcoChisel/TelcoChiselOS](https://github.com/TelcoChisel/TelcoChiselOS)
- **Discord:** [discord.gg/RykzXTQFXF](https://discord.gg/RykzXTQFXF)
- **Engineering journal:** [telcosec.substack.com](https://telcosec.substack.com)

<!-- @VERSION@, @SIZE@, @DATE@ are substituted by release.yml at publish time. -->
