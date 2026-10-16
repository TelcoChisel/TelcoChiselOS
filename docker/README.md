# TelcoChisel Container Images

Docker images of the TelcoChisel toolset, as an alternative to booting the
[live ISO](../README.md). Useful when you just want to run a specific tool
(`nmap`, `pySim-shell`, `UERANSIM`, …) without booting a full desktop OS.

**This is a second, narrower delivery format, not a replacement for the ISO.**
The live ISO remains the right vehicle for the full SDR/RAN research
experience — desktop GUI tools, kernel-module-dependent tools (`gtp5g`),
realtime/kernel-cmdline tuning, and the systemd-managed ChiselControl
dashboard are either unavailable or degraded in a container. See "Known
limitations" below before choosing a container over the ISO for a given task.

> 🎓 **Hands-On Telecom Security Training & Live Labs:**  
> Learn how to execute signaling assessments, 5G SA core exploits, and SDR wireless testing with interactive labs at the **[TelcoSec Academy](https://app.telcosec.net)**:
> - 📡 **Interactive Courses & Certifications:** [app.telcosec.net/courses](https://app.telcosec.net/courses)
> - 🛠️ **ProLabs Cellular Testbeds:** [app.telcosec.net/prolabs](https://app.telcosec.net/prolabs)

## Images (`v2026.2`)

| Image | Contents | Runtime needs |
|-------|----------|----------------|
| `telcochisel-base` | Headless CLI toolset + Go `telcosec` at `/usr/local/libexec/telcosec` (PATH bash wrapper; `telcosec.bash` / `TELCOSEC_FORCE_BASH=1` for bash): nmap, tshark, Scapy, SIPVicious, sctpscan, SigPloit, Diafuzzer, FirmWire, QCSuper, MTKClient, pySim, lpac, SIMtrace2, SIMurai, UERANSIM, SCAT, kalibrate-gsm, SIMTester, LTESniffer, RouterSploit, sipp, asleap, snmp-check, docsis, sipsak, voiphopper, rtpbleed, mausezahn (mz), sdr-info, telcosec-ran-status, telcosec-pkg, telcosec-academy, telcosec-prolabs, mitmproxy, pcsc-tools, OpenSC, telecom wordlists | none |
| `telcochisel-sdr` | `FROM base` + SoapySDR/UHD/LimeSuite/HackRF/BladeRF/rtl-sdr, GNU Radio 3.10, GQRX, gr-gsm, kalibrate-rtl, URH, Inspectrum, Gpredict (conda `telcosec-sdr` env) | USB device passthrough; X11 for GUI tools |
| `telcochisel-core-network` | `FROM base` + srsRAN/Open5GS/OAI-UE/5Ghoul first-run helper stubs and their build deps prebaked | `NET_ADMIN`, `/dev/net/tun`, often host networking |
| `telcochisel-5ghoul` | `FROM base` + BladeRF/UHD userspace and the pinned 5Ghoul radio overlay (`packages/5ghoul-5g-nr-attacks`). Default radio is BladeRF. Compile with `sudo 5ghoul-install` | USB passthrough, `NET_ADMIN`, `/dev/net/tun` |
| `telcochisel-device-tools` | `FROM base` + Heimdall, ADB/Fastboot, MTKClient wrappers, QCSuper, EDL, AT console | USB/serial device passthrough |

Matches the ISO's own "ready" vs. "setup" tool taxonomy (see the main
`CLAUDE.md`) — the core-network image's helpers (`srsran-install`,
`open5gs-install`, `oai-install`, `5ghoul-install`, `gtp5g-load`) are
first-run compiles, not pre-built binaries, same as on the ISO.

## Container Optimizations

All TelcoChisel container images feature runtime and build optimizations:
- **PID 1 Signal Handling (`tini`)**: Containers run under `/usr/bin/tini` as init subreaper to propagate `SIGINT`/`SIGTERM` to scanning tools (`tshark`, `sipp`, `sctpscan`) and eliminate zombie child processes.
- **Built-in Healthchecks**: Containers implement Docker and Kubernetes native probes via `/usr/local/bin/container-healthcheck.sh`, dynamically validating tool responsiveness and subsystem readiness.
- **Layer & Cache Pruning**: Conda package archives are cleaned via `conda clean -afy`, and temporary compilers are purged after build stages to keep image footprints minimal.
- **Broadband & Wireline Parity**: Added `asleap`, `docsis`, and `snmp-check` alongside `routersploit` and `sipp` for full wireline and PPPoE audit capabilities.

---

## Telecom POD Orchestration

In cellular and telco cloud architectures (Kubernetes, OpenShift, bare-metal Podman), testing requires tightly-coupled multi-container orchestration. TelcoChisel provides pre-engineered **Telecom POD manifests** in `docker/pods/`:

### Available POD Manifests

| Manifest | Architecture | Use Case |
|---|---|---|
| `podman-telecom-pod.yaml` | Multi-container (Core + Scanner) | Instant rootless execution via `podman play kube` on Linux or WSL2 |
| `k8s-5g-core-pod.yaml` | Multi-container (`open5gs-core` + `ueransim-tester`) | 5G Standalone Core & RAN simulation with shared localhost networking |
| `k8s-sdr-rf-pod.yaml` | Real-time SDR engine | Over-the-air RF signal capture with `SYS_NICE` priority and USB passthrough |
| `k8s-device-audit-pod.yaml` | Flasher + Baseband Decoder | Non-privileged default; USB hostPath only |
| `k8s-device-audit-pod.privileged.yaml` | Same (lab-only) | Opt-in `privileged: true` for full ttyUSB — **not** for shared clusters |
| `k8s-telecom-suite-pod.yaml` | Unified multi-container suite | End-to-end telecom red team assessment across signaling, RAN, and RF |

### Rootless Quickstart with Podman (`play kube`)

You do **not** need a Kubernetes cluster to run multi-container telecom pods. Rootless Podman natively runs them via `podman play kube`:

```bash
# 1. Start the Telecom Pod (shares localhost networking between Core and Scanner)
podman play kube docker/pods/podman-telecom-pod.yaml

# 2. Check running pod and containers
podman pod ps
podman ps --filter "label=net.telcosec.product=telcochisel"

# 3. Open a shell inside the scanner container
podman exec -it telcochisel-telecom-pod-telecom-scanner /bin/bash

# 4. Tear down the pod
podman play kube --down docker/pods/podman-telecom-pod.yaml
```

### Deploying to Kubernetes Clusters

```bash
# Deploy 5G Core & RAN simulator pod
kubectl apply -f docker/pods/k8s-5g-core-pod.yaml

# Inspect status
kubectl get pods -l app.kubernetes.io/part-of=telcochisel

# Shell into the RAN simulator container
kubectl exec -it telcochisel-5g-core-pod -c ueransim-tester -- /bin/bash
```

### Unified CLI Helper: `pod-deploy.sh`

Use `docker/pods/pod-deploy.sh` for convenient cluster and pod management:

```bash
# Start or stop Podman pod
bash docker/pods/pod-deploy.sh start-podman
bash docker/pods/pod-deploy.sh stop-podman

# Deploy or delete Kubernetes pod
bash docker/pods/pod-deploy.sh apply-k8s docker/pods/k8s-5g-core-pod.yaml
bash docker/pods/pod-deploy.sh delete-k8s docker/pods/k8s-5g-core-pod.yaml

# Inspect pod health across Podman and Kubernetes
bash docker/pods/pod-deploy.sh status
```

---

## Build

Build context is the **repo root**, not `docker/` — the Dockerfiles `COPY`
`builder/scripts/lib/*` (the single source of truth for package lists)
directly, so run these from the repo root:

```bash
docker build -f docker/base.Dockerfile         -t telcochisel-base .
docker build -f docker/device-tools.Dockerfile -t telcochisel-device-tools .
docker build -f docker/sdr.Dockerfile          -t telcochisel-sdr .
docker build -f docker/core-network.Dockerfile -t telcochisel-core-network .
docker build -f docker/5ghoul.Dockerfile       -t telcochisel-5ghoul .
```

or with Compose:

```bash
docker compose -f docker/compose.yaml build
```

`telcochisel-sdr` is the slowest build (UHD alone takes 15-20 minutes).

The add-on Dockerfiles accept a `BASE_IMAGE` build arg (default:
`telcochisel-base`, i.e. whatever you just built locally). CI overrides it to
pull the freshly-pushed registry tag instead, since buildx's containerized
builder doesn't share the local Docker daemon's image cache:
`--build-arg BASE_IMAGE=ghcr.io/<owner>/telcochisel-base:<version>`.

## Run

```bash
# Base — no special flags
docker run --rm -it telcochisel-base

# SDR — USB passthrough + X11 for GQRX
docker run --rm -it \
  --device /dev/bus/usb \
  -e DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  telcochisel-sdr

# Core network — NET_ADMIN + tun device, usually host networking
docker run --rm -it \
  --cap-add=NET_ADMIN --device /dev/net/tun --network host \
  telcochisel-core-network

# Device tools — USB + serial passthrough
docker run --rm -it \
  --device /dev/bus/usb --device /dev/ttyUSB0 \
  telcochisel-device-tools

# 5Ghoul — BladeRF by default; compile on first run
docker compose -f docker/compose.yaml run --rm 5ghoul
# inside the container: sudo 5ghoul-install
```

Or via Compose: `docker compose -f docker/compose.yaml run --rm sdr`, etc.
See `docker/compose.yaml` for the full flag set per image.

For nested Open5GS install (host Docker socket — lab hosts only):

```bash
docker compose -f docker/compose.yaml -f docker/compose.docker-sock.yaml run --rm core-network
```

## Package reuse boundary

The Dockerfiles are **fresh** — they do not source or modify the 13
provisioning scripts under `builder/scripts/` or `build-iso.sh`, so the ISO
build is unaffected by anything in this directory. What they *do* reuse:

- `builder/scripts/lib/packages.sh` — the `PKGS_*` arrays, verbatim. This
  stays the single source of truth for package names; a package added there
  is available to container scripts automatically.
- `builder/scripts/lib/pip-retry.sh`, `pip-constraints.txt`, `record-tool.sh`
  — the pip retry wrapper and build-verification helper, verbatim.
- `docker/scripts/00-container-common.sh` defines `CONTAINER_PKG_BLOCKLIST` —
  package names that only make sense for the live ISO / a desktop / a real
  kernel and init system (`casper`, `xfce4`, `lightdm`, `grub-*`, `calamares`,
  `tuned`, …) — and `filter_pkgs()`, which strips them out of any `PKGS_*`
  array before `apt-get install`. GUI tools that work under the optional
  X11-passthrough model (`wireshark`, `gqrx`, `twinkle`, `baresip`) are
  deliberately **kept**, not blocklisted.
- The tool **build steps** themselves (source builds in `docker/scripts/10-
  base-tools.sh`, `20-sdr.sh`, `30-core-network.sh`, `40-device-tools.sh`)
  are copied from the corresponding `builder/scripts/0N-*.sh` step, with
  `sudo`/`chown telcosec`/`systemctl enable`/udev/`.desktop` launcher lines
  dropped since they don't apply to a container build. If you fix a build
  step in one place, check whether the other needs the same fix — see each
  script's header comment for which `builder/scripts/*.sh` it mirrors.

## Known limitations

These are containerization realities, not missing features to "fix" — see
each helper's own `docker/scripts/30-core-network.sh` comments for detail:

- **`gtp5g` (kernel module).** Cannot be built against, or loaded into, the
  container's host kernel from inside an unprivileged container.
  `gtp5g-load` checks for matching kernel headers and fails with a clear
  message rather than silently doing nothing; load it on the host instead.
- **Open5GS.** Upstream's install flow is `docker compose` — a container-in-
  container pattern. `open5gs-install` needs a mounted host Docker socket
  (opt-in: `docker compose -f docker/compose.yaml -f docker/compose.docker-sock.yaml …`)
  or true Docker-in-Docker; the default compose file does **not** mount
  `docker.sock` (host-root equivalent).
- **Realtime/PAM limits, `mitigations=off`, hugepages, sysctl tuning.** These
  are host-kernel/boot-cmdline concerns (see the ISO's `08-system-
  optimization.sh` and the "Security Posture" section of the main
  `CLAUDE.md`) and are simply not applicable inside a container — set them
  on the Docker host if RAN performance requires it.
- **GUI tools (GQRX, Wireshark GUI, gnuradio-companion, softphones).** Shipped
  in the relevant image, but need an X11 socket mounted from a Linux host
  (see the `sdr` run recipe above). No VNC/noVNC server is bundled — Windows/
  Mac users without an X server should use the live ISO for GUI tools instead.
- **SDR/USB/serial hardware.** Every device-touching tool is a no-op without
  the corresponding `--device`/`--privileged` flag at `docker run` time —
  building an image never requires hardware, only running against real RF or
  USB/serial devices does.

## CI / publishing

`.github/workflows/docker.yml` builds all four images via a buildx matrix and
pushes to `ghcr.io/telcochisel/telcochisel-{base,sdr,core-network,device-tools}`
on `workflow_dispatch` or `v*.*.*` tag pushes, tagged `latest` + the version.
Independent of `.github/workflows/release.yml` (the ISO release path) — a
Docker publish never blocks or is blocked by an ISO release.

## Smoke testing

```bash
bash docker/smoke-test.sh --build   # build all four images, then test
bash docker/smoke-test.sh           # test images already built locally
```

Runs a representative tool per category with `--version`/`--help` in each
image and validates all Telecom POD manifests. This is a build/PATH sanity check,
not a functional test of SDR/network features — those need real hardware/privilege
(see "Known limitations" above).

