# syntax=docker/dockerfile:1
# telcochisel-5ghoul — BladeRF-first 5Ghoul image.
# Build context is the REPO ROOT, from telcochisel-base:
#
#   docker build -f docker/5ghoul.Dockerfile -t telcochisel-5ghoul .
#
# First compile (not done at image build): sudo 5ghoul-install
# Runtime needs /dev/bus/usb for a BladeRF, plus NET_ADMIN and /dev/net/tun
# when the gNB dataplane is used. See docker/descriptions/5ghoul.md.
ARG BASE_IMAGE=telcochisel-base
FROM ${BASE_IMAGE}

ARG VERSION=2026.2
ENV TELCOSEC_5GHOUL_RADIO=BLADERF \
    TELCOSEC_5GHOUL_DIR=/opt/telcosec/5ghoul

LABEL org.opencontainers.image.title="TelcoSec TelcoChisel 5Ghoul" \
      org.opencontainers.image.description="TelcoSec TelcoChisel 5Ghoul — pinned 5Ghoul tree with BladeRF, LimeSDR, and USRP radio overlay" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.url="https://telcochisel.com" \
      org.opencontainers.image.documentation="https://telcochisel.com" \
      org.opencontainers.image.source="https://github.com/TelcoChisel/TelcoChiselOS" \
      org.opencontainers.image.vendor="TelcoSec" \
      org.opencontainers.image.licenses="Apache-2.0" \
      net.telcosec.brand="TelcoSec" \
      net.telcosec.product="TelcoChisel" \
      net.telcosec.tier="5ghoul" \
      net.telcosec.category="telecom-security-research"

USER root
COPY packages/5ghoul-5g-nr-attacks/UPSTREAM /opt/telcosec/5ghoul-overlay/UPSTREAM
COPY packages/5ghoul-5g-nr-attacks/scripts /opt/telcosec/5ghoul-overlay/scripts
COPY docker/scripts/35-5ghoul.sh /tmp/35-5ghoul.sh
RUN bash /tmp/35-5ghoul.sh && rm -f /tmp/35-5ghoul.sh

WORKDIR /home/telcosec
USER telcosec

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD ["/usr/local/bin/container-healthcheck.sh"]

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/bash"]
