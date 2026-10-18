# TelcoChisel Promotion Playbook

Paste-ready copy and a checklist for the manual (web-UI) promotion tasks that
can't be committed to the repo. Goal: more distro downloads + TelcoSec Academy
sign-ups. Keep this in sync when the pitch changes.

---

## 1. GitHub — Social preview image (Settings → General → Social preview)

Upload a 1280×640 PNG/JPG. `assets/repo_cover.png` (1376×768) works — GitHub
crops to center. This image is what renders when the repo is shared on
X/LinkedIn/Discord/Slack.

If you want a dedicated card, export one at exactly **1280×640** and upload it.

## 2. GitHub — Repo "About" (already set via API; verify)

- **Description:** `5G/4G telecom security Linux distro (Ubuntu-based) with 100+ SDR, baseband & RF penetration-testing tools — srsRAN, Open5GS, HackRF, USRP ready.`
- **Website:** `https://telcochisel.com`
- **Topics (20):** telecom-security, 5g, 5g-security, sdr, software-defined-radio, srsran, open5gs, hackrf, usrp, baseband, imsi-catcher, gsm, lte, penetration-testing, cybersecurity, ubuntu, live-usb, gnuradio, ueransim, telcosec

## 3. GitHub — Enable Discussions (Settings → Features → Discussions)

Turn it on. Seed with a pinned "Start here / Try the Academy" post:

> **Welcome to TelcoChisel** — a 5G/4G telecom-security live OS. New here?
> 1. Download the ISO: https://sourceforge.net/projects/telcochisel/files/latest/download
> 2. Boot it (`telcosec` / `telcosec`), run `telcosec check`.
> 3. Turn it into skills with guided labs → **https://app.telcosec.net**
> Questions? Ask in Discussions or join Discord: https://discord.gg/RykzXTQFXF

## 4. SourceForge — Project admin (sourceforge.net/projects/telcochisel/admin)

**Summary (one line):**
> TelcoChisel — a 5G/4G telecom-security Linux live OS (Ubuntu 24.04) with 100+ SDR, baseband, SIM and RAN pentest tools. Boots to a ready lab; pairs with the hands-on TelcoSec Academy.

**Categories / Trove:**
- Security
- Telecommunications
- Communications → Telephony
- Operating System → Linux Distributions
- Topic → System → Operating System

**Description (long) — lead paragraph:**
> TelcoChisel is an advanced live Linux distribution for telecommunications
> security research — 5G SA core & RAN testing, SDR/RF analysis, cellular
> baseband reverse engineering, and SIM/eSIM auditing. Based on Ubuntu 24.04
> LTS with 100+ pre-configured tools (srsRAN, Open5GS, UERANSIM, GNU Radio,
> HackRF/USRP/BladeRF drivers, FirmWire, 5Ghoul, pySim). Boot the ISO and go,
> or deepen your skills with guided labs and CTF testbeds at TelcoSec Academy
> (https://app.telcosec.net).

**Screenshots** (upload — big conversion driver; assets already in repo):
- `assets/sf-screenshot-1-desktop.png` — "Tactical XFCE desktop with live RF HUD"
- `assets/sf-screenshot-2-gnuradio.png` — "GNU Radio SDR signal analysis"
- `assets/sf-screenshot-3-wireshark.png` — "Wireshark with telecom dissectors"
- `assets/sf-screenshot-4-terminal.png` — "100+ tools, ready from the terminal"

## 5. SourceForge — Default Download (CRITICAL — currently unset)

File manager → `vX.Y.Z/` (highest) → the `.iso` → mark **Default Download for
all platforms**. Without this, `files/latest/download` (the link in every badge
and doc) does not serve the ISO. Re-do after every stable release.

## 6. Reviews flywheel (SF ranks/badges by review count)

Already nudged in: the SF READMEs, GitHub release notes, and the first-boot
MOTD (`/etc/update-motd.d/06-telcosec-academy`). Ask directly in Discord and in
release announcements too — reviews are the single biggest SF discovery lever.

## 7. Measurement

Academy links in release notes carry `utm_source=github&utm_medium=release`.
Add equivalent UTM tags to any SF/Discord/social CTA so Academy sign-ups can be
attributed back to the channel that drove them.

---

### Status (2026-10-18)
- [x] Repo topics (20) + keyword description — set via API
- [x] Release-notes Academy/Discord/review CTA — in release.yml
- [x] First-boot MOTD nudge — in 05-desktop-customization.sh
- [x] In-ISO docs OG/Twitter/JSON-LD — correct org + current version
- [ ] GitHub social-preview image — upload in Settings
- [ ] GitHub Discussions — enable + pin welcome post
- [ ] SF categories + summary + screenshots — paste from this doc
- [ ] SF Default Download — set for v2026.3.0
