# syntax=docker/dockerfile:1
# =============================================================================
# telcochisel-base — headless CLI toolset (protocol scanners, SS7/Diameter/GTP
# exploitation, baseband/SIM analysis, 5G UE/gNB simulation).
#
# Build context is the REPO ROOT (not docker/) so this Dockerfile can COPY
# builder/scripts/lib/* — the single source of truth for package lists —
# without duplicating those files. Run from the repo root:
#
#   docker build -f docker/base.Dockerfile -t telcochisel-base .
#
# See docker/README.md for the full reuse boundary and what's deliberately
# left out of this image (GUI desktop, kernel modules, systemd services —
# those belong to the ISO or to the sdr/core-network/device-tools add-ons).
# =============================================================================
# Stage 1: build the Go operator CLI (preferred over the bash launcher).
FROM golang:1.27-bookworm AS cli-builder
WORKDIR /src
COPY packages/telcosec-cli/ ./
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/telcosec ./cmd/telcosec

FROM ubuntu:24.04

ARG VERSION=2026.2

LABEL org.opencontainers.image.title="TelcoSec TelcoChisel Base" \
      org.opencontainers.image.description="TelcoSec TelcoChisel Base — Headless CLI telecom security penetration testing and research toolset (nmap, tshark, Scapy, SIPVicious, sctpscan, SigPloit, Diafuzzer, FirmWire, QCSuper, MTKClient, pySim, lpac, SIMtrace2, SIMurai, UERANSIM, SCAT, LTESniffer, sipp, asleap, snmp-check, docsis, routersploit, rtpbleed, voiphopper, sipsak)" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.url="https://telcochisel.com" \
      org.opencontainers.image.documentation="https://telcochisel.com" \
      org.opencontainers.image.source="https://github.com/TelcoChisel/TelcoChiselOS" \
      org.opencontainers.image.vendor="TelcoSec" \
      org.opencontainers.image.licenses="Apache-2.0" \
      net.telcosec.brand="TelcoSec" \
      net.telcosec.product="TelcoChisel" \
      net.telcosec.tier="base" \
      net.telcosec.category="telecom-security-research" \
      net.telcosec.portal.url="https://telcochisel.com" \
      net.telcosec.company.url="https://telco-sec.com" \
      net.telcosec.academy.url="https://app.telcosec.net" \
      net.telcosec.academy.courses="https://app.telcosec.net/courses" \
      net.telcosec.academy.prolabs="https://app.telcosec.net/prolabs" \
      net.telcosec.academy.training="Master telecom security, 5G SA signaling, and SDR wireless audits at TelcoSec Academy: https://app.telcosec.net"

ENV DEBIAN_FRONTEND=noninteractive \
    TELCOSEC_OPT=/opt/telcosec \
    PATH="/usr/local/bin:${PATH}"

# Configure dpkg to permanently exclude docs, manpages, and groff files for minimal footprint,
# and configure apt to skip recommends/suggests.
RUN mkdir -p /etc/dpkg/dpkg.cfg.d /etc/apt/apt.conf.d \
 && printf "path-exclude /usr/share/doc/*\npath-include /usr/share/doc/*/copyright\npath-exclude /usr/share/man/*\npath-exclude /usr/share/groff/*\npath-exclude /usr/share/info/*\npath-exclude /usr/share/lintian/*\npath-exclude /usr/share/linda/*\n" > /etc/dpkg/dpkg.cfg.d/01_nodoc \
 && printf "APT::Install-Recommends \"0\";\nAPT::Install-Suggests \"0\";\n" > /etc/apt/apt.conf.d/01_norecommends

# telcosec user — parity with the ISO's account so tool configs, wordlist
# paths, and /opt/telcosec ownership match what TelcoChisel documentation
# and helper scripts already assume. ubuntu:24.04 ships a pre-existing
# "ubuntu" user/group at uid/gid 1000 (since 24.04's image revamp) — remove
# it first so telcosec can claim 1000:1000 cleanly.
RUN (getent passwd ubuntu >/dev/null && userdel -r ubuntu 2>/dev/null || true) \
 && (getent group ubuntu >/dev/null && groupdel ubuntu 2>/dev/null || true) \
 && groupadd -g 1000 telcosec \
 && useradd -u 1000 -g telcosec -m -s /bin/bash telcosec \
 && mkdir -p /opt/telcosec/lib /usr/local/libexec && chown -R telcosec:telcosec /opt/telcosec \
 && mkdir -p /etc/apt/keyrings /etc/apt/sources.list.d

# Fingerprint-verify TelcoChisel APT key (same FPR as ISO builder / install script).
# Best-effort: offline/air-gapped builds skip the repo rather than aborting.
COPY docker/scripts/install-apt-key.sh /tmp/install-apt-key.sh
RUN chmod +x /tmp/install-apt-key.sh \
 && (bash /tmp/install-apt-key.sh || echo "WARNING: TelcoChisel APT key not installed (offline or fingerprint failure)") \
 && rm -f /tmp/install-apt-key.sh \
 && rm -rf /var/lib/apt/lists/*

COPY builder/scripts/lib/packages.sh         /opt/telcosec/lib/packages.sh
COPY builder/scripts/lib/pip-retry.sh        /opt/telcosec/lib/pip-retry.sh
COPY builder/scripts/lib/pip-constraints.txt /opt/telcosec/lib/pip-constraints.txt
COPY builder/scripts/lib/record-tool.sh      /opt/telcosec/lib/record-tool.sh
COPY builder/wordlists/                      /opt/telcosec/wordlists/
COPY docker/scripts/00-container-common.sh   /opt/telcosec/lib/00-container-common.sh
# Go at libexec; bash wrapper on PATH execs it (same layout as the ISO).
COPY --from=cli-builder /out/telcosec         /usr/local/libexec/telcosec
COPY builder/scripts/bin/telcosec            /usr/local/bin/telcosec
COPY builder/scripts/bin/telcosec            /usr/local/bin/telcosec.bash
COPY builder/scripts/bin/telcosec-pkg        /usr/local/bin/telcosec-pkg
COPY builder/scripts/bin/telcosec-academy    /usr/local/bin/telcosec-academy
COPY builder/scripts/bin/telcosec-prolabs    /usr/local/bin/telcosec-prolabs
COPY docker/scripts/10-base-tools.sh         /tmp/10-base-tools.sh

# Container builds treat missing optional tools as non-fatal (ISO still fails hard).
ENV TELCOSEC_ALLOW_TOOL_FAILURES=1
RUN chmod +x /usr/local/libexec/telcosec /usr/local/bin/telcosec /usr/local/bin/telcosec.bash /usr/local/bin/telcosec-* \
 && ln -sf /usr/local/bin/telcosec /usr/local/bin/telcochisel \
 && bash /tmp/10-base-tools.sh \
 && rm -f /tmp/10-base-tools.sh

WORKDIR /home/telcosec
USER telcosec

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD ["/usr/local/bin/container-healthcheck.sh"]

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/bash"]
