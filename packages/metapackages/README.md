# TelcoChisel Modular Debian Metapackages

Canonical source: [TelcoChisel/telcochisel-metapackages](https://github.com/TelcoChisel/telcochisel-metapackages).

This directory is a build-time copy of the packaging definitions for the **10 Official TelcoChisel Debian Metapackages**.

These metapackages enable users and automated CI/CD environments to install specialized functional tiers on minimal Ubuntu 24.04 installations or manage modular updates via `telcosec-pkg`.

---

## Metapackage Hierarchy & Aliases

| Metapackage Name | Shorthand Alias | Category / Functional Domain | Core Included Instruments |
| :--- | :--- | :--- | :--- |
| **`telcochisel-base`** | `base` | Core OS Tuning & Utilities | Real-time PAM limits, SCTP stack, Wireshark, TShark, Scapy, nmap, `telcosec-cli` |
| **`telcochisel-hardware-sdr`** | `hardware` | SDR Drivers & udev Rules | UHD, HackRF, BladeRF, LimeSuite, RTL-SDR, SoapySDR, non-root udev rules |
| **`telcochisel-tools-sdr`** | `sdr` | Radio Frequency & DSP | GNU Radio 3.10, Gqrx, Inspectrum, URH, Gpredict, gr-gsm |
| **`telcochisel-tools-2g-3g`** | `2g-3g` / `gsm` | 2G/3G Cellular Auditing | Osmocom stack, OpenBTS, YateBTS, Kalibrate-GSM |
| **`telcochisel-tools-4g`** | `4g` / `lte` | 4G LTE RAN & EPC | srsRAN 4G, srsUE, LTESniffer, LTE-CellScanner, Open5GS EPC |
| **`telcochisel-tools-5g`** | `5g` / `nr` | 5G Standalone Core & RAN | Open5GS 5G SA Core, UERANSIM, my5G-RANTester, 5Ghoul fuzzer, mitmproxy (5G SBI) |
| **`telcochisel-tools-sim`** | `sim` / `smartcard` | SIM & Smart Card Security | pySim-shell, Osmocom SIMtrace 2, lpac eSIM, SIMurai, SIMtester, pcsc-tools, OpenSC |
| **`telcochisel-tools-pstn-adsl`** | `wireline` / `voip` | Wireline, VoIP & Broadband | mausezahn, yersinia, SIPp, sipsak, ettercap, DOCSIS tools |
| **`telcochisel-tools-ue`** | `ue` / `modem` | Mobile UE & Baseband | UERANSIM UE, SCAT, QCSuper, FirmWire baseband fuzzer, MTKClient, EDL 9008 |
| **`telcochisel-meta-full`** | `full` / `complete` | Complete Ecosystem Umbrella | Installs all 100 specialized telecom security instruments across all 11 domains |

---

## Building the Metapackages

To build all 10 `.deb` packages locally:

```bash
make build
# or
bash build-metapackages.sh
```

Binary packages and Debian repository metadata (`Packages.gz`, `Release`) will be output to `dist/`.

---

## Installing via `telcosec-pkg` CLI

On any TelcoChisel OS system:

```bash
# Install specific modular domain suites
sudo telcosec-pkg install 5g
sudo telcosec-pkg install sdr
sudo telcosec-pkg install sim

# Check installed metapackage status
telcosec-pkg status

# Install the complete ecosystem (all 100 tools)
sudo telcosec-pkg install full
```
