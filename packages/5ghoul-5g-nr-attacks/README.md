# TelcoSec 5Ghoul

Radio overlay for [asset-group/5ghoul-5g-nr-attacks](https://github.com/asset-group/5ghoul-5g-nr-attacks), maintained for TelcoChisel.

This repository does not vendor the upstream OAI tree. `scripts/install.sh` clones the commit in `UPSTREAM`, then:

- rewrites `build_oai -w USRP` to `-w BLADERF` or `-w LMSSDR` in every shell script (including `requirements.sh`)
- writes a 20 MHz n78 gNB config (`configs/5gnr_gnb/n78.106.bladerf.conf` and `conf/gnb_bladerf.conf`) with BladeRF device args and gain clamped for the A4
- adjusts `requirements.sh` for Ubuntu 24.04 package names

Default radio in the container image is **BladeRF**. USRP and LimeSDR are `--radio USRP` and `--radio LIMESDR`.

## Image

From this directory:

```bash
docker compose run --rm 5ghoul
docker compose run --rm 5ghoul 5ghoul-install
```

The image installs BladeRF userspace and the overlay. The OAI compile runs on first `5ghoul-install` (typically 20–60 minutes) and needs the USB device passed through (`/dev/bus/usb` is set in `compose.yaml`).

TelcoChiselOS also publishes `telcochisel-5ghoul`, built `FROM telcochisel-base` with this same overlay.

```bash
docker pull ghcr.io/telcochisel/5ghoul:latest
```

The package is private until it is marked public:

https://github.com/orgs/TelcoChisel/packages/container/5ghoul/settings
