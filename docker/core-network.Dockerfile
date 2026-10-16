# syntax=docker/dockerfile:1
# =============================================================================
# telcochisel-core-network — srsRAN/Open5GS/OAI-UE/5Ghoul first-run helper
# stubs, with their build-dependency sets prebaked so the actual first-run
# compiles (triggered by the user, on the live container) are fast.
#
# Build context is the REPO ROOT. Build from telcochisel-base:
#
#   docker build -f docker/core-network.Dockerfile -t telcochisel-core-network .
#
# Needs --cap-add=NET_ADMIN, /dev/net/tun, and usually --network host at
# `docker run` time for RAN/core networking. gtp5g (a kernel module) and
# Open5GS (upstream docker-compose flow) have real limitations in a
# container — see docker/README.md "Known limitations" before relying on
# either from inside this image.
# =============================================================================
# See docker/sdr.Dockerfile's ARG BASE_IMAGE comment for why this is
# parameterized (buildx CI resolution vs. local `docker build`).
ARG BASE_IMAGE=telcochisel-base
FROM ${BASE_IMAGE}

ARG VERSION=2026.2

LABEL org.opencontainers.image.title="TelcoSec TelcoChisel Core Network" \
      org.opencontainers.image.description="TelcoSec TelcoChisel Core Network — 4G LTE & 5G SA core and RAN emulation & exploitation platform (srsRAN Project, Open5GS 5G Core, OpenAirInterface UE, 5Ghoul fuzzing, gtp5g)" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.url="https://telcochisel.com" \
      org.opencontainers.image.documentation="https://telcochisel.com" \
      org.opencontainers.image.source="https://github.com/TelcoChisel/TelcoChiselOS" \
      org.opencontainers.image.vendor="TelcoSec" \
      org.opencontainers.image.licenses="Apache-2.0" \
      net.telcosec.brand="TelcoSec" \
      net.telcosec.product="TelcoChisel" \
      net.telcosec.tier="core-network" \
      net.telcosec.category="telecom-security-research" \
      net.telcosec.portal.url="https://telcochisel.com" \
      net.telcosec.company.url="https://telco-sec.com" \
      net.telcosec.academy.url="https://app.telcosec.net" \
      net.telcosec.academy.courses="https://app.telcosec.net/courses" \
      net.telcosec.academy.prolabs="https://app.telcosec.net/prolabs" \
      net.telcosec.academy.training="Master 5G SA Core, UPF eBPF bypass, and cellular signaling at TelcoSec Academy: https://app.telcosec.net"

USER root
COPY docker/scripts/30-core-network.sh /tmp/30-core-network.sh
RUN bash /tmp/30-core-network.sh && rm -f /tmp/30-core-network.sh

WORKDIR /home/telcosec
USER telcosec

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD ["/usr/local/bin/container-healthcheck.sh"]

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/bash"]
