# syntax=docker/dockerfile:1
# TelcoSec 5Ghoul image. Build context is this directory:
#   docker build -t telcosec/5ghoul packages/5ghoul-5g-nr-attacks
#
# The image carries BladeRF userspace, the radio overlay, and build
# dependencies. The OAI compile stays a first-run step (20–60 min):
#   docker compose run --rm 5ghoul 5ghoul-install
FROM ubuntu:24.04

ARG VERSION=2026.2
ENV DEBIAN_FRONTEND=noninteractive \
    TELCOSEC_5GHOUL_RADIO=BLADERF \
    TELCOSEC_5GHOUL_DIR=/opt/telcosec/5ghoul \
    PATH="/usr/local/bin:${PATH}"

LABEL org.opencontainers.image.title="TelcoSec 5Ghoul" \
      org.opencontainers.image.description="TelcoSec 5Ghoul overlay — pinned asset-group/5ghoul-5g-nr-attacks with BladeRF, LimeSDR, and USRP radio backends" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.source="https://github.com/TelcoChisel/5ghoul-5g-nr-attacks" \
      org.opencontainers.image.vendor="TelcoSec" \
      org.opencontainers.image.licenses="Apache-2.0"

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git sudo tini \
      build-essential cmake ninja-build pkg-config python3 \
      libbladerf2 libbladerf-dev bladerf \
      libuhd-dev uhd-host \
 && rm -rf /var/lib/apt/lists/* \
 && (getent group plugdev >/dev/null || groupadd plugdev) \
 && (getent passwd ubuntu >/dev/null && userdel -r ubuntu 2>/dev/null || true) \
 && (getent group ubuntu >/dev/null && groupdel ubuntu 2>/dev/null || true) \
 && groupadd -g 1000 telcosec \
 && useradd -u 1000 -g telcosec -G plugdev -m -s /bin/bash telcosec \
 && mkdir -p /opt/telcosec \
 && printf 'telcosec ALL=(root) NOPASSWD: /usr/local/bin/5ghoul-install, /opt/telcosec/5ghoul/build/5g_fuzzer\n' > /etc/sudoers.d/telcosec \
 && chmod 440 /etc/sudoers.d/telcosec

COPY UPSTREAM /opt/telcosec/5ghoul-overlay/UPSTREAM
COPY scripts /opt/telcosec/5ghoul-overlay/scripts
RUN chmod 755 /opt/telcosec/5ghoul-overlay/scripts/*.sh /opt/telcosec/5ghoul-overlay/scripts/5ghoul-run \
 && ln -sf /opt/telcosec/5ghoul-overlay/scripts/install.sh /usr/local/bin/5ghoul-install \
 && ln -sf /opt/telcosec/5ghoul-overlay/scripts/5ghoul-run /usr/local/bin/5ghoul-run \
 && chown -R telcosec:telcosec /opt/telcosec

WORKDIR /opt/telcosec
USER telcosec
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/bash"]
