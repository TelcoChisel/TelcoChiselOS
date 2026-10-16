#!/bin/bash
# =============================================================================
# docker/scripts/20-sdr.sh — telcochisel-sdr image contents
#
# Runs as root during `docker build`, FROM telcochisel-base. Mirrors (not
# sources) builder/scripts/02-install-sdr.sh: Miniconda + the telcosec-sdr
# env, SoapySDR/UHD/LimeSuite/HackRF/SoapyBladeRF/rtl-sdr built from source,
# GNU Radio + GQRX via conda, gr-gsm and kalibrate-rtl built against the env.
#
# Needs --device /dev/bus/usb (or --privileged) at `docker run` time to reach
# real SDR hardware, and an X11 socket mount for gqrx/gnuradio-companion —
# see docker/README.md. udev rules (builder/udev/50-telcosec-hw.rules) are
# NOT installed here — a container has no udev; device permissions come from
# the --device flag / host udev instead.
# =============================================================================
set -e

LIB=/opt/telcosec/lib
TELCOSEC_OPT=/opt/telcosec
CONDA_ROOT=/opt/telcosec/miniconda
# shellcheck source=00-container-common.sh
source "${LIB}/00-container-common.sh"
# shellcheck source=../../builder/scripts/lib/record-tool.sh
source "${LIB}/record-tool.sh"
# shellcheck source=../../builder/scripts/lib/packages.sh
source "${LIB}/packages.sh"

suppress_services

# ─── 1. APT packages (PKGS_SDR, filtered, + BladeRF libs from PKGS_CORE_NETWORK) ──
echo "=== Installing SDR APT packages ==="
apt-get update
mapfile -t FILTERED_PKGS < <(filter_pkgs "${PKGS_SDR[@]}")
apt_retry install -y --no-install-recommends \
  "${FILTERED_PKGS[@]}" \
  libbladerf2 libbladerf-dev bladerf \
  build-essential
rm -rf /var/lib/apt/lists/*

# ─── 2. Miniconda + telcosec-sdr env ────────────────────────────────────────
MINICONDA_VER="py312_26.7.1-1"
MINICONDA_INSTALLER="Miniconda3-${MINICONDA_VER}-Linux-x86_64.sh"
MINICONDA_URL="https://repo.anaconda.com/miniconda/${MINICONDA_INSTALLER}"
echo "Installing Miniconda ${MINICONDA_VER}..."
wget -q -O /tmp/miniconda.sh "$MINICONDA_URL"
if wget -q -O /tmp/miniconda.sh.sha256 "${MINICONDA_URL}.sha256" 2>/dev/null; then
  EXPECTED=$(awk '{print $1}' /tmp/miniconda.sh.sha256)
  ACTUAL=$(sha256sum /tmp/miniconda.sh | awk '{print $1}')
  if [ -z "$EXPECTED" ] || [ "$EXPECTED" != "$ACTUAL" ]; then
    echo "ERROR: Miniconda SHA256 mismatch" >&2
    exit 1
  fi
fi
bash /tmp/miniconda.sh -b -p "$CONDA_ROOT"
rm /tmp/miniconda.sh

cat > /etc/profile.d/conda.sh << EOF
export PATH="${CONDA_ROOT}/bin:\$PATH"
. ${CONDA_ROOT}/etc/profile.d/conda.sh
EOF

source "${CONDA_ROOT}/etc/profile.d/conda.sh"
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main || true
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r || true
conda config --add channels conda-forge
conda config --set channel_priority strict
conda config --remove channels defaults || true

conda create -y --override-channels -c conda-forge -n telcosec-sdr \
  python=3.11 cmake ninja pkg-config boost-cpp swig pybind11 libusb mako \
  requests numpy ruamel.yaml setuptools
conda activate telcosec-sdr

export PKG_CONFIG_PATH="$CONDA_PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"
export CMAKE_PREFIX_PATH="$CONDA_PREFIX"

# ─── 3. Clone SDR source repos in parallel ──────────────────────────────────
mkdir -p "${TELCOSEC_OPT}/src"
git_clone_retry --depth 1 https://github.com/pothosware/SoapySDR.git "${TELCOSEC_OPT}/src/SoapySDR" &
{ git_clone_retry --depth 1 --branch v2026.01.3 https://github.com/greatscottgadgets/hackrf.git "${TELCOSEC_OPT}/src/hackrf" \
  || git_clone_retry --depth 1 https://github.com/greatscottgadgets/hackrf.git "${TELCOSEC_OPT}/src/hackrf"; } &
{ git_clone_retry --depth 1 --branch v4.11.0.0 https://github.com/EttusResearch/uhd.git "${TELCOSEC_OPT}/src/uhd" \
  || git_clone_retry --depth 1 https://github.com/EttusResearch/uhd.git "${TELCOSEC_OPT}/src/uhd"; } &
git_clone_retry --depth 1 https://github.com/steve-m/kalibrate-rtl.git "${TELCOSEC_OPT}/src/kalibrate-rtl" &
{ git_clone_retry --depth 1 --branch v23.11.0 https://github.com/myriadrf/LimeSuite.git "${TELCOSEC_OPT}/src/LimeSuite" \
  || git_clone_retry --depth 1 https://github.com/myriadrf/LimeSuite.git "${TELCOSEC_OPT}/src/LimeSuite"; } &
wait

_sdr_cmake_make() {
  local name="$1" src_dir="$2"; shift 2
  local log="/tmp/sdr-build-${name}.log"
  printf "  [%-16s] building...\n" "$name"
  (
    set -e
    rm -rf "${src_dir}/build"
    mkdir -p "${src_dir}/build"
    cd "${src_dir}/build"
    cmake "$@"
    make -j"$(nproc)"
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

# ─── 4. SoapySDR (must install before plugins) ──────────────────────────────
_sdr_cmake_make "SoapySDR" "${TELCOSEC_OPT}/src/SoapySDR" \
  -DCMAKE_INSTALL_PREFIX="$CONDA_PREFIX" ..
(cd "${TELCOSEC_OPT}/src/SoapySDR/build" && make install)
record_tool "SoapySDR" "${CONDA_PREFIX}/bin/SoapySDRUtil" "sdr"

git_clone_retry --depth 1 https://github.com/pothosware/SoapyBladeRF.git \
  "${TELCOSEC_OPT}/src/SoapyBladeRF" 2>/dev/null || true

# ─── 5. UHD, LimeSuite, HackRF, SoapyBladeRF in parallel ────────────────────
_sdr_cmake_make "UHD" "${TELCOSEC_OPT}/src/uhd/host" \
  -DCMAKE_INSTALL_PREFIX="$CONDA_PREFIX" -DENABLE_TESTS=OFF -DENABLE_EXAMPLES=OFF .. &
_UHD_PID=$!
_sdr_cmake_make "LimeSuite" "${TELCOSEC_OPT}/src/LimeSuite" \
  -DCMAKE_INSTALL_PREFIX="$CONDA_PREFIX" .. &
_LIME_PID=$!
_sdr_cmake_make "HackRF" "${TELCOSEC_OPT}/src/hackrf/host" \
  -DCMAKE_INSTALL_PREFIX="$CONDA_PREFIX" .. &
_HACKRF_PID=$!
if [ -d "${TELCOSEC_OPT}/src/SoapyBladeRF" ]; then
  _sdr_cmake_make "SoapyBladeRF" "${TELCOSEC_OPT}/src/SoapyBladeRF" \
    -DCMAKE_INSTALL_PREFIX="$CONDA_PREFIX" .. &
  _BLADERF_PID=$!
fi

wait "$_UHD_PID"    && _UHD_OK=1    || { _UHD_OK=0;    echo "  WARNING: UHD build failed"; }
wait "$_LIME_PID"   && _LIME_OK=1   || { _LIME_OK=0;   echo "  WARNING: LimeSuite build failed"; }
wait "$_HACKRF_PID" && _HACKRF_OK=1 || { _HACKRF_OK=0; echo "  WARNING: HackRF build failed"; }
if [ -n "${_BLADERF_PID:-}" ]; then
  wait "$_BLADERF_PID" && _BLADERF_OK=1 || { _BLADERF_OK=0; echo "  WARNING: SoapyBladeRF build failed"; }
fi

[ "${_UHD_OK:-0}"     = "1" ] && (cd "${TELCOSEC_OPT}/src/uhd/host/build"    && make install) || true
[ "${_LIME_OK:-0}"    = "1" ] && (cd "${TELCOSEC_OPT}/src/LimeSuite/build"   && make install) || true
[ "${_HACKRF_OK:-0}"  = "1" ] && (cd "${TELCOSEC_OPT}/src/hackrf/host/build" && make install) || true
[ "${_BLADERF_OK:-0}" = "1" ] && [ -d "${TELCOSEC_OPT}/src/SoapyBladeRF/build" ] && \
  (cd "${TELCOSEC_OPT}/src/SoapyBladeRF/build" && make install) || true

record_tool "UHD" "${CONDA_PREFIX}/bin/uhd_usrp_probe" "sdr"
record_tool "LimeSuite" "${CONDA_PREFIX}/bin/LimeUtil" "sdr"
record_tool "HackRF" "${CONDA_PREFIX}/bin/hackrf_info" "sdr"
SOAPYBLADERF_MOD=$(find "${CONDA_PREFIX}/lib" -iname '*bladerf*' -path '*SoapySDR*' 2>/dev/null | head -1)
record_tool "SoapyBladeRF" "$SOAPYBLADERF_MOD" "sdr"

# Deferred UHD FPGA images downloader (saves ~1.5 GB / ~10 min)
cat > /usr/local/bin/uhd-download-images << FIRSTRUN
#!/bin/bash
echo "Downloading UHD FPGA images (~1.5 GB)..."
source ${CONDA_ROOT}/etc/profile.d/conda.sh
conda activate telcosec-sdr 2>/dev/null || true
uhd_images_downloader
FIRSTRUN
chmod +x /usr/local/bin/uhd-download-images

# ─── 6. GNU Radio ecosystem ──────────────────────────────────────────────────
conda install -y --override-channels -c conda-forge rtl-sdr 2>/dev/null || \
  echo "  WARNING: rtl-sdr conda install failed — will try source build below"

if [ ! -f "${CONDA_PREFIX}/include/rtl-sdr.h" ]; then
  git_clone_retry --depth 1 https://github.com/osmocom/rtl-sdr "${TELCOSEC_OPT}/src/librtlsdr" 2>/dev/null || true
  if [ -d "${TELCOSEC_OPT}/src/librtlsdr" ]; then
    cmake -S "${TELCOSEC_OPT}/src/librtlsdr" -B "${TELCOSEC_OPT}/src/librtlsdr/build" \
      -DCMAKE_INSTALL_PREFIX="${CONDA_PREFIX}" -DDETACH_KERNEL_DRIVER=ON \
      -DCMAKE_BUILD_TYPE=Release >/dev/null 2>&1
    make -C "${TELCOSEC_OPT}/src/librtlsdr/build" -j"$(nproc)" >/dev/null 2>&1
    make -C "${TELCOSEC_OPT}/src/librtlsdr/build" install >/dev/null 2>&1 || true
  fi
fi
record_tool "librtlsdr" "${CONDA_PREFIX}/include/rtl-sdr.h" "sdr"

conda install -y --override-channels -c conda-forge gnuradio gqrx 2>/dev/null || \
  echo "  WARNING: conda gnuradio/gqrx install failed (non-fatal)"
conda install -y --override-channels -c conda-forge gr-osmosdr 2>/dev/null || \
  echo "  INFO: gr-osmosdr not on conda-forge — skipping (gr-gsm built from source below)"

git_clone_retry --depth 1 https://github.com/bkerler/gr-gsm "${TELCOSEC_OPT}/src/gr-gsm" 2>/dev/null || true
if [ -d "${TELCOSEC_OPT}/src/gr-gsm" ]; then
  cmake -S "${TELCOSEC_OPT}/src/gr-gsm" -B "${TELCOSEC_OPT}/src/gr-gsm/build" \
    -DCMAKE_INSTALL_PREFIX="$CONDA_PREFIX" -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_MODULE_PATH="$CONDA_PREFIX/lib/cmake/gnuradio" >/dev/null 2>&1 || true
  make -C "${TELCOSEC_OPT}/src/gr-gsm/build" -j"$(nproc)" >/dev/null 2>&1 || true
  make -C "${TELCOSEC_OPT}/src/gr-gsm/build" install >/dev/null 2>&1 || true
fi
record_tool "gr-gsm" "${CONDA_PREFIX}/bin/grgsm_scanner" "2g"

# ─── 7. Kalibrate-RTL ────────────────────────────────────────────────────────
if [ ! -f "${CONDA_PREFIX}/include/rtl-sdr.h" ]; then
  echo "  WARNING: rtl-sdr.h not found in conda env — skipping kalibrate-rtl build"
else
  cd "${TELCOSEC_OPT}/src/kalibrate-rtl"
  ./bootstrap
  LIBRTLSDR_CFLAGS="-I${CONDA_PREFIX}/include" \
  LIBRTLSDR_LIBS="-L${CONDA_PREFIX}/lib -lrtlsdr -Wl,-rpath,${CONDA_PREFIX}/lib" \
  FFTW3_CFLAGS="-I/usr/include" \
  FFTW3_LIBS="-lfftw3 -lm" \
    ./configure
  make -j"$(nproc)"
  make install
fi
record_tool "kalibrate-rtl" "/usr/local/bin/kal" "2g"

# ─── 8. CLI wrappers that activate the conda env before exec'ing ───────────
# (GUI .desktop launchers from the ISO don't apply here — X11 passthrough
# users invoke these same wrapper binaries directly; see docker/README.md.)
for bin in gqrx gnuradio-companion; do
  [ -f "${CONDA_PREFIX}/bin/${bin}" ] && ln -sf "${CONDA_PREFIX}/bin/${bin}" "/usr/local/bin/${bin}"
done
record_tool "gqrx" "${CONDA_PREFIX}/bin/gqrx" "sdr"

for bin in grgsm_livemon grgsm_scanner; do
  if [ -f "${CONDA_PREFIX}/bin/${bin}" ]; then
    cat > "/usr/local/bin/${bin}" << WRAPPER
#!/bin/bash
source ${CONDA_ROOT}/etc/profile.d/conda.sh
conda activate telcosec-sdr 2>/dev/null
exec "${CONDA_PREFIX}/bin/${bin}" "\$@"
WRAPPER
    chmod +x "/usr/local/bin/${bin}"
  fi
done

# ─── 9. Conda cache pruning, build artifact cleanup & healthcheck ───────────
echo "Pruning conda package caches and temporary build trees..."
conda clean -afy 2>/dev/null || true
find "${TELCOSEC_OPT}/src" -maxdepth 3 -name "build" -type d -exec rm -rf {} + 2>/dev/null || true
rm -rf /root/.cache /home/telcosec/.cache /tmp/* /var/tmp/*

# ─── 10. Ownership + tool-manifest summary ──────────────────────────────────
install_container_healthcheck
chown -R telcosec:telcosec "${TELCOSEC_OPT}"
record_tool_summary

echo "=== telcochisel-sdr installation complete ==="
