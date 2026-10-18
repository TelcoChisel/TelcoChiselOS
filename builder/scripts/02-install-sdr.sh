#!/bin/bash
set -e

echo "=== Installing Conda & Compiling SDR Drivers from Source ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/record-tool.sh
source "${SCRIPT_DIR}/lib/record-tool.sh"
# shellcheck source=lib/build-tool.sh
source "${SCRIPT_DIR}/lib/build-tool.sh"

# Skip apt operations — handled by 00-install-all-packages.sh
if [ ! -f /tmp/.packages-installed ]; then
  echo "WARNING: Running standalone (packages not pre-installed)"
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential cmake git wget libusb-1.0-0-dev pkg-config
fi

# 1. Install Miniconda (version-pinned — never use Miniconda3-latest)
MINICONDA_VER="py312_26.7.1-1"
MINICONDA_INSTALLER="Miniconda3-${MINICONDA_VER}-Linux-x86_64.sh"
MINICONDA_URL="https://repo.anaconda.com/miniconda/${MINICONDA_INSTALLER}"
if [ ! -d /opt/telcosec/miniconda ]; then
  echo "Installing Miniconda ${MINICONDA_VER}..."
  wget -O /tmp/miniconda.sh "$MINICONDA_URL"
  # Verify when Anaconda publishes a companion .sha256 (hex or "hex  filename").
  if wget -q -O /tmp/miniconda.sh.sha256 "${MINICONDA_URL}.sha256" 2>/dev/null; then
    EXPECTED=$(awk '{print $1}' /tmp/miniconda.sh.sha256)
    ACTUAL=$(sha256sum /tmp/miniconda.sh | awk '{print $1}')
    if [ -z "$EXPECTED" ] || [ "$EXPECTED" != "$ACTUAL" ]; then
      echo "ERROR: Miniconda SHA256 mismatch (expected=$EXPECTED actual=$ACTUAL)" >&2
      exit 1
    fi
    echo "  Miniconda SHA256 verified: $ACTUAL"
  else
    echo "  WARNING: no .sha256 sidecar for ${MINICONDA_INSTALLER} — proceeding without verify"
  fi
  bash /tmp/miniconda.sh -b -p /opt/telcosec/miniconda
  rm -f /tmp/miniconda.sh /tmp/miniconda.sh.sha256
else
  echo "Miniconda already installed, skipping installer."
fi

# Make Conda available to all users
cat << 'EOF' | sudo tee /etc/profile.d/conda.sh
export PATH="/opt/telcosec/miniconda/bin:$PATH"
. /opt/telcosec/miniconda/etc/profile.d/conda.sh
EOF

source /opt/telcosec/miniconda/etc/profile.d/conda.sh

# Accept Terms of Service for default channels to prevent non-interactive blocks
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main || true
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r || true

# Configure Conda to use conda-forge and avoid Anaconda commercial ToS issues
conda config --add channels conda-forge
conda config --set channel_priority strict
conda config --remove channels defaults || true

# 2. Create SDR Virtual Environment
if ! conda info --envs | grep -q "telcosec-sdr"; then
  echo "Creating SDR Conda Environment..."
  conda create -y --override-channels -c conda-forge -n telcosec-sdr python=3.11 cmake ninja pkg-config boost-cpp swig pybind11 libusb mako requests numpy ruamel.yaml setuptools soapysdr
else
  echo "SDR Conda Environment already exists."
fi
conda activate telcosec-sdr

# Export compilation environment variables to prefer the Conda environment
export PKG_CONFIG_PATH="$CONDA_PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"
export CMAKE_PREFIX_PATH="$CONDA_PREFIX"

# 3. Clone SDR source repos in parallel (fail loudly if any clone fails)
echo "Cloning SDR source repositories..."
mkdir -p /opt/telcosec/src
clone_bg https://github.com/greatscottgadgets/hackrf.git        /opt/telcosec/src/hackrf      v2026.01.3
clone_bg https://github.com/EttusResearch/uhd.git               /opt/telcosec/src/uhd         v4.11.0.0
clone_bg https://github.com/steve-m/kalibrate-rtl.git          /opt/telcosec/src/kalibrate-rtl
clone_bg https://github.com/myriadrf/LimeSuite.git              /opt/telcosec/src/LimeSuite    v23.11.0

if ! wait_clones "SDR repos"; then
  echo "Aborting: one or more SDR repo clones failed" >&2
  exit 1
fi
echo "All SDR repos checked/cloned."

_sdr_cmake_make() {
  local name="$1" src_dir="$2"; shift 2
  local log="/tmp/sdr-build-${name}.log"
  local procs
  procs="$(get_build_procs)"
  printf "  [%-16s] building (jobs=%s)...\n" "$name" "$procs"
  (
    set -e
    rm -rf "${src_dir}/build"
    mkdir -p "${src_dir}/build"
    cd "${src_dir}/build"
    /usr/bin/cmake "$@"
    nice -n 10 make -j"${procs}"
  ) >"$log" 2>&1
  local rc=$?
  if [ "$rc" -eq 0 ]; then
    printf "  [%-16s] build OK\n" "$name"
  else
    printf "  [%-16s] build FAILED (rc=%d) — see %s\n" "$name" "$rc" "$log" >&2
    tail -20 "$log" >&2
  fi
  return "$rc"
}

# 4. SoapySDR core runtime & headers are provided directly by Conda
echo "Configuring SoapySDR from Conda environment..."
record_tool "SoapySDR" "${CONDA_PREFIX}/bin/SoapySDRUtil" "sdr"

# SoapyBladeRF clone (depends on SoapySDR being installed above)
echo "Cloning SoapyBladeRF..."
clone_if_missing https://github.com/pothosware/SoapyBladeRF.git /opt/telcosec/src/SoapyBladeRF || true

# 5–6. Build LimeSuite, HackRF + SoapyBladeRF, then UHD.
# Serializing UHD prevents 64-thread compiler storms that exhaust RAM and peg host CPU.
echo "Compiling LimeSuite, HackRF, SoapyBladeRF..."
_sdr_cmake_make "LimeSuite" /opt/telcosec/src/LimeSuite \
  -DCMAKE_INSTALL_PREFIX="$CONDA_PREFIX" .. &
_LIME_PID=$!

_sdr_cmake_make "HackRF" /opt/telcosec/src/hackrf/host \
  -DCMAKE_INSTALL_PREFIX="$CONDA_PREFIX" .. &
_HACKRF_PID=$!

if [ -d /opt/telcosec/src/SoapyBladeRF ]; then
  _sdr_cmake_make "SoapyBladeRF" /opt/telcosec/src/SoapyBladeRF \
    -DCMAKE_INSTALL_PREFIX="$CONDA_PREFIX" .. &
  _BLADERF_PID=$!
fi

wait "$_LIME_PID"   && _LIME_OK=1   || { _LIME_OK=0;   echo "  WARNING: LimeSuite build failed"; }
wait "$_HACKRF_PID" && _HACKRF_OK=1 || { _HACKRF_OK=0; echo "  WARNING: HackRF build failed"; }
if [ -n "${_BLADERF_PID:-}" ]; then
  wait "$_BLADERF_PID" && _BLADERF_OK=1 || { _BLADERF_OK=0; echo "  WARNING: SoapyBladeRF build failed"; }
fi

echo "Compiling UHD..."
if _sdr_cmake_make "UHD" /opt/telcosec/src/uhd/host \
  -DCMAKE_INSTALL_PREFIX="$CONDA_PREFIX" \
  -DENABLE_TESTS=OFF -DENABLE_EXAMPLES=OFF ..; then
  _UHD_OK=1
else
  _UHD_OK=0
  echo "  WARNING: UHD source build failed (will fallback to conda-forge package)"
fi

# Serialize installs to avoid write races on $CONDA_PREFIX
echo "  Installing SDR libraries (serial)..."
[ "${_UHD_OK:-0}"    = "1" ] && (cd /opt/telcosec/src/uhd/host/build       && make install) || true
[ "${_LIME_OK:-0}"   = "1" ] && (cd /opt/telcosec/src/LimeSuite/build      && make install) || true
[ "${_HACKRF_OK:-0}" = "1" ] && (cd /opt/telcosec/src/hackrf/host/build    && make install) || true
[ "${_BLADERF_OK:-0}" = "1" ] && [ -d /opt/telcosec/src/SoapyBladeRF/build ] && \
  (cd /opt/telcosec/src/SoapyBladeRF/build && make install) || true

record_tool "UHD" "${CONDA_PREFIX}/bin/uhd_usrp_probe" "sdr"
record_tool "LimeSuite" "${CONDA_PREFIX}/bin/LimeUtil" "sdr"
record_tool "HackRF" "${CONDA_PREFIX}/bin/hackrf_info" "sdr"
# SoapyBladeRF installs as a runtime-loaded SoapySDR module, not a top-level
# binary — its install path includes a SoapySDR ABI version directory
# (e.g. modules0.8) so we search for it rather than hardcoding the path.
SOAPYBLADERF_MOD=$(find "${CONDA_PREFIX}/lib" -iname '*bladerf*' -path '*SoapySDR*' 2>/dev/null | head -1)
record_tool "SoapyBladeRF" "$SOAPYBLADERF_MOD" "sdr"

# Defer uhd_images_downloader to first-run (saves ~1.5 GB ISO space and ~10 min)
echo "Creating UHD images first-run downloader..."
cat << 'FIRSTRUN' | sudo tee /usr/local/bin/uhd-download-images
#!/bin/bash
TARGET_DIR="/usr/share/uhd/images"
sudo mkdir -p "$TARGET_DIR"

if [ -d "$TARGET_DIR" ] && [ "$(ls -A "$TARGET_DIR" 2>/dev/null)" ]; then
  echo "UHD FPGA images are already installed in $TARGET_DIR (offline ready)."
  ls -lh "$TARGET_DIR"/*.bin 2>/dev/null | head -5 || true
  read -rp "Re-download UHD images? [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]] || exit 0
fi

echo "=== Downloading UHD FPGA Images ==="
echo "Note: pass '--types b2xx' for quick download of B200/B210 images only (~30 MB)"
source /opt/telcosec/miniconda/etc/profile.d/conda.sh
conda activate telcosec-sdr 2>/dev/null || true
uhd_images_downloader "$@"
echo "UHD images downloaded successfully to $TARGET_DIR."
FIRSTRUN
sudo chmod +x /usr/local/bin/uhd-download-images

# Defer BladeRF FPGA images to first-run downloader
echo "Creating BladeRF FPGA images first-run downloader..."
sudo mkdir -p /usr/share/Nuand/bladeRF /lib/firmware/nuand
cat << 'FIRSTRUN_BLADERF' | sudo tee /usr/local/bin/bladerf-download-images
#!/bin/bash
set -e
echo "=== Nuand BladeRF FPGA Images & Firmware Manager ==="
TARGET_DIR="/usr/share/Nuand/bladeRF"
FW_DIR="/lib/firmware/nuand"
sudo mkdir -p "$TARGET_DIR" "$FW_DIR"

# Check if offline cached files exist in local directory or /tmp/firmware
if [ -d "/tmp/firmware/bladeRF" ]; then
  echo "Found local offline firmware cache in /tmp/firmware/bladeRF! Copying..."
  sudo cp -rn /tmp/firmware/bladeRF/* "$TARGET_DIR/" 2>/dev/null || true
fi

BASE_URL="https://www.nuand.com/fpga"
# Latest hosted images for BladeRF 2.0 micro (xA4, xA9) and BladeRF Classic (x40, x115)
IMAGES=(
  "v0.15.3/hostedxA4.rbf"
  "v0.15.3/hostedxA9.rbf"
  "v0.15.3/hostedx40.rbf"
  "v0.15.3/hostedx115.rbf"
)

for img in "${IMAGES[@]}"; do
  fname=$(basename "$img")
  if [ -s "${TARGET_DIR}/${fname}" ]; then
    echo "  [OK] $fname already present (offline ready)."
  else
    echo "Downloading $fname..."
    curl -fsSL "${BASE_URL}/${img}" -o "${TARGET_DIR}/${fname}" || \
      echo "  WARNING: Failed to download $fname (check internet connectivity)"
  fi
done

# Create default hosted.rbf symlink pointing to hostedxA4.rbf
if [ -f "${TARGET_DIR}/hostedxA4.rbf" ]; then
  ln -sf "${TARGET_DIR}/hostedxA4.rbf" "${TARGET_DIR}/hosted.rbf"
fi

# Download latest FX3 firmware
if [ -s "${TARGET_DIR}/bladeRF_fw.img" ]; then
  echo "  [OK] BladeRF FX3 firmware already present."
else
  echo "Downloading BladeRF FX3 firmware..."
  curl -fsSL "https://www.nuand.com/fx3/bladeRF_fw_latest.img" -o "${TARGET_DIR}/bladeRF_fw.img" 2>/dev/null || true
fi

if [ -f "${TARGET_DIR}/bladeRF_fw.img" ]; then
  cp -f "${TARGET_DIR}/bladeRF_fw.img" "${FW_DIR}/bladeRF.img" 2>/dev/null || true
fi

sudo chmod 644 "${TARGET_DIR}"/* 2>/dev/null || true
echo "✓ BladeRF FPGA & firmware check complete."
echo "✓ BladeRF FPGA images and firmware installed in $TARGET_DIR"
FIRSTRUN_BLADERF
sudo chmod +x /usr/local/bin/bladerf-download-images

# 7. Install GNU Radio ecosystem into conda env
# gqrx-sdr, gr-osmosdr, gr-gsm removed from system apt (librtlsdr ABI conflict
# between librtlsdr0/soname-0 and librtlsdr2/soname-2 in Ubuntu 24.04 Noble).
# conda-forge packages resolve their own ABIs cleanly.
echo "Installing GNU Radio ecosystem into conda env..."
# Single transaction — each separate `conda install` re-runs the solver
# (1–5 min per pass). One solve for the whole ecosystem.
conda install -y --override-channels -c conda-forge \
  rtl-sdr gnuradio gqrx gnuradio-osmosdr \
  soapysdr-module-rtlsdr soapysdr-module-hackrf soapysdr-module-uhd \
  soapysdr-module-lms7 soapysdr-module-remote 2>/dev/null || \
  echo "  WARNING: conda GNU Radio ecosystem install failed (non-fatal)"

# If the conda transaction failed and rtl-sdr headers are absent, build
# librtlsdr from source directly into the conda env. This is the guaranteed
# fallback that always works.
if [ ! -f "${CONDA_PREFIX}/include/rtl-sdr.h" ]; then
  echo "  Building librtlsdr from source into conda env..."
  clone_if_missing https://github.com/osmocom/rtl-sdr /opt/telcosec/src/librtlsdr || true
  if [ -d /opt/telcosec/src/librtlsdr ]; then
    cmake -S /opt/telcosec/src/librtlsdr -B /opt/telcosec/src/librtlsdr/build \
      -DCMAKE_INSTALL_PREFIX="${CONDA_PREFIX}" \
      -DDETACH_KERNEL_DRIVER=ON \
      -DCMAKE_BUILD_TYPE=Release >/dev/null 2>&1
    make -C /opt/telcosec/src/librtlsdr/build -j"$(nproc)" >/dev/null 2>&1
    make -C /opt/telcosec/src/librtlsdr/build install >/dev/null 2>&1 && \
      echo "  librtlsdr source build complete — rtl-sdr.h now available"
  fi
fi
record_tool "librtlsdr" "${CONDA_PREFIX}/include/rtl-sdr.h" "sdr"

# gr-gsm (deferred: setup tool). gr-gsm is not on conda-forge and its cmake
# app-codegen (.py.in -> .py for grgsm_scanner etc.) is incompatible with the
# conda GNU Radio 3.10 in this env — make install silently skipped the apps,
# so the build-time install was unreliable. Build on first run via
# `sudo grgsm-install`, which compiles against whatever GNU Radio is present.
echo "Creating gr-gsm first-run installer..."
cat << 'GRGSM' | sudo tee /usr/local/bin/grgsm-install >/dev/null
#!/bin/bash
set -e
OPT=/opt/telcosec
PREFIX=/opt/telcosec/miniconda/envs/telcosec-sdr
source /opt/telcosec/miniconda/etc/profile.d/conda.sh
conda activate telcosec-sdr
if [ ! -d "$OPT/src/gr-gsm/.git" ] && [ ! -f "$OPT/src/gr-gsm/CMakeLists.txt" ]; then
  git clone https://github.com/bkerler/gr-gsm "$OPT/src/gr-gsm"
fi
cmake -S "$OPT/src/gr-gsm" -B "$OPT/src/gr-gsm/build" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CXX_FLAGS="-std=c++17 -Wno-error" -DCMAKE_C_FLAGS="-Wno-error -fcommon" \
  -DCMAKE_MODULE_PATH="$PREFIX/lib/cmake/gnuradio"
make -C "$OPT/src/gr-gsm/build" -j"$(nproc)"
make -C "$OPT/src/gr-gsm/build" install
if [ -f "$PREFIX/bin/grgsm_scanner" ]; then
  echo "gr-gsm installed: run 'grgsm_scanner' / 'grgsm_livemon'"
else
  echo "ERROR: gr-gsm build did not produce grgsm_scanner" >&2; exit 1
fi
GRGSM
sudo chmod +x /usr/local/bin/grgsm-install
record_tool "gr-gsm" "/usr/local/bin/grgsm-install" "2g"
# Also re-verify UHD now that Conda gnuradio packages have landed
record_tool "UHD" "$(command -v uhd_usrp_probe 2>/dev/null || find "${CONDA_PREFIX}/bin" /usr/bin -name 'uhd_usrp_probe' 2>/dev/null | head -1)" "sdr"

# 8. Compile and Install Kalibrate-RTL from Source
echo "Compiling and installing Kalibrate-RTL..."
if [ ! -f "${CONDA_PREFIX}/include/rtl-sdr.h" ]; then
  echo "  WARNING: rtl-sdr.h not found in conda env — skipping kalibrate-rtl build"
else
  cd /opt/telcosec/src/kalibrate-rtl
  ./bootstrap
  # Bypass pkg-config for both librtlsdr (conda, no .pc file) and fftw3 (system,
  # hidden when conda sets PKG_CONFIG_LIBDIR and overrides default search paths).
  # -rpath embeds the conda lib path into the kal binary itself, since it
  # installs to /usr/local (system-wide) but links against a library that
  # only exists in the conda env — without it, kal fails at runtime with
  # "librtlsdr.so.0: cannot open shared object file" outside an activated
  # conda shell (e.g. when launched from a plain gnome-terminal).
  LIBRTLSDR_CFLAGS="-I${CONDA_PREFIX}/include" \
  LIBRTLSDR_LIBS="-L${CONDA_PREFIX}/lib -lrtlsdr -Wl,-rpath,${CONDA_PREFIX}/lib" \
  FFTW3_CFLAGS="-I/usr/include" \
  FFTW3_LIBS="-lfftw3 -lm" \
    ./configure
  make -j$(nproc)
  sudo make install
  cd -
fi
record_tool "kalibrate-rtl" "/usr/local/bin/kal" "2g"

# GUI desktop launchers (.desktop Exec=) run outside any login shell so the
# conda env is never activated. For ELF binaries (gqrx, gnuradio-companion)
# a symlink works once we embed the rpath; for Python scripts installed by
# gr-gsm (grgsm_livemon, grgsm_scanner) the shebang points to the conda
# Python, which can't import gnuradio blocks unless the conda env is active.
# Use wrapper scripts that activate the env before exec'ing the tool — this
# also avoids the conditional symlink silently doing nothing when a gr-gsm
# cmake build fails.
for bin in gqrx gnuradio-companion; do
  if [ -f "${CONDA_PREFIX}/bin/${bin}" ]; then
    sudo tee "/usr/local/bin/${bin}" > /dev/null << WRAPPER
#!/bin/bash
source /opt/telcosec/miniconda/etc/profile.d/conda.sh
conda activate telcosec-sdr 2>/dev/null
exec "${CONDA_PREFIX}/bin/${bin}" "\$@"
WRAPPER
    sudo chmod +x "/usr/local/bin/${bin}"
  fi
done
record_tool "gqrx" "${CONDA_PREFIX}/bin/gqrx" "sdr"
record_tool "gnuradio-companion" "${CONDA_PREFIX}/bin/gnuradio-companion" "sdr"

# Only write the grgsm_* wrappers if the underlying conda binaries actually
# exist — the gr-gsm build above is entirely best-effort (`|| true`), so
# writing these unconditionally would ship a launcher that always errors
# when the build failed. Users would have no way to tell "not built" apart
# from "broken."
for bin in grgsm_livemon grgsm_scanner; do
  if [ -f "${CONDA_PREFIX}/bin/${bin}" ]; then
    sudo tee "/usr/local/bin/${bin}" > /dev/null << WRAPPER
#!/bin/bash
source /opt/telcosec/miniconda/etc/profile.d/conda.sh
conda activate telcosec-sdr 2>/dev/null
exec "${CONDA_PREFIX}/bin/${bin}" "\$@"
WRAPPER
    sudo chmod +x "/usr/local/bin/${bin}"
  else
    echo "  WARNING: ${bin} not found in conda env — skipping wrapper (gr-gsm build likely failed)"
  fi
done

# Surface the core SDR CLIs outside the conda env (they carry an embedded rpath).
for bin in hackrf_info hackrf_transfer uhd_usrp_probe uhd_find_devices \
           SoapySDRUtil rtl_test rtl_sdr rtl_fm LimeUtil; do
  [ -f "${CONDA_PREFIX}/bin/${bin}" ] && \
    sudo ln -sf "${CONDA_PREFIX}/bin/${bin}" "/usr/local/bin/${bin}"
done

# Deploy global sdr-info diagnostic helper
echo "Creating SDR hardware discovery helper (sdr-info)..."
cat << 'EOF' | sudo tee /usr/local/bin/sdr-info > /dev/null
#!/bin/bash
echo "=== TelcoChisel SDR Transceiver Discovery & Driver Status ==="
echo ""
echo "--- USB Connected Radio Devices ---"
lsusb | grep -iE "ettus|usrp|hackrf|bladerf|limesdr|rtl2832|realtek" || echo "No recognized USB SDR devices detected."
echo ""
echo "--- SoapySDR Hardware Probe ---"
if command -v SoapySDRUtil >/dev/null 2>&1; then
  SoapySDRUtil --find || true
else
  echo "SoapySDRUtil not available."
fi
echo ""
echo "--- HackRF Info ---"
if command -v hackrf_info >/dev/null 2>&1; then
  hackrf_info 2>&1 | head -n 10 || true
fi
echo ""
echo "--- USRP Device Probe ---"
if command -v uhd_find_devices >/dev/null 2>&1; then
  uhd_find_devices 2>&1 | head -n 10 || true
fi
echo ""
echo "--- LimeSDR Device Probe ---"
if command -v LimeUtil >/dev/null 2>&1; then
  LimeUtil --find || true
fi
EOF
sudo chmod +x /usr/local/bin/sdr-info

record_tool "sdr-info" "/usr/local/bin/sdr-info" "sdr"

# Install Universal Radio Hacker (URH) into the telcosec-sdr conda environment
echo "Installing Universal Radio Hacker (URH) in telcosec-sdr conda env..."
conda run -n telcosec-sdr pip install --no-cache-dir urh || {
  echo "  WARNING: Failed to pip install urh in conda env"
}

# Create wrapper for URH
cat << 'WRAPPER' | sudo tee /usr/local/bin/urh > /dev/null
#!/bin/bash
source /opt/telcosec/miniconda/etc/profile.d/conda.sh
conda activate telcosec-sdr 2>/dev/null
exec urh "$@"
WRAPPER
sudo chmod +x /usr/local/bin/urh
record_tool "URH" "/usr/local/bin/urh" "sdr"

# Set permissions
sudo chown -R telcosec:telcosec /opt/telcosec
