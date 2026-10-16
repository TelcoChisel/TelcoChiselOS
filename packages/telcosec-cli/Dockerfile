# ==============================================================================
# Build Stage: Compile static multi-architecture Go binary
# ==============================================================================
FROM golang:1.22-alpine AS builder

RUN apk add --no-cache git make ca-certificates

WORKDIR /src

# Pre-copy dependency manifests
COPY go.mod ./

# Copy full source tree
COPY . .

ARG TARGETOS TARGETARCH
ARG VERSION=v2026.2
ARG COMMIT=container
ARG BUILD_DATE

RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build \
    -trimpath \
    -ldflags "-s -w -X main.Version=${VERSION} -X main.GitCommit=${COMMIT} -X main.BuildDate=${BUILD_DATE}" \
    -o /out/telcosec ./cmd/telcosec

# ==============================================================================
# Final Stage: Lightweight production runtime image
# ==============================================================================
FROM alpine:3.20

# Install diagnostic utilities and telecom runtime helpers
RUN apk add --no-cache \
    ca-certificates \
    usbutils \
    pciutils \
    iproute2 \
    ethtool \
    curl \
    bash \
    tzdata \
    man-pages

# Create unprivileged operator user and assign telecom hardware access groups
RUN addgroup -g 1000 telcosec && \
    adduser -u 1000 -G telcosec -h /home/telcosec -D -s /bin/bash telcosec && \
    (getent group dialout || addgroup -g 20 dialout) && \
    (getent group plugdev || addgroup -g 46 plugdev) && \
    (getent group netdev || addgroup -g 102 netdev) && \
    addgroup telcosec dialout && \
    addgroup telcosec plugdev && \
    addgroup telcosec netdev

# Deploy statically compiled operator CLI binaries
COPY --from=builder /out/telcosec /usr/local/bin/telcosec
RUN ln -s /usr/local/bin/telcosec /usr/local/bin/telcochisel

# Deploy shell autocompletions
COPY completions/telcosec.bash /etc/bash_completion.d/telcosec
COPY completions/_telcosec /usr/share/zsh/site-functions/_telcosec
COPY completions/telcosec.fish /usr/share/fish/vendor_completions.d/telcosec.fish

# Deploy Section 1 UNIX manual pages
RUN mkdir -p /usr/share/man/man1
COPY docs/man/telcosec.1 /usr/share/man/man1/telcosec.1
RUN ln -s /usr/share/man/man1/telcosec.1 /usr/share/man/man1/telcochisel.1

# Standard OpenContainers annotations
LABEL org.opencontainers.image.title="telcosec-cli" \
      org.opencontainers.image.description="Unified Operator CLI for Telecom Security, SDR Diagnostics, and 5G SA Operations" \
      org.opencontainers.image.url="https://telcochisel.com" \
      org.opencontainers.image.documentation="https://telcochisel.com" \
      org.opencontainers.image.source="https://github.com/TelcoChisel/telcosec-cli" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.vendor="TelcoSec Engineering"

USER telcosec
WORKDIR /home/telcosec

ENTRYPOINT ["/usr/local/bin/telcosec"]
CMD ["help"]
