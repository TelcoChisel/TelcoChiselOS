#!/bin/bash
set -e

echo "=== Configuring Core Network Stack (srsRAN + Open5GS first-run helpers) ==="

# Skip apt operations — handled by 00-install-all-packages.sh
if [ ! -f /tmp/.packages-installed ]; then
  echo "WARNING: Running standalone (packages not pre-installed)"
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # shellcheck source=lib/packages.sh
  source "${SCRIPT_DIR}/lib/packages.sh"
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${PKGS_CORE_NETWORK[@]}"
  sudo update-alternatives --install /usr/bin/clang   clang   /usr/bin/clang-15   100 || true
  sudo update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-15 100 || true
  sudo update-alternatives --install /usr/bin/lld     lld     /usr/bin/lld-15     100 || true
fi

# srsRAN — no Ubuntu 24.04 noble apt package available.
# Install a first-run build script at /usr/local/bin/srsran-install.
# Users run: sudo srsran-install
echo "Creating srsRAN first-run build script..."
cat << 'SRSRAN_SCRIPT' | sudo tee /usr/local/bin/srsran-install
#!/bin/bash
set -e
INSTALL_DIR="/opt/telcosec/srsRAN_Project"
echo "╔══════════════════════════════════════════════╗"
echo "║   srsRAN Project Builder                    ║"
echo "║   https://github.com/srsran/srsRAN_Project  ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo srsran-install"
  exit 1
fi
if [ ! -d "$INSTALL_DIR/.git" ]; then
  echo "[1/3] Cloning srsRAN_Project..."
  # Pin to a released tag; fall back to default branch if the tag disappears.
  if ! git clone --depth 1 --branch release_25_10 --recurse-submodules \
      https://github.com/srsran/srsRAN_Project.git "$INSTALL_DIR"; then
    echo "[1/3] release_25_10 unavailable — cloning default branch"
    git clone --depth 1 --recurse-submodules https://github.com/srsran/srsRAN_Project.git "$INSTALL_DIR"
  fi
else
  echo "[1/3] Already cloned — leaving existing checkout (no floating pull)"
fi
cd "$INSTALL_DIR"
mkdir -p build && cd build
echo "[2/3] Configuring with cmake..."
cmake ../ -DENABLE_EXPORT=ON -DENABLE_ZEROMQ=ON
echo "[3/3] Compiling (this takes 10-20 min)..."
make -j$(nproc)
make install
echo ""
echo "✓ srsRAN installed. Run: srsgnb --help"
SRSRAN_SCRIPT
sudo chmod +x /usr/local/bin/srsran-install

# Open5GS — Dockerized deployment to keep the host OS clean and prevent dependency conflicts
echo "Creating Open5GS first-run install script..."
cat << 'OPEN5GS_SCRIPT' | sudo tee /usr/local/bin/open5gs-install
#!/bin/bash
set -e
echo "╔══════════════════════════════════════════════╗"
echo "║   Open5GS 5G SA Core Docker Installer      ║"
echo "║   https://open5gs.org                        ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo open5gs-install"
  exit 1
fi

echo "Setting up Open5GS Docker environment..."
mkdir -p /opt/telcosec/open5gs
cd /opt/telcosec/open5gs

# Pin docker_open5gs to a known commit (repo has no release tags).
OPEN5GS_DOCKER_SHA="1f3bcf73f926b5b7526ef3c41cd2b839c2b17ac3"
if [ ! -d "/opt/telcosec/open5gs/docker_open5gs/.git" ]; then
  git clone https://github.com/herlesupreeth/docker_open5gs
  git -C docker_open5gs checkout "$OPEN5GS_DOCKER_SHA" \
    || echo "WARNING: could not checkout $OPEN5GS_DOCKER_SHA — using clone HEAD"
else
  echo "docker_open5gs already present — leaving checkout (expected $OPEN5GS_DOCKER_SHA)"
fi

cd docker_open5gs
echo "Pulling Open5GS Docker images..."
docker compose pull || docker-compose pull

echo "Patching PLMN to 5Ghoul default test PLMN (MCC 001, MNC 01)..."
if [ -f .env ]; then
  sed -i 's/MCC=.*/MCC=001/g' .env
  sed -i 's/MNC=.*/MNC=01/g' .env
fi

echo "Enable IP forwarding for UPF data plane..."
cat > /etc/sysctl.d/99-open5gs.conf << 'SYSCTL'
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
SYSCTL
sysctl -p /etc/sysctl.d/99-open5gs.conf || true

echo ""
echo "✓ Open5GS Dockerized environment installed."
echo "  Start:  sudo open5gs-start"
echo "  Stop:   sudo open5gs-stop"
echo "  Logs:   sudo open5gs-logs"
echo "  Add UE: sudo 5ghoul-add-subscriber (or use the webui on http://localhost:3000)"
OPEN5GS_SCRIPT
sudo chmod +x /usr/local/bin/open5gs-install

echo "=== Core network stack configured ==="
