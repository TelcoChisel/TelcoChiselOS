# TelcoSec TelcoChisel Base Container

[![Docker Pulls](https://img.shields.io/docker/pulls/telcosec/telcochisel-base.svg)](https://hub.docker.com/r/telcosec/telcochisel-base)
[![Docker Image Size](https://img.shields.io/docker/image-size/telcosec/telcochisel-base/latest)](https://hub.docker.com/r/telcosec/telcochisel-base)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0)
[![Website: telcochisel.com](https://img.shields.io/badge/Website-telcochisel.com-00ffd5.svg)](https://telcochisel.com)
[![Academy: app.telcosec.net](https://img.shields.io/badge/Academy-app.telcosec.net-e8921e.svg)](https://app.telcosec.net)

Official headless CLI container image for **TelcoChisel OS** (`v2026.2`), the premier telecom security penetration testing and research distribution developed by **TelcoSec** ([telco-sec.com](https://telco-sec.com) • [telcochisel.com](https://telcochisel.com)).

Built on **Ubuntu 24.04 LTS (Noble Numbat)**, stripped of desktop/manpage bloat, and enrolled in the official [TelcoSec Metapackage Archive](https://meta.telcochisel.com).

---

## 🛠 Included Telecom Tools

- **Core Protocol Analysis & Scanning:** `nmap`, `tshark`, `wireshark-common`, `scapy`, `sctpscan`, `sdr-info`, `telcosec-ran-status`
- **VoIP & Signaling Assessment:** `sipvicious`, `sipsak`, `sipp` (with PCAP & SCTP enabled), `rtpbleed`, `voiphopper`, `SigPloit`, `Diafuzzer`
- **Wireline & High-Rate Packet Generation:** `mausezahn` (`mz`), `asleap`, `docsis`, `snmp-check`, `rdnsx`
- **Cellular & SIM Investigation:** `pySim-shell`, `pySim-prog`, `pySim-read`, `lpac` (eSIM LPA), `SIMtrace2` host tools, `SIMurai`, `SIMTester`
- **Baseband Diagnostics:** `FirmWire` (emulation framework), `QCSuper` (Qualcomm Diag), `MTKClient` (MediaTek), `SCAT`
- **Radio Access Network (RAN) Simulation & Sniffing:** `UERANSIM` (`nr-gnb`, `nr-ue`, `nr-cli`), `LTESniffer`, `kalibrate-gsm`
- **Network & Perimeter Defense:** `RouterSploit`, `wireguard`, `freeradius-utils`, `vlan`, `macchanger`
- **Operator Tooling:** `telcosec` CLI, `telcosec-pkg` modular metapackage client, `telcosec-academy` lab bridge
- **Wordlists:** Curated TelcoSec telecom wordlists (APN lists, operator IMSI ranges, permutation scripts) in `/usr/share/wordlists/telecom`

---

## 🚀 Quick Start

Run an interactive shell:
```bash
docker run --rm -it telcosec/telcochisel-base:latest
```

Execute a scan or tool directly:
```bash
# Inspect SIM cards with pySim
docker run --rm -it --device /dev/bus/usb telcosec/telcochisel-base:latest pySim-shell

# Run SCTP scanner
docker run --rm -it telcosec/telcochisel-base:latest sctpscan -h

# Run 5G UE simulation
docker run --rm -it telcosec/telcochisel-base:latest nr-ue --help
```

---

## 🎓 Master Telecom Security at TelcoSec Academy

Accelerate your expertise in telecommunications cybersecurity and vulnerability research with official hands-on labs and certifications:
- **Interactive Live Labs:** Signaling attacks (SS7, Diameter, GTP-C), 5G Standalone core penetration testing, and baseband firmware reverse engineering.
- **Real-World Scenarios:** From rogue base stations (IMSI catchers) to eBPF-accelerated 5G UPF auditing.
- 👉 **Access Live Labs & Training:** [app.telcosec.net](https://app.telcosec.net)

---

## 🔒 Security Notice & Legal Disclaimer

TelcoChisel and TelcoSec tools are designed strictly for authorized telecommunications penetration testing, educational research, network defense audits, and vulnerability verification. Unauthorized interception of telecommunication signals or unauthorized testing of public carrier networks without explicit consent is illegal.

---

## 🌐 Resources & Documentation

- **TelcoSec Academy (Live Labs):** [app.telcosec.net](https://app.telcosec.net)
- **Official Website:** [telcosec.net](https://telcosec.net)
- **Documentation & Research:** [telcosec.net/docs](https://telcosec.net)
- **GitHub Repository:** [TelcoChisel/TelcoChiselOS](https://github.com/TelcoChisel/TelcoChiselOS)
- **Official Metapackages:** [meta.telcochisel.com](https://meta.telcochisel.com)
