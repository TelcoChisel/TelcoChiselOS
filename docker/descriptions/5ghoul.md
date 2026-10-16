# telcochisel-5ghoul

Pinned [5Ghoul](https://github.com/asset-group/5ghoul-5g-nr-attacks) tree with the TelcoSec radio overlay. The image default is **BladeRF**. USRP and LimeSDR are selected at install time.

The OAI compile is not baked into the image. First run:

```bash
docker compose -f docker/compose.yaml run --rm 5ghoul
sudo 5ghoul-install
```

`5ghoul-install` with no arguments uses `TELCOSEC_5GHOUL_RADIO` (BladeRF in this image). Override with `--radio USRP` or `--radio LIMESDR`.

USB passthrough (`/dev/bus/usb`), `NET_ADMIN`, and `/dev/net/tun` are set on the Compose service. The overlay sources live in this repository at `packages/5ghoul-5g-nr-attacks` and are published as [TelcoChisel/5ghoul-5g-nr-attacks](https://github.com/TelcoChisel/5ghoul-5g-nr-attacks).
