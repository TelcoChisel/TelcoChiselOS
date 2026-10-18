#!/usr/bin/env bash
# =============================================================================
# scripts/deploy_menu.sh — TelcoSec TelcoChisel Service & Build Navigator
#
# Interactive and programmatic deployment and build manager for TelcoChisel OS:
#   - Docker Container Services (Base, SDR, Core Network, Device Tools, Compose)
#   - Kubernetes & Rootless Podman Telecom PODs (5G SA Core, SDR RF, Red Team)
#   - Live ISO Image Builders (Full Field Edition, Modular Lite, Cloud CI)
#   - Virtual Machine Appliance Builders (Proxmox, VMware, VirtualBox, Cloud CI)
#   - WSL2 Distro Generator
#   - Host Daemons & System Services (Open5GS, SigPloit)
#   - Real-time Observability, Healthchecks, and Teardown
#   - Direct TelcoSec Academy & Documentation Integration
#
# Usage:
#   ./deploy_menu.sh                     (Interactive TUI menu)
#   ./deploy_menu.sh --deploy <service>  (Deploy specific service)
#   ./deploy_menu.sh --build-iso [full|lite|repack|ci]
#   ./deploy_menu.sh --build-vm [all|proxmox|vmware|virtualbox|ci]
#   ./deploy_menu.sh --build-wsl
#   ./deploy_menu.sh --status            (Inspect status of all services)
#   ./deploy_menu.sh --stop <service>    (Stop/tear down specific service)
#   ./deploy_menu.sh --help              (Show CLI options)
#
# Powered by TelcoSec | TelcoSec Academy: https://app.telcosec.net
# =============================================================================
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ─── Colors and Styling ───────────────────────────────────────────────────────
CYAN='\033[1;36m'
AMBER='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
BOLD='\033[1m'
MUTED='\033[0;37m'
NC='\033[0m'

# Version Resolution
VERSION="2026.2"
if [ -f "${REPO_ROOT}/VERSION" ]; then
  VERSION=$(head -n 1 "${REPO_ROOT}/VERSION" | tr -d '[:space:]')
  VERSION="${VERSION#v}"
fi

IMAGE_REGISTRY="${TELCOCHISEL_REGISTRY:-ghcr.io/telcochisel}"

# ─── Banner Display ───────────────────────────────────────────────────────────
show_banner() {
  clear 2>/dev/null || true
  printf "${CYAN}"
  cat << 'BANNER_ART'
  +-------------------------------------------------------------------------+
  |   _____ _____ _     ____ ___   ____ _   _ ___ ____  _____ _             |
  |  |_   _| ____| |   / ___/ _ \ / ___| | | |_ _/ ___|| ____| |            |
  |    | | |  _| | |  | |  | | | | |   | |_| || |\___ \|  _| | |            |
  |    | | | |___| |__| |__| |_| | |___|  _  || | ___) | |___| |__|         |
  |    |_| |_____|_____\____\___/ \____|_| |_|___|____/|_____|____|         |
BANNER_ART
  printf "${NC}${BOLD}"
  printf "  |        TELCOCHISEL OS v%-7s -- SERVICE & BUILD NAVIGATOR        |\n" "$VERSION"
  printf "  +-------------------------------------------------------------------------+\n"
  printf "${NC}"
  printf "${AMBER}  |  [*] TelcoSec Academy Portal: ${GREEN}https://app.telcosec.net${NC}\n"
  printf "${AMBER}  |  [*] Interactive Courses:     ${GREEN}https://app.telcosec.net/courses${NC}\n"
  printf "${AMBER}  |  [*] ProLabs Active Testbeds: ${GREEN}https://app.telcosec.net/prolabs${NC}\n"
  printf "${BOLD}  +-------------------------------------------------------------------------+${NC}\n\n"
}

# ─── Environment Probing ──────────────────────────────────────────────────────
check_runtimes() {
  printf "${BOLD}=== System Runtime & Tooling Environment ===${NC}\n"
  
  if command -v docker &>/dev/null; then
    if docker info >/dev/null 2>&1; then
      printf "  [✓] Docker Engine:     ${GREEN}Active & Accessible${NC} ($(docker --version | cut -d',' -f1))\n"
    else
      printf "  [!] Docker Engine:     ${AMBER}Installed but daemon not reachable${NC}\n"
    fi
  else
    printf "  [✗] Docker Engine:     ${RED}Not installed${NC}\n"
  fi

  if command -v podman &>/dev/null; then
    printf "  [✓] Podman (Rootless): ${GREEN}Available${NC} ($(podman --version))\n"
  else
    printf "  [ ] Podman (Rootless): ${MUTED}Not detected${NC}\n"
  fi

  if command -v kubectl &>/dev/null; then
    printf "  [✓] Kubernetes CLI:    ${GREEN}Available${NC} ($(kubectl version --client 2>/dev/null | grep -o 'v[0-9]*\.[0-9]*\.[0-9]*' | head -1 || echo 'Installed'))\n"
  else
    printf "  [ ] Kubernetes CLI:    ${MUTED}Not detected${NC}\n"
  fi

  if command -v qemu-img &>/dev/null; then
    printf "  [✓] QEMU Utilities:    ${GREEN}Available${NC} (qemu-img ready for VM builds)\n"
  else
    printf "  [ ] QEMU Utilities:    ${MUTED}Not installed (apt install qemu-utils for local VM builds)${NC}\n"
  fi

  if command -v gh &>/dev/null; then
    if gh auth status >/dev/null 2>&1; then
      printf "  [✓] GitHub CLI (gh):   ${GREEN}Authenticated${NC} (CI dispatch available)\n"
    else
      printf "  [!] GitHub CLI (gh):   ${AMBER}Installed but not authenticated${NC}\n"
    fi
  else
    printf "  [ ] GitHub CLI (gh):   ${MUTED}Not installed (install gh for remote CI triggers)${NC}\n"
  fi

  if systemctl is-system-running &>/dev/null; then
    printf "  [✓] Systemd Init:      ${GREEN}Active${NC}\n"
  else
    printf "  [ ] Systemd Init:      ${MUTED}Container or non-systemd environment${NC}\n"
  fi
  printf "\n"
}

# ─── Service Deployment Functions ─────────────────────────────────────────────

deploy_docker_base() {
  printf "${CYAN}[*] Deploying TelcoSec Base Security Container (Headless)...${NC}\n"
  local img="${IMAGE_REGISTRY}/telcochisel-base:latest"
  if ! docker image inspect "$img" >/dev/null 2>&1 && ! docker image inspect telcochisel-base:latest >/dev/null 2>&1; then
    printf "  Pulling %s...\n" "$img"
    docker pull "$img" || img="telcochisel-base:latest"
  fi
  
  echo "Launching interactive shell in telcochisel-base..."
  docker run --rm -it \
    --name telcochisel-base-interactive \
    --hostname telcochisel-base \
    -e TERM=xterm-256color \
    "$img" /bin/bash
}

deploy_docker_sdr() {
  printf "${CYAN}[*] Deploying TelcoSec SDR & RF Analysis Container...${NC}\n"
  local img="${IMAGE_REGISTRY}/telcochisel-sdr:latest"
  local dev_args=()
  [ -d /dev/bus/usb ] && dev_args+=(--device /dev/bus/usb)
  
  local x11_args=()
  if [ -n "${DISPLAY:-}" ] && [ -d /tmp/.X11-unix ]; then
    x11_args+=(-e DISPLAY="${DISPLAY}" -v /tmp/.X11-unix:/tmp/.X11-unix:ro)
  fi

  docker run --rm -it \
    --name telcochisel-sdr-interactive \
    --hostname telcochisel-sdr \
    "${dev_args[@]}" \
    "${x11_args[@]}" \
    "$img" /bin/bash
}

deploy_docker_core() {
  printf "${CYAN}[*] Deploying TelcoSec Core Network & 5G/RAN Container...${NC}\n"
  local img="${IMAGE_REGISTRY}/telcochisel-core-network:latest"
  local tun_args=()
  [ -e /dev/net/tun ] && tun_args+=(--device /dev/net/tun)

  docker run --rm -it \
    --name telcochisel-core-interactive \
    --hostname telcochisel-core \
    --cap-add=NET_ADMIN \
    "${tun_args[@]}" \
    --network host \
    "$img" /bin/bash
}

deploy_docker_device() {
  printf "${CYAN}[*] Deploying TelcoSec Device Analysis & Modem Tools Container...${NC}\n"
  local img="${IMAGE_REGISTRY}/telcochisel-device-tools:latest"
  local dev_args=()
  [ -d /dev/bus/usb ] && dev_args+=(--device /dev/bus/usb)
  for tty in /dev/ttyUSB* /dev/ttyACM*; do
    [ -e "$tty" ] && dev_args+=(--device "$tty")
  done

  docker run --rm -it \
    --name telcochisel-device-interactive \
    --hostname telcochisel-device \
    "${dev_args[@]}" \
    "$img" /bin/bash
}

deploy_docker_compose() {
  printf "${CYAN}[*] Launching Full TelcoChisel Docker Compose Stack in Background...${NC}\n"
  if [ -f "${REPO_ROOT}/docker/compose.yaml" ]; then
    docker compose -f "${REPO_ROOT}/docker/compose.yaml" up -d
    printf "${GREEN}[✓] Docker Compose stack is running.${NC}\n"
    docker compose -f "${REPO_ROOT}/docker/compose.yaml" ps
  else
    printf "${RED}[-] ERROR: docker/compose.yaml not found.${NC}\n"
  fi
}

deploy_podman_pod() {
  printf "${CYAN}[*] Deploying Rootless Telecom POD via Podman...${NC}\n"
  if ! command -v podman &>/dev/null; then
    printf "${RED}[-] ERROR: 'podman' command not found. Install Podman to run rootless pods.${NC}\n"
    return 1
  fi
  bash "${REPO_ROOT}/docker/pods/pod-deploy.sh" start-podman
}

deploy_k8s_5g_core() {
  printf "${CYAN}[*] Deploying 5G SA Core & UERANSIM POD to Kubernetes...${NC}\n"
  if ! command -v kubectl &>/dev/null; then
    printf "${RED}[-] ERROR: 'kubectl' command not found.${NC}\n"
    return 1
  fi
  bash "${REPO_ROOT}/docker/pods/pod-deploy.sh" apply-k8s "${REPO_ROOT}/docker/pods/k8s-5g-core-pod.yaml"
}

deploy_k8s_sdr() {
  printf "${CYAN}[*] Deploying SDR RF Analysis POD to Kubernetes...${NC}\n"
  if ! command -v kubectl &>/dev/null; then
    printf "${RED}[-] ERROR: 'kubectl' command not found.${NC}\n"
    return 1
  fi
  bash "${REPO_ROOT}/docker/pods/pod-deploy.sh" apply-k8s "${REPO_ROOT}/docker/pods/k8s-sdr-rf-pod.yaml"
}

deploy_k8s_device() {
  printf "${CYAN}[*] Deploying Device & Modem Audit POD to Kubernetes...${NC}\n"
  if ! command -v kubectl &>/dev/null; then
    printf "${RED}[-] ERROR: 'kubectl' command not found.${NC}\n"
    return 1
  fi
  bash "${REPO_ROOT}/docker/pods/pod-deploy.sh" apply-k8s "${REPO_ROOT}/docker/pods/k8s-device-audit-pod.yaml"
}

deploy_k8s_suite() {
  printf "${CYAN}[*] Deploying Full Red Team Telecom POD Suite to Kubernetes...${NC}\n"
  if ! command -v kubectl &>/dev/null; then
    printf "${RED}[-] ERROR: 'kubectl' command not found.${NC}\n"
    return 1
  fi
  bash "${REPO_ROOT}/docker/pods/pod-deploy.sh" apply-k8s "${REPO_ROOT}/docker/pods/k8s-telecom-suite-pod.yaml"
}

deploy_host_open5gs() {
  printf "${CYAN}[*] Managing Host Open5GS 5G Core Network...${NC}\n"
  if systemctl list-units "open5gs-*" --state=active 2>/dev/null | grep -q "open5gs-"; then
    printf "${GREEN}[✓] Open5GS core daemons are currently ACTIVE:${NC}\n"
    systemctl status "open5gs-*" --no-pager 2>/dev/null | grep -E "Loaded|Active" | head -10 || true
  elif [ -f /usr/local/bin/open5gs-install ]; then
    printf "Invoking Open5GS installer / manager...\n"
    /usr/local/bin/open5gs-install
  else
    printf "${AMBER}[!] Open5GS not detected as host systemd units.${NC}\n"
    printf "    Tip: Deploy via Docker container (Option 3) or K8s 5G Core Pod (Option 6).\n"
  fi
}

# ─── Build Engine Functions (ISO, VMs, WSL) ───────────────────────────────────

build_iso_action() {
  local flavor="${1:-full}"
  local ver="${2:-$VERSION}"
  local extra_args=("${@:3}")

  printf "${CYAN}[*] Building TelcoSec TelcoChisel Live ISO (${flavor}, v${ver})...${NC}\n"
  if [ ! -f "${REPO_ROOT}/build-iso.sh" ]; then
    printf "${RED}[-] ERROR: build-iso.sh not found in repository root.${NC}\n"
    return 1
  fi

  if [ "$EUID" -ne 0 ]; then
    printf "${AMBER}[!] Root privileges required. Executing with sudo...${NC}\n"
    sudo bash "${REPO_ROOT}/build-iso.sh" --flavor="${flavor}" --version="${ver}" "${extra_args[@]}"
  else
    bash "${REPO_ROOT}/build-iso.sh" --flavor="${flavor}" --version="${ver}" "${extra_args[@]}"
  fi
}

build_vm_action() {
  local target="${1:-all}"
  local ver="${2:-$VERSION}"
  local iso_path="${3:-}"
  
  if [ -z "$iso_path" ]; then
    shopt -s nullglob
    local isos=("${REPO_ROOT}"/TelcoChisel-*.iso)
    shopt -u nullglob
    if [ ${#isos[@]} -gt 0 ]; then
      iso_path="${isos[0]}"
      printf "  Using local ISO: %s\n" "$iso_path"
    fi
  fi

  printf "${CYAN}[*] Building TelcoSec VM Appliance (${target}, v${ver})...${NC}\n"
  if [ ! -f "${REPO_ROOT}/builder/vm/build-vm.sh" ]; then
    printf "${RED}[-] ERROR: builder/vm/build-vm.sh not found.${NC}\n"
    return 1
  fi

  local cmd_args=(--target "$target" --version "$ver" --compress)
  [ -n "$iso_path" ] && cmd_args+=(--iso "$iso_path")

  if [ "$EUID" -ne 0 ]; then
    printf "${AMBER}[!] Root privileges required. Executing with sudo...${NC}\n"
    sudo "${REPO_ROOT}/builder/vm/build-vm.sh" "${cmd_args[@]}"
  else
    "${REPO_ROOT}/builder/vm/build-vm.sh" "${cmd_args[@]}"
  fi
}

build_wsl_action() {
  printf "${CYAN}[*] Building TelcoSec WSL2 Distro Tarball...${NC}\n"
  if [ ! -f "${REPO_ROOT}/build-wsl.sh" ]; then
    printf "${RED}[-] ERROR: build-wsl.sh not found.${NC}\n"
    return 1
  fi

  if [ "$EUID" -ne 0 ]; then
    printf "${AMBER}[!] Root privileges required. Executing with sudo...${NC}\n"
    sudo bash "${REPO_ROOT}/build-wsl.sh"
  else
    bash "${REPO_ROOT}/build-wsl.sh"
  fi
}

trigger_ci_iso() {
  local flavor="${1:-full}"
  printf "${CYAN}[*] Dispatching GitHub Actions Release Workflow (Live ISO)...${NC}\n"
  if ! command -v gh &>/dev/null; then
    printf "${RED}[-] ERROR: GitHub CLI ('gh') is not installed.${NC}\n"
    return 1
  fi
  gh workflow run release.yml -f flavor="$flavor" -f release_type=patch
  printf "${GREEN}[✓] Release pipeline dispatched! Track run status with:${NC}\n"
  printf "    gh run list --workflow=release.yml\n"
}

trigger_ci_vm() {
  local target="${1:-all}"
  printf "${CYAN}[*] Dispatching GitHub Actions VM Appliance Builder...${NC}\n"
  if ! command -v gh &>/dev/null; then
    printf "${RED}[-] ERROR: GitHub CLI ('gh') is not installed.${NC}\n"
    return 1
  fi
  gh workflow run build-vm.yml -f target="$target" -f compress=true -f publish_sf=true
  printf "${GREEN}[✓] VM builder pipeline dispatched! Track run status with:${NC}\n"
  printf "    gh run list --workflow=build-vm.yml\n"
}

iso_menu() {
  printf "\n${CYAN}=== TelcoChisel Live ISO Builder Menu ===${NC}\n"
  echo "  1) Build Local Full ISO        (All 100 tools offline, ~5.0 GB)"
  echo "  2) Build Local Modular Lite    (~1.8 GB, core desktop + telcosec-pkg)"
  echo "  3) Repack Existing Chroot      (--pack-only, fast squashfs rebuild)"
  echo "  4) Trigger Remote GitHub CI    (Build and publish to SourceForge & GitHub Releases)"
  echo "  5) Back to main menu"
  read -rp "Enter choice [1-5]: " iso_c

  case "$iso_c" in
    1) build_iso_action full "$VERSION" ;;
    2) build_iso_action lite "$VERSION" ;;
    3) build_iso_action full "$VERSION" --pack-only ;;
    4) trigger_ci_iso full ;;
    *) return 0 ;;
  esac
}

vm_menu() {
  printf "\n${CYAN}=== TelcoChisel Virtual Machine Appliance Builder Menu ===${NC}\n"
  echo "  1) Build All Appliances Locally   (Proxmox .qcow2 + VMware .ova + VirtualBox .ova)"
  echo "  2) Build Proxmox Appliance Only   (.qcow2 with Cloud-Init & QEMU Agent)"
  echo "  3) Build VMware Appliance Only    (.ova with streamOptimized VMDK)"
  echo "  4) Build VirtualBox Appliance     (.ova with xHCI USB 3.0 passthrough)"
  echo "  5) Trigger Remote GitHub CI       (Build on GitHub Actions & publish to SourceForge)"
  echo "  6) Back to main menu"
  read -rp "Enter choice [1-6]: " vm_c

  case "$vm_c" in
    1) build_vm_action all "$VERSION" ;;
    2) build_vm_action proxmox "$VERSION" ;;
    3) build_vm_action vmware "$VERSION" ;;
    4) build_vm_action virtualbox "$VERSION" ;;
    5) trigger_ci_vm all ;;
    *) return 0 ;;
  esac
}

show_all_status() {
  printf "\n${BOLD}========================================================================${NC}\n"
  printf "${BOLD}             TelcoChisel Active Services & Workloads Status              ${NC}\n"
  printf "${BOLD}========================================================================${NC}\n\n"

  # Docker containers
  if command -v docker &>/dev/null && docker info >/dev/null 2>&1; then
    printf "${CYAN}--- [Docker Containers] ---${NC}\n"
    local running_containers
    running_containers=$(docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}")
    if [ "$(echo "$running_containers" | wc -l)" -gt 1 ]; then
      echo "$running_containers"
    else
      echo "  (No active Docker containers)"
    fi
    printf "\n"
  fi

  # Podman pods
  if command -v podman &>/dev/null; then
    printf "${CYAN}--- [Podman Pods] ---${NC}\n"
    podman pod ps 2>/dev/null || echo "  (No active Podman pods)"
    printf "\n"
  fi

  # Kubernetes pods
  if command -v kubectl &>/dev/null; then
    printf "${CYAN}--- [Kubernetes Telecom Workloads] ---${NC}\n"
    kubectl get pods -l "app.kubernetes.io/part-of=telcochisel" -o wide 2>/dev/null || echo "  (No active TelcoChisel Kubernetes pods)"
    printf "\n"
  fi

  # Host services
  if systemctl is-system-running &>/dev/null; then
    printf "${CYAN}--- [Host Telecom Services] ---${NC}\n"
    for s in open5gs-amfd open5gs-smfd open5gs-upfd; do
      if systemctl is-active --quiet "$s" 2>/dev/null; then
        printf "  [✓] %-20s ${GREEN}RUNNING${NC}\n" "$s"
      elif systemctl list-unit-files "$s.service" &>/dev/null; then
        printf "  [-] %-20s ${MUTED}STOPPED${NC}\n" "$s"
      fi
    done
    printf "\n"
  fi

  # Local Artifacts
  printf "${CYAN}--- [Local Built Artifacts] ---${NC}\n"
  shopt -s nullglob
  local built_isos=("${REPO_ROOT}"/TelcoChisel-*.iso)
  local built_vms=("${REPO_ROOT}"/dist/vm/*)
  shopt -u nullglob

  if [ ${#built_isos[@]} -gt 0 ]; then
    printf "  ISO Images:\n"
    for f in "${built_isos[@]}"; do
      printf "    - %s (%s)\n" "$(basename "$f")" "$(du -h "$f" | cut -f1)"
    done
  fi

  if [ ${#built_vms[@]} -gt 0 ]; then
    printf "  VM Appliances:\n"
    for f in "${built_vms[@]}"; do
      printf "    - %s (%s)\n" "$(basename "$f")" "$(du -h "$f" | cut -f1)"
    done
  fi

  if [ ${#built_isos[@]} -eq 0 ] && [ ${#built_vms[@]} -eq 0 ]; then
    printf "  (No local ISOs or VM appliances found in repository root or dist/vm)\n"
  fi
  printf "\n"
}

stop_services() {
  printf "${AMBER}Select teardown target:${NC}\n"
  echo "  1) Stop all TelcoChisel Docker containers"
  echo "  2) Stop Docker Compose stack"
  echo "  3) Tear down Podman Telecom Pod"
  echo "  4) Delete Kubernetes TelcoChisel Pods"
  echo "  5) Cancel"
  read -rp "Enter choice [1-5]: " t_choice

  case "$t_choice" in
    1)
      printf "Stopping running TelcoChisel containers...\n"
      docker ps -q --filter "ancestor=${IMAGE_REGISTRY}/telcochisel-base:latest" \
                   --filter "ancestor=${IMAGE_REGISTRY}/telcochisel-sdr:latest" \
                   --filter "ancestor=${IMAGE_REGISTRY}/telcochisel-core-network:latest" \
                   --filter "ancestor=${IMAGE_REGISTRY}/telcochisel-device-tools:latest" | xargs -r docker stop
      printf "${GREEN}[✓] Containers stopped.${NC}\n"
      ;;
    2)
      docker compose -f "${REPO_ROOT}/docker/compose.yaml" down
      printf "${GREEN}[✓] Docker Compose stack down.${NC}\n"
      ;;
    3)
      bash "${REPO_ROOT}/docker/pods/pod-deploy.sh" stop-podman
      ;;
    4)
      kubectl delete pods -l "app.kubernetes.io/part-of=telcochisel" --ignore-not-found=true
      printf "${GREEN}[✓] Kubernetes pods deleted.${NC}\n"
      ;;
    *)
      printf "Cancelled.\n"
      ;;
  esac
}

open_academy() {
  printf "\n${AMBER}========================================================================${NC}\n"
  printf "${BOLD}             TelcoSec Academy -- Hands-On Telecom Security Training      ${NC}\n"
  printf "${AMBER}========================================================================${NC}\n\n"
  printf "  Master telecommunications and cellular security through real testbeds:\n\n"
  printf "  ${GREEN}1. Academy Learning Portal:${NC}    https://app.telcosec.net\n"
  printf "  ${GREEN}2. Interactive Courses:${NC}        https://app.telcosec.net/courses\n"
  printf "     - SS7, SIGTRAN, and Mobile Application Part (MAP) Vulnerabilities\n"
  printf "     - Diameter & LTE EPC Signaling Exploitation\n"
  printf "     - 5G Service-Based Architecture (SBA) & REST API Fuzzing\n"
  printf "     - Over-the-Air SDR & Rogue Base Station Attacks\n"
  printf "  ${GREEN}3. ProLabs Advanced Testbeds:${NC}  https://app.telcosec.net/prolabs\n"
  printf "     - Private 5G SA Core Exploit Sandbox\n"
  printf "     - IMS / VoLTE Interception & Media Bleed Laboratory\n"
  printf "  ${GREEN}4. OS Documentation & Wiki:${NC}    https://telcochisel.com\n\n"

  if [ -n "${DISPLAY:-}" ] && command -v xdg-open &>/dev/null; then
    read -rp "Open TelcoSec Academy in default browser? [Y/n]: " ans
    if [[ "$ans" =~ ^[Yy]?$ ]]; then
      xdg-open "https://app.telcosec.net" 2>/dev/null || true
    fi
  fi
}

# ─── Interactive Menu Loop ───────────────────────────────────────────────────
interactive_menu() {
  while true; do
    show_banner
    check_runtimes

    printf "${BOLD}Select an action, deployment, or build workflow:${NC}\n\n"

    printf "${CYAN}  [Docker Container Suite]${NC}\n"
    printf "    1) Base Telecom Security CLI       (SS7, Diameter, GTP, VoIP, SIM, 5G Tools)\n"
    printf "    2) SDR & RF Signal Analysis         (GNU Radio, GQRX, HackRF, BladeRF, USRP)\n"
    printf "    3) 5G/4G Core & RAN Stack           (srsRAN, Open5GS, UERANSIM, 5Ghoul)\n"
    printf "    4) Device & Baseband Analysis       (EDL, MTKClient, QCSuper, Heimdall)\n"
    printf "    5) Full Docker Compose Stack        (Deploy all 4 container tiers in background)\n\n"

    printf "${CYAN}  [Telecom POD Orchestration (K8s & Podman)]${NC}\n"
    printf "    6) 5G SA Core & UERANSIM POD        (k8s-5g-core-pod.yaml)\n"
    printf "    7) SDR RF Over-the-Air Capture POD  (k8s-sdr-rf-pod.yaml)\n"
    printf "    8) Device Firmware & Modem POD      (k8s-device-audit-pod.yaml)\n"
    printf "    9) Red Team Telecom Suite POD       (k8s-telecom-suite-pod.yaml)\n"
    printf "   10) Turnkey Rootless Podman POD      (podman-telecom-pod.yaml)\n\n"

    printf "${CYAN}  [Build Engine: ISO, VMs & WSL]${NC}\n"
    printf "   11) Build Live ISO Image             (Full Field Edition, Modular Lite, or CI)\n"
    printf "   12) Build VM Appliances              (Proxmox QCOW2, VMware, VirtualBox OVA)\n"
    printf "   13) Build WSL2 Distro Tarball        (Run TelcoChisel inside Windows WSL2)\n\n"

    printf "${CYAN}  [Host Services]${NC}\n"
    printf "   14) Host Open5GS 5G Core Daemons     (systemd / installer)\n\n"

    printf "${CYAN}  [Observability, Management & Training]${NC}\n"
    printf "   15) Inspect Status & Active Services (Live container, pod, host & artifact probe)\n"
    printf "   16) Stop / Tear Down Services        (Selective or full shutdown)\n"
    printf "   17) TelcoSec Academy & Testbeds      (Explore courses & ProLabs)\n"
    printf "   18) Exit Navigator\n\n"

    read -rp "Enter selection [1-18]: " choice
    echo ""

    case "$choice" in
      1)  deploy_docker_base ;;
      2)  deploy_docker_sdr ;;
      3)  deploy_docker_core ;;
      4)  deploy_docker_device ;;
      5)  deploy_docker_compose ;;
      6)  deploy_k8s_5g_core ;;
      7)  deploy_k8s_sdr ;;
      8)  deploy_k8s_device ;;
      9)  deploy_k8s_suite ;;
      10) deploy_podman_pod ;;
      11) iso_menu ;;
      12) vm_menu ;;
      13) build_wsl_action ;;
      14) deploy_host_open5gs ;;
      15) show_all_status ;;
      16) stop_services ;;
      17) open_academy ;;
      18|q|Q|exit)
        printf "${GREEN}Thank you for using TelcoChisel OS. Secure the signaling!${NC}\n"
        exit 0
        ;;
      *)
        printf "${RED}Invalid selection. Press Enter to retry.${NC}\n"
        ;;
    esac

    printf "\n"
    read -rp "Press Enter to return to menu..." _
  done
}

# ─── CLI Entrypoint ───────────────────────────────────────────────────────────
case "${1:-}" in
  --deploy|-d)
    target="${2:-}"
    case "$target" in
      base|docker-base)           deploy_docker_base ;;
      sdr|docker-sdr)             deploy_docker_sdr ;;
      core|core-network)          deploy_docker_core ;;
      device|device-tools)        deploy_docker_device ;;
      compose|docker-compose)     deploy_docker_compose ;;
      5g-core|k8s-5g-core)        deploy_k8s_5g_core ;;
      sdr-pod|k8s-sdr)            deploy_k8s_sdr ;;
      device-pod|k8s-device)      deploy_k8s_device ;;
      suite|k8s-suite)            deploy_k8s_suite ;;
      podman|podman-pod)          deploy_podman_pod ;;
      open5gs)                    deploy_host_open5gs ;;
      *)
        echo "Unknown service: $target" >&2
        echo "Valid targets: base, sdr, core, device, compose, 5g-core, sdr-pod, device-pod, suite, podman, open5gs" >&2
        exit 1
        ;;
    esac
    ;;

  --build-iso)
    subtarget="${2:-full}"
    case "$subtarget" in
      full)   build_iso_action full "$VERSION" ;;
      lite)   build_iso_action lite "$VERSION" ;;
      repack) build_iso_action full "$VERSION" --pack-only ;;
      ci)     trigger_ci_iso full ;;
      *)
        echo "Unknown ISO build option: $subtarget. Options: full, lite, repack, ci" >&2
        exit 1
        ;;
    esac
    ;;

  --build-vm)
    subtarget="${2:-all}"
    case "$subtarget" in
      all)        build_vm_action all "$VERSION" ;;
      proxmox)    build_vm_action proxmox "$VERSION" ;;
      vmware)     build_vm_action vmware "$VERSION" ;;
      virtualbox) build_vm_action virtualbox "$VERSION" ;;
      ci)         trigger_ci_vm all ;;
      *)
        echo "Unknown VM build option: $subtarget. Options: all, proxmox, vmware, virtualbox, ci" >&2
        exit 1
        ;;
    esac
    ;;

  --build-wsl)
    build_wsl_action
    ;;

  --status|-s|status)
    show_all_status
    ;;

  --stop|-k|stop)
    stop_services
    ;;

  --academy|academy)
    open_academy
    ;;

  --help|-h|help)
    show_banner
    cat << 'EOF'
Usage:
  ./deploy_menu.sh                          Launch interactive TUI service navigator
  ./deploy_menu.sh --deploy <target>        Deploy specific service non-interactively
  ./deploy_menu.sh --build-iso [flavor]     Build Live ISO (full, lite, repack, ci)
  ./deploy_menu.sh --build-vm [target]      Build VM appliances (all, proxmox, vmware, virtualbox, ci)
  ./deploy_menu.sh --build-wsl              Build WSL2 distro tarball
  ./deploy_menu.sh --status                 Show status of running containers, pods, services & artifacts
  ./deploy_menu.sh --stop                   Interactive teardown menu
  ./deploy_menu.sh --academy                Display TelcoSec Academy courses & ProLabs testbeds
  ./deploy_menu.sh --help                   Show this help message

Available deploy targets:
  base, sdr, core, device, compose, 5g-core, sdr-pod, device-pod, suite, podman, open5gs
EOF
    ;;

  "")
    interactive_menu
    ;;

  *)
    echo "Unknown argument: $1" >&2
    echo "Run '$0 --help' for usage." >&2
    exit 1
    ;;
esac
