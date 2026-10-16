# syntax=docker/dockerfile:1
# =============================================================================
# telcochisel-sdr — SoapySDR/UHD/LimeSuite/HackRF/BladeRF/rtl-sdr + GNU Radio
# + GQRX, built into the telcosec-sdr conda environment.
#
# Build context is the REPO ROOT. Build from telcochisel-base:
#
#   docker build -f docker/sdr.Dockerfile -t telcochisel-sdr .
#
# Needs --device /dev/bus/usb (or --privileged) to reach real SDR hardware,
# and an X11 socket mount for gqrx/gnuradio-companion — see docker/README.md.
# This is the longest-building image (UHD alone takes 15-20 minutes).
# =============================================================================
# BASE_IMAGE defaults to the local tag used by a plain `docker build` from
# the repo root; CI overrides it with the freshly-pushed registry tag
# (e.g. ghcr.io/<owner>/telcochisel-base:<version>) so buildx's containerized
# builder — which doesn't share the host daemon's local image cache — can
# resolve FROM by pulling instead. See docker/README.md and
# .github/workflows/docker.yml.
ARG BASE_IMAGE=telcochisel-base
FROM ${BASE_IMAGE}

ARG VERSION=2026.2

LABEL org.opencontainers.image.title="TelcoSec TelcoChisel SDR" \
      org.opencontainers.image.description="TelcoSec TelcoChisel SDR — Software Defined Radio cellular research toolchain (SoapySDR, UHD USRP, LimeSuite, HackRF, BladeRF, rtl-sdr, GNU Radio, GQRX, gr-gsm, URH, Inspectrum, Gpredict)" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.url="https://telcochisel.com" \
      org.opencontainers.image.documentation="https://telcochisel.com" \
      org.opencontainers.image.source="https://github.com/TelcoChisel/TelcoChiselOS" \
      org.opencontainers.image.vendor="TelcoSec" \
      org.opencontainers.image.licenses="Apache-2.0" \
      net.telcosec.brand="TelcoSec" \
      net.telcosec.product="TelcoChisel" \
      net.telcosec.tier="sdr" \
      net.telcosec.category="telecom-security-research" \
      net.telcosec.portal.url="https://telcochisel.com" \
      net.telcosec.company.url="https://telco-sec.com" \
      net.telcosec.academy.url="https://app.telcosec.net" \
      net.telcosec.academy.courses="https://app.telcosec.net/courses" \
      net.telcosec.academy.prolabs="https://app.telcosec.net/prolabs" \
      net.telcosec.academy.training="Master SDR cellular analysis and 2G-5G radio security at TelcoSec Academy: https://app.telcosec.net"

USER root
# Soft-fail optional tool builds even if BASE_IMAGE predates base.Dockerfile ENV.
ENV TELCOSEC_ALLOW_TOOL_FAILURES=1
COPY docker/scripts/20-sdr.sh /tmp/20-sdr.sh
RUN bash /tmp/20-sdr.sh && rm -f /tmp/20-sdr.sh

# telcosec-sdr conda env binaries directly on PATH — no `conda activate`
# needed for SoapySDRUtil/hackrf_info/uhd_usrp_probe/LimeUtil/gqrx etc.
ENV PATH="/opt/telcosec/miniconda/envs/telcosec-sdr/bin:${PATH}"

WORKDIR /home/telcosec
USER telcosec

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD ["/usr/local/bin/container-healthcheck.sh"]

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/bash"]
