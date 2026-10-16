# syntax=docker/dockerfile:1.4
# TelcoChisel Hermetic ISO Build Container
# Ubuntu 24.04 LTS Noble Numbat based environment for building TelcoChisel Live ISOs

FROM ubuntu:24.04

LABEL org.opencontainers.image.title="TelcoChisel ISO Builder" \
      org.opencontainers.image.description="Hermetic, reproducible Live ISO build environment for TelcoChiselOS" \
      org.opencontainers.image.vendor="TelcoSec" \
      org.opencontainers.image.version="2026.2"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Install all host dependencies required for debootstrap, squashfs assembly, and EFI Secure Boot signing
RUN apt-get update && apt-get install -y --no-install-recommends \
    debootstrap \
    squashfs-tools \
    xorriso \
    mtools \
    dosfstools \
    grub-pc-bin \
    grub-efi-amd64-bin \
    shim-signed \
    grub-efi-amd64-signed \
    git \
    ca-certificates \
    curl \
    wget \
    rsync \
    bc \
    kmod \
    procps \
    psmisc \
    util-linux \
    fdisk \
    tar \
    zstd \
    pigz \
    gawk \
    coreutils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Set default entrypoint for running build-iso.sh
ENTRYPOINT ["/bin/bash", "build-iso.sh"]
CMD ["--flavor=full"]
