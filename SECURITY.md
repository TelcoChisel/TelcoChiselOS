# Security Policy

The **TelcoSec** team takes the security of TelcoChisel seriously. As a distribution designed for telecommunications security research, ethical hacking, and cellular penetration testing, maintaining distribution integrity and secure defaults is paramount.

---

## Supported Versions

Security patches and dependency updates are applied to the active major release:

| Release Version | Supported | Maintenance Status |
| :--- | :--- | :--- |
| **2026.x (Noble Numbat)** | :white_check_mark: **Yes** | Active development (`VERSION` = `YYYY.R`; tags `v2026.2`) |
| 3.0.x / 3.1.x (legacy semver tags) | :white_check_mark: **Yes** | Same Noble line; prefer date-based `2026.x` naming going forward |
| 1.1.x (Public Beta) | :x: No | End of Life (upgrade to 2026.x) |
| 1.0.x (Initial POC) | :x: No | End of Life |

---

## Reporting a Vulnerability

If you discover a security vulnerability within the TelcoChisel distribution, please report it privately rather than opening a public issue.

### Preferred Method: GitHub Private Security Advisory
1. Navigate to the [TelcoChisel Security Advisories](https://github.com/TelcoChisel/TelcoChiselOS/security/advisories) page.
2. Click **Report a vulnerability** to open a confidential advisory draft.
3. Provide a detailed summary, proof-of-concept steps, and affected components.

### Alternative Method: Direct Security Contact
If you cannot use GitHub Advisories, email the maintainers directly:
- **Email**: `security@telcosec.net`
- **PGP Key**: Available upon request or via keyserver.

Please include:
- A description of the vulnerability and its potential impact.
- Exact reproduction steps, script snippets, or terminal logs.
- The ISO version, kernel version (`uname -a`), and environment (Live USB, installed, VM).

---

## Response Timeline & SLA

- **Initial Acknowledgment**: Within **48 hours** of report receipt.
- **Triage & Impact Assessment**: Within **5 business days**.
- **Remediation & Patching**: Critical vulnerabilities will receive an expedited fix and point-release rebuild.
- **Coordinated Disclosure**: We adhere to a 90-day coordinated disclosure window.

---

## Scope & Responsible Disclosure Guidelines

### In Scope
- Vulnerabilities in the ISO build engine (`build-iso.sh`, `builder/scripts/`).
- Flaws in custom TelcoChisel binaries and scripts (`telcosec`, `telcosec-pkg`, `telcosec-create-usb`).
- Insecure default permissions outside of standard live-mode operation.
- Vulnerabilities in the Calamares installer integration or LUKS encryption implementation.
- Infrastructure security of our APT repositories (`meta.telcosec.net`) and portals.

### Out of Scope / Upstream Tools
- **Bundled Offensive Tools**: TelcoChisel deliberately ships security auditing tools (e.g., 5Ghoul, SigPloit, QCSuper, FirmWire, srsRAN, Open5GS) whose intended purpose is finding and demonstrating vulnerabilities in cellular protocols. Behavior that is part of a tool's normal offensive operation is not considered a TelcoChisel vulnerability.
- **Upstream Tool Bugs**: Bugs, crashes, or memory corruption inside third-party upstream tools should be reported directly to the upstream tool author's repository.
