# TelcoSec TelcoChisel SDR Container

[![Docker Pulls](https://img.shields.io/docker/pulls/telcosec/telcochisel-sdr.svg)](https://hub.docker.com/r/telcosec/telcochisel-sdr)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0)
[![Website: telcochisel.com](https://img.shields.io/badge/Website-telcochisel.com-00ffd5.svg)](https://telcochisel.com)
[![Academy: app.telcosec.net](https://img.shields.io/badge/Academy-app.telcosec.net-e8921e.svg)](https://app.telcosec.net)

Official Software Defined Radio (SDR) research container image for **TelcoChisel OS** (`v2026.2`), developed by **TelcoSec** ([telco-sec.com](https://telco-sec.com) • [telcochisel.com](https://telcochisel.com)).

Extends `telcochisel-base` with drivers, hardware support libraries, and research software for Software Defined Radios across 2G, 3G, 4G LTE, and 5G NR frequency bands.

---

## 📻 Hardware & SDR Ecosystem

- **SDR Frameworks & Utilities:** `SoapySDR` (`SoapySDRUtil`), `UHD` (`uhd_usrp_probe`), `LimeSuite` (`LimeUtil`), `HackRF` (`hackrf_info`), `BladeRF` (`bladeRF-cli`), `rtl-sdr`
- **Signal Processing & Demodulation:** `GNU Radio`, `GQRX`, `gr-gsm`, `kalibrate-rtl`
- **Isolated Conda Environment:** Pre-configured `telcosec-sdr` conda environment in `/opt/telcosec/miniconda/envs/telcosec-sdr` with all tool binaries directly exported on `PATH`.
- **Automated Bitstream & Firmware Downloaders:**
  - `bladerf-download-images` (Hosted FPGA bitstreams `hostedxA4`, `hostedxA9`, `hostedx40`, `hostedx115` & FX3 firmware)
  - `uhd-download-images` (USRP FPGA images)

---

## 🚀 Quick Start

Run with USB passthrough to access attached SDR hardware:
```bash
docker run --rm -it --device /dev/bus/usb telcosec/telcochisel-sdr:latest
```

Query connected SDR devices:
```bash
# Probe all SoapySDR supported devices
docker run --rm -it --device /dev/bus/usb telcosec/telcochisel-sdr:latest SoapySDRUtil --find

# HackRF probe
docker run --rm -it --device /dev/bus/usb telcosec/telcochisel-sdr:latest hackrf_info

# USRP probe
docker run --rm -it --device /dev/bus/usb telcosec/telcochisel-sdr:latest uhd_usrp_probe
```

Run GUI tools (GQRX) with X11 forwarding on Linux:
```bash
docker run --rm -it \
  --device /dev/bus/usb \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  telcosec/telcochisel-sdr:latest gqrx
```

---

## 🎓 Master Telecom Security at TelcoSec Academy

Accelerate your expertise in SDR radio engineering, signal analysis, and cellular interception:
- **RF & SDR Security Labs:** HackRF, BladeRF, and USRP hands-on signal capture, GSM frame decoding, and LTE sniffer analysis.
- **Spectrum Defense:** Rogue base station detection and wireless physical-layer assessment.
- 👉 **Access Live Labs & Training:** [app.telcosec.net](https://app.telcosec.net)

---

## 🔒 Security Notice & Legal Disclaimer

Authorized telecom security research only. Transmitting over licensed cellular spectrum without proper regulatory licenses or Faraday isolation is strictly prohibited by law.

---

## 🌐 Resources & Documentation

- **TelcoSec Academy (Live Labs):** [app.telcosec.net](https://app.telcosec.net)
- **Official Website:** [telcosec.net](https://telcosec.net)
- **GitHub Repository:** [TelcoChisel/TelcoChiselOS](https://github.com/TelcoChisel/TelcoChiselOS)
