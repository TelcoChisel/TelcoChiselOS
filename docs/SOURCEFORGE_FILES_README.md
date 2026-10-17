# TelcoChisel Live Linux OS

**Official SourceForge File Release Repository**  
*Advanced 5G/4G Cellular Security & Telecom Auditing Live Operating System by TelcoSec*

[![Download TelcoChisel](https://img.shields.io/sourceforge/dt/telcochisel?logo=sourceforge&label=Downloads&color=00ffd5)](https://sourceforge.net/projects/telcochisel/files/latest/download)
[![SourceForge Reviews](https://img.shields.io/sourceforge/reviews/telcochisel?logo=sourceforge&label=User%20Reviews&color=f59e0b)](https://sourceforge.net/projects/telcochisel/reviews/new)
[![DistroWatch](https://img.shields.io/badge/DistroWatch-Specification_Ready-00ffd5?logo=linux&logoColor=black)](https://github.com/TelcoSec-Tools/TelcoChiselOS/blob/main/DISTROWATCH.md)
[![News Feed](https://img.shields.io/badge/News_Feed-RSS_2.0-ff6600?logo=rss&logoColor=white)](https://telcochisel.com/feed.xml)
[![GitHub Stars](https://img.shields.io/github/stars/TelcoSec-Tools/TelcoChiselOS?logo=github&label=GitHub%20Stars&color=6366f1)](https://github.com/TelcoSec-Tools/TelcoChiselOS)

---

### Latest Release: TelcoChisel OS 2026.2 (Noble Numbat)

TelcoChisel is distributed in two official editions tailored for offensive security researchers, telecom operators, and radio engineers:

| Edition | Primary ISO File | Approx Size | Target Profile | Key Capabilities |
| :--- | :--- | :--- | :--- | :--- |
| **Flagship Field Edition (Full)** | `TelcoChisel-2026.2-amd64.iso`<br>*(symlinked as `TelcoChisel-live.iso`)* | **~5.5 GB** | Field auditing, air-gapped cellular testing, complete radio labs | All 100 telecom security tools pre-installed across 11 categories; UHD FPGA images, GNU Radio 3.10, Open5GS, srsRAN, O-RAN E2/O1, 5G SBI fuzzers, FirmWire, 5Ghoul, PySIM, Wireshark dissectors offline ready. |
| **Modular Lite Edition (Lite)** | `TelcoChisel-2026.2-lite-amd64.iso` | **~1.8 GB** | Lightweight deployments, VMs, custom tailored toolsets | Clean base XFCE desktop, 1000Hz Low-Latency kernel, Wireshark, Python runtime + `telcosec-pkg` CLI to pull modular domain metapackages on-demand. |

- **Base Distribution:** Ubuntu 24.04 LTS (*Noble Numbat*)
- **Kernel Architecture:** Linux Real-Time Low-Latency (`linux-image-lowlatency`, 1000Hz timer, preemptible)
- **Desktop Environment:** XFCE4 + i3 Tiling Window Manager (LightDM, GPU-accelerated, custom cyberpunk telecom icon suite)
- **Default Credentials:**
  - **Username:** `telcosec`
  - **Password:** `telcosec`
  - *(Graphical auto-login is active by default in Live Mode)*

---

### Hardware Compatibility & Driver Matrix

All device drivers are built from source and pre-configured with complete udev rules (`/etc/udev/rules.d/`) to grant unprivileged `telcosec` user access:

| Hardware Category | Supported Models / Chipsets | Driver & Runtime Stack | Use Cases |
| :--- | :--- | :--- | :--- |
| **Software-Defined Radio (SDR)** | Ettus Research USRP B200, B210, N210, X310 | UHD 4.6.0 + FPGA images (`/usr/share/uhd/images/`) | 5G NR / 4G LTE gNodeB/eNodeB simulation, wideband spectrum recording |
| **Sub-GHz & Portable SDR** | Great Scott Gadgets HackRF One, Rad1o | `libhackrf` 2024.02.1 + `hackrf-tools` | GSM/LTE downlink sniffing, IMSI-catcher discovery, replay testing |
| **MIMO Transceiver SDR** | Nuand BladeRF 2.0 micro (xA4, xA9) | `libbladeRF` 2.5.0 + FPGA auto-loader | Full-duplex cellular base stations, 5Ghoul over-the-air fuzzing |
| **Broadband SDR** | Lime Microsystems LimeSDR USB, LimeSDR Mini | `LimeSuite` 23.11.0 + SoapySDR bindings | Cellular carrier frequency surveying, multi-carrier monitoring |
| **Low-Cost Receiver** | RTL-SDR v3 / v4 (R820T2, R828D) | `librtlsdr` with direct sampling patches | Broadcast FM, ADS-B, GSM 900/1800 control channel monitoring |
| **Smart Card & SIM Audit** | Sysmocom SIMtrace 2, Osmocom SIMtrace | `simtrace2-remsim` + SPI/ISO-7816 firmware | Intercepting APDUs between mobile handset and physical SIM card |
| **PCSC Smart Card Readers** | Omnikey 3021/3121, Identiv uTrust 2700R, ACR38U | `pcscd`, `pcsc-tools`, `pysim-shell` | SIM/USIM/ISIM parameter extraction, Ki/OPc programming, eSIM LPA |
| **Cellular Basebands & Modems** | Qualcomm Snapdragon, MediaTek Helio/Dimensity, Shannon | `edl`, `qcsuper`, `mtkclient`, `firmwire` | Baseband firmware reverse engineering, DIAG trace logging, crash fuzzing |

---

### System Requirements

- **Processor:** 64-bit x86_64 CPU with Intel SSE4.2 / AVX2 instructions (AVX2 recommended for 5G NR LDPC acceleration).
- **Memory (RAM):**
  - *Lite Edition:* 4 GB minimum (8 GB recommended).
  - *Full Field Edition:* 8 GB minimum (16 GB recommended for concurrent 5G SA Core + srsRAN gNB).
- **Bootable Storage:** USB 3.0 / USB 3.1 Flash Drive or Portable SSD with at least 16 GB (Lite) or 32 GB (Full).
- **Firmware:** UEFI (with Secure Boot disabled) or Legacy BIOS.

---

### First 60 Seconds: Field Operator Cheatsheet

Once booted into the live environment, open the terminal (`Ctrl+Alt+T`) and run these integrated commands:

```bash
# 1. Inspect attached SDRs, kernel modules, and SCTP tuning
telcosec check

# 2. Test connected SDR transceiver (e.g. USRP B210 or HackRF)
telcosec sdr

# 3. Spin up full local 5G Standalone core network (Open5GS)
sudo telcosec 5g-sa start

# 4. Search and verify tool catalog (100 tools)
telcosec search gsm

# 5. Launch offline documentation and lab scenarios in browser
telcosec docs
```

---

### SHA-256 Checksum Verification

Always verify the integrity of your downloaded ISO before writing to USB:

```bash
# Linux / macOS
sha256sum -c TelcoChisel-live.iso.sha256

# Or manual verification:
sha256sum TelcoChisel-live.iso
```

```powershell
# Windows PowerShell
Get-FileHash .\TelcoChisel-live.iso -Algorithm SHA256
```

---

### Creating Bootable Live Media

#### Option A: Using `dd` (Linux / macOS)
```bash
# Identify your target USB drive (e.g., /dev/sdX)
lsblk

# Write ISO directly to block device (NOT a partition like /dev/sdX1)
sudo dd if=TelcoChisel-live.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

#### Option B: Using GUI Flashers (Windows / Linux / macOS)
1. **BalenaEtcher:** Select `TelcoChisel-live.iso`, choose target USB drive, click **Flash!**.
2. **Rufus (Windows):** Select USB device, browse to `TelcoChisel-live.iso`, partition scheme `MBR` or `GPT`, write mode **DD Image Mode** (recommended).

#### Option C: Native LUKS-Encrypted Persistence
Boot into TelcoChisel Live Mode and run our dedicated USB creator:
```bash
sudo telcosec-create-usb /dev/sdX
```
This partitions the drive, deploys the ISO, and creates an AES-XTS LUKS-encrypted `casper-rw` partition for secure field persistence.

---

### Joining Split Files (If downloaded in parts)
If you downloaded the split release parts (`.part-aa`, `.part-ab`, `.part-ac`):

```bash
# Linux / macOS
cat TelcoChisel-live.iso.part-* > TelcoChisel-live.iso

# Windows Command Prompt (CMD)
copy /b TelcoChisel-live.iso.part-aa + TelcoChisel-live.iso.part-ab + TelcoChisel-live.iso.part-ac TelcoChisel-live.iso
```

---

### ⭐ Rate & Review TelcoChisel on SourceForge

If TelcoChisel assisted your telecom research, SDR engagement, or security audits, please take 30 seconds to rate us on SourceForge:

👉 **[Leave a 5-Star Review on SourceForge](https://sourceforge.net/projects/telcochisel/reviews/new)**

Your feedback directly supports continuous maintenance, driver updates, and helps other telecom engineers discover open-source wireless security tools.

---

### Quick Links & Official Portals
- **Documentation & Interactive Reference:** [telcochisel.com](https://telcochisel.com)
- **TelcoSec Academy (Interactive Field Labs):** [app.telcosec.net](https://app.telcosec.net)
- **Community Forum & Q&A:** [community.telcosec.net](https://community.telcosec.net)
- **Official GitHub Repository:** [github.com/TelcoSec-Tools/TelcoChiselOS](https://github.com/TelcoSec-Tools/TelcoChiselOS)
- **Discord Community:** [discord.gg/RykzXTQFXF](https://discord.gg/RykzXTQFXF)
- **Substack Engineering Journal:** [telcosec.substack.com](https://telcosec.substack.com)
