#!/bin/bash
# =============================================================================
# docker/scripts/10-base-tools.sh — telcochisel-base image contents
#
# Runs as root during `docker build`. Installs the headless CLI subset of the
# TelcoChisel toolset: protocol scanners, SS7/Diameter/GTP exploitation,
# baseband/SIM analysis, and 5G UE/gNB simulation tools that need no special
# runtime privileges (USB/kernel-module/systemd tools live in the sdr,
# core-network, and device-tools add-on images instead — see docker/README.md).
#
# This is a FRESH script, not sourced from builder/scripts/04-install-tools.sh,
# 06-install-ue-analysis.sh, or 10-install-telecom-advanced.sh — but every
# build step below is copied from (not reinvented over) those scripts, with
# sudo/chown telcosec/systemctl/udev/.desktop-launcher lines dropped since
# they don't apply in a container build. See docker/scripts/lib/packages.sh
# consumers (this file) vs. builder/scripts/lib/packages.sh (source of truth)
# in the plan doc for the full reuse boundary.
# =============================================================================
set -e

LIB=/opt/telcosec/lib
TELCOSEC_OPT=/opt/telcosec
# shellcheck source=00-container-common.sh
source "${LIB}/00-container-common.sh"
# shellcheck source=../../builder/scripts/lib/pip-retry.sh
source "${LIB}/pip-retry.sh"
# shellcheck source=../../builder/scripts/lib/record-tool.sh
source "${LIB}/record-tool.sh"
# shellcheck source=../../builder/scripts/lib/packages.sh
source "${LIB}/packages.sh"

suppress_services

mkdir -p "$TELCOSEC_OPT"

# ─── 1. APT packages (PKGS_TOOLS + PKGS_UE_ANALYSIS, container-filtered) ────
# git itself comes from this install — the git config/env below must run
# AFTER it, not before.
echo "=== Installing base APT packages ==="
apt-get update

# Explicitly track build dependencies to purge later, keeping runtime slim
BUILD_DEPS=(
  build-essential cmake pkg-config autoconf automake libtool
  python3-dev libusb-1.0-0-dev libmnl-dev libssl-dev libncurses-dev
  libsctp-dev libglib2.0-dev libpcsclite-dev librocksdb-dev libmd-dev libfftw3-dev
  bison flex libpcap-dev libsnmp-dev libgsl-dev libnet1-dev libmbedtls-dev libhackrf-dev
)

# Explicitly install runtime shared libraries so purging -dev packages does not remove them
RUNTIME_LIBRARIES=(
  libglib2.0-0t64 libsctp1 libusb-1.0-0 libmnl0 libncurses6
  libpcsclite1 libmd0 libfftw3-double3 libpcap0.8t64 libgsl27 libgslcblas0
  libhackrf0 libmbedcrypto7t64 libmbedtls14t64 libmbedx509-1t64
)

apt_retry install -y --no-install-recommends \
  ca-certificates curl wget gnupg git vim nano \
  tini python3-pip python3-venv \
  sudo unzip openjdk-17-jre-headless \
  "${BUILD_DEPS[@]}" \
  "${RUNTIME_LIBRARIES[@]}"

mapfile -t FILTERED_PKGS < <(filter_pkgs "${PKGS_TOOLS[@]}" "${PKGS_UE_ANALYSIS[@]}")
apt_retry install -y --no-install-recommends "${FILTERED_PKGS[@]}"

# Install official TelcoChisel base configuration if meta repository is configured
if [ -f /etc/apt/sources.list.d/telcochisel.sources ]; then
  apt_retry install -y --no-install-recommends telcochisel-base || true
fi

export GIT_TERMINAL_PROMPT=0
export GIT_ASKPASS=/bin/false
git config --global credential.helper ''
git config --global --add safe.directory '*'

# Wireshark non-interactive config & hardware/network groups
echo "wireshark-common wireshark-common/install-syscap boolean true" | debconf-set-selections
dpkg-reconfigure wireshark-common || true
for grp in wireshark dialout plugdev netdev; do
  getent group "$grp" >/dev/null || groupadd -r "$grp"
  usermod -a -G "$grp" telcosec || true
done

rm -rf /var/lib/apt/lists/*

# ─── 2. pip global config (mirrors 00-install-all-packages.sh step 6b) ─────
mkdir -p /etc/pip
cat > /etc/pip/pip.conf << 'PIPCONF'
[global]
timeout = 120
retries = 10
PIPCONF
pip3 install --break-system-packages --force-reinstall --no-deps \
  typing-extensions || true

# ─── 3. SIPVicious + Scapy (from 04-install-tools.sh) ───────────────────────
pip_retry install sipvicious scapy --break-system-packages
record_tool "SIPVicious" "$(command -v sipvicious 2>/dev/null || command -v svmap 2>/dev/null)" "voip"

# ─── 4. sctpscan (from 04-install-tools.sh) ─────────────────────────────────
echo "Compiling sctpscan..."
git_clone_retry --depth 1 https://github.com/philpraxis/sctpscan.git "${TELCOSEC_OPT}/sctpscan"
cd "${TELCOSEC_OPT}/sctpscan"
sed -i '/#include <stropts.h>/d' sctpscan.c
sed -i 's/setpgrp(0, getpid())/setpgrp()/g' sctpscan.c
sed -i '/#include <sys\/socket.h>/a #include <sys\/ioctl.h>' sctpscan.c
gcc -O2 -Wno-pointer-to-int-cast -Wno-unused-result \
  sctpscan.c -o sctpscan $(pkg-config --cflags --libs glib-2.0)
cp sctpscan /usr/local/bin/
chmod 755 /usr/local/bin/sctpscan
record_tool "sctpscan" "/usr/local/bin/sctpscan" "voip"

# ─── 5. SigPloit (SS7/Diameter/GTP framework — Docker-based, from 04) ──────
# The Dockerfile + wrapper are installed so users with docker-in-docker (or a
# mounted host socket, see docker/README.md) can build/run it; the image
# itself is NOT built here (that would require DinD at `docker build` time).
echo "Setting up SigPloit..."
git_clone_retry --depth 1 https://github.com/SigPloiter/SigPloit.git "${TELCOSEC_OPT}/sigploit"
cat << 'EOF' > "${TELCOSEC_OPT}/sigploit/Dockerfile"
FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y python2 python-pip libsctp-dev git && rm -rf /var/lib/apt/lists/*
RUN pip2 install colorama pyfiglet termcolor configobj 'IPy==0.83' pysctp
WORKDIR /app
ENTRYPOINT ["python2", "sigploit.py"]
EOF
cat << 'EOF' > /usr/local/bin/sigploit
#!/bin/bash
cd /opt/telcosec/sigploit
if ! docker image inspect sigploit:latest >/dev/null 2>&1; then
  echo "Building SigPloit Docker image for the first time..."
  docker build -t sigploit:latest .
fi
exec docker run -it --rm --net=host -v "$PWD:/app" sigploit:latest "$@"
EOF
chmod +x /usr/local/bin/sigploit
record_tool "SigPloit" "/usr/local/bin/sigploit" "voip"

# ─── 6. Diafuzzer (from 04-install-tools.sh) ────────────────────────────────
echo "Installing Diafuzzer..."
git_clone_retry --depth 1 https://github.com/Orange-OpenSource/diafuzzer.git "${TELCOSEC_OPT}/diafuzzer" || true
if [ -f "${TELCOSEC_OPT}/diafuzzer/requirements.txt" ]; then
  pip_retry install -r "${TELCOSEC_OPT}/diafuzzer/requirements.txt" --break-system-packages
fi

# ─── 7. Wordlists (vendored, from 04-install-tools.sh) ──────────────────────
echo "Installing TelcoSec wordlists..."
mkdir -p /usr/share/wordlists/telecom
if [ -d "${TELCOSEC_OPT}/wordlists" ] && [ "$(ls -A "${TELCOSEC_OPT}/wordlists" 2>/dev/null)" ]; then
  cp -r "${TELCOSEC_OPT}/wordlists/." /usr/share/wordlists/telecom/
fi
find /usr/share/wordlists/telecom -type f -exec chmod 644 {} + 2>/dev/null || true
find /usr/share/wordlists/telecom -type d -exec chmod 755 {} + 2>/dev/null || true
[ -f /usr/share/wordlists/telecom/scripts/apn_permutator.py ] && \
  install -m 755 /usr/share/wordlists/telecom/scripts/apn_permutator.py /usr/local/bin/telcosec-apn-permutator || true
[ -f /usr/share/wordlists/telecom/scripts/imsi_generator.py ] && \
  install -m 755 /usr/share/wordlists/telecom/scripts/imsi_generator.py /usr/local/bin/telcosec-imsi-generator || true

# Ensure mausezahn and mz from netsniff-ng package are easily accessible in PATH
if [ -f /usr/sbin/mausezahn ] && [ ! -f /usr/local/bin/mausezahn ]; then
  ln -sf /usr/sbin/mausezahn /usr/local/bin/mausezahn
fi
if [ -f /usr/sbin/mz ] && [ ! -f /usr/local/bin/mz ]; then
  ln -sf /usr/sbin/mz /usr/local/bin/mz
elif [ -f /usr/sbin/mausezahn ] && [ ! -f /usr/local/bin/mz ]; then
  ln -sf /usr/sbin/mausezahn /usr/local/bin/mz
fi
record_tool "mausezahn (mz)" "$(command -v mz 2>/dev/null || command -v mausezahn 2>/dev/null || echo '/usr/sbin/mausezahn')" "adsl"

# ─── 8. libosmocore >= 1.11.0 (from 06-install-ue-analysis.sh) ─────────────
# Ubuntu 24.04 ships 1.7.0; simtrace2 host tools require >= 1.11.0.
echo "Building libosmocore from source..."
git_clone_retry --depth 1 https://gitea.osmocom.org/osmocom/libosmocore.git /tmp/libosmocore
cd /tmp/libosmocore
autoreconf -fi
./configure --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --disable-doxygen --disable-tests
make -j"$(nproc)"
make install
find /usr/lib/x86_64-linux-gnu/pkgconfig/ -name 'libosmo*.pc' | while read -r pc; do
  grep -q 'UNKNOWN' "$pc" 2>/dev/null && sed -i '/^Version:/c\Version: 1.11.0' "$pc"
done
ldconfig
cd "$TELCOSEC_OPT"
rm -rf /tmp/libosmocore
record_tool "libosmocore" "/usr/lib/x86_64-linux-gnu/pkgconfig/libosmocore.pc" "baseband"

# ─── 9. FirmWire (from 06-install-ue-analysis.sh) ───────────────────────────
echo "Installing FirmWire..."
git_clone_retry --depth 1 https://github.com/FirmWire/FirmWire.git "${TELCOSEC_OPT}/firmwire"
cd "${TELCOSEC_OPT}/firmwire"
grep -rl "from collections import Mapping" --include="*.py" . 2>/dev/null | \
  xargs -r sed -i 's/from collections import Mapping/from collections.abc import Mapping/'
python3 -m venv venv
./venv/bin/pip install --upgrade pip
./venv/bin/pip install "Cython<3.0.0" setuptools wheel

if [ ! -f /usr/include/rocksdb/utilities/backupable_db.h ]; then
  mkdir -p /usr/include/rocksdb/utilities/
  cat << 'EOF' > /usr/include/rocksdb/utilities/backupable_db.h
#pragma once
#include "rocksdb/utilities/backup_engine.h"
namespace rocksdb {
  typedef BackupEngineOptions BackupableDBOptions;
  typedef BackupEngine BackupableDB;
  typedef BackupInfo BackupableDBInfo;
}
EOF
fi

mkdir -p /tmp/rocksdb-build
cd /tmp/rocksdb-build
"${TELCOSEC_OPT}/firmwire/venv/bin/pip" download --no-binary :all: --no-deps rocksdb
tar -xzf rocksdb-*.tar.gz
cd rocksdb-*/

python3 -c "
with open('rocksdb/cpp/filter_policy_wrapper.hpp', 'r') as f:
    content = f.read()

replacement = '''            virtual const char* CompatibilityName() const override {
                return this->name.c_str();
            }

            virtual rocksdb::FilterBitsBuilder* GetBuilderWithContext(
                const rocksdb::FilterBuildingContext&) const override {
                return nullptr;
            }

            virtual rocksdb::FilterBitsReader* GetFilterBitsReader(
                const rocksdb::Slice&) const override {
                return nullptr;
            }

            virtual const char* Name() const {'''

new_content = content.replace('            virtual const char* Name() const {', replacement)
with open('rocksdb/cpp/filter_policy_wrapper.hpp', 'w') as f:
    f.write(new_content)
"

python3 - <<'PYEOF'
import re, pathlib

pyx = pathlib.Path('rocksdb/_rocksdb.pyx').read_text()

for prop in ['purge_redundant_kvs_while_flush', 'rate_limit_delay_max_milliseconds', 'soft_rate_limit', 'hard_rate_limit', 'max_mem_compaction_level', 'skip_log_error_on_recovery']:
    pyx = re.sub(
        r'\s*property ' + prop + r':\s*'
        r'def __get__\(self\):.*?'
        r'def __set__\(self, \w+\):.*?self\.(copts|opts)\.' + prop + r'\s*=\s*\w+\b[^\n]*\n',
        '\n',
        pyx,
        flags=re.DOTALL
    )

pyx = pyx.replace(
    '        if hash_index_allow_collision:\n            table_options.hash_index_allow_collision = True\n        else:\n            table_options.hash_index_allow_collision = False',
    '        # disabled hash_index_allow_collision for RocksDB 7+'
)
pyx = pyx.replace(
    '        if block_cache_compressed is not None:\n            table_options.block_cache_compressed = block_cache_compressed.get_cache()',
    '        # disabled block_cache_compressed for RocksDB 7+'
)
pyx = pyx.replace(
    '    def create_filter(self, keys):\n        cdef string dst\n        cdef vector[Slice] c_keys\n\n        for key in keys:\n            c_keys.push_back(bytes_to_slice(key))\n\n        self.policy.get().CreateFilter(\n            vector_data(c_keys),\n            <int>c_keys.size(),\n            cython.address(dst))\n\n        return string_to_bytes(dst)',
    '    def create_filter(self, keys):\n        raise NotImplementedError("create_filter is not supported in RocksDB 7+")'
)
pyx = pyx.replace(
    '    def key_may_match(self, key, filter_):\n        return self.policy.get().KeyMayMatch(\n            bytes_to_slice(key),\n            bytes_to_slice(filter_))',
    '    def key_may_match(self, key, filter_):\n        raise NotImplementedError("key_may_match is not supported in RocksDB 7+")'
)

pathlib.Path('rocksdb/_rocksdb.pyx').write_text(pyx)

pxd = pathlib.Path('rocksdb/table_factory.pxd').read_text()
pxd = pxd.replace('        cpp_bool hash_index_allow_collision\n', '')
pxd = pxd.replace('        shared_ptr[Cache] block_cache_compressed\n', '')
pathlib.Path('rocksdb/table_factory.pxd').write_text(pxd)

f_pxd = pathlib.Path('rocksdb/filter_policy.pxd').read_text()
f_pxd = f_pxd.replace('        void CreateFilter(const Slice*, int, string*) nogil except+\n', '')
f_pxd = f_pxd.replace('        cpp_bool KeyMayMatch(const Slice&, const Slice&) nogil except+\n', '')
pathlib.Path('rocksdb/filter_policy.pxd').write_text(f_pxd)

setup_py = pathlib.Path('setup.py').read_text()
setup_py = setup_py.replace("'-std=c++11'", "'-std=c++17'")
pathlib.Path('setup.py').write_text(setup_py)
PYEOF

rm -f rocksdb/_rocksdb.cpp
"${TELCOSEC_OPT}/firmwire/venv/bin/pip" install --no-build-isolation .
cd "${TELCOSEC_OPT}/firmwire"
rm -rf /tmp/rocksdb-build

./venv/bin/pip install -r requirements.txt
./venv/bin/pip install --upgrade setuptools

FIRMWIRE_ROCKSDB=$(find "${TELCOSEC_OPT}/firmwire/venv/lib" -maxdepth 3 -iname 'rocksdb*' 2>/dev/null | head -1)
record_tool "FirmWire" "$FIRMWIRE_ROCKSDB" "baseband"

# ─── 10. QCSuper (from 06-install-ue-analysis.sh) ───────────────────────────
pip_retry install --upgrade qcsuper --break-system-packages
record_tool "QCSuper" "$(command -v qcsuper 2>/dev/null)" "baseband"

# ─── 11. MTKClient (from 06-install-ue-analysis.sh) ─────────────────────────
git_clone_retry --depth 1 https://github.com/bkerler/mtkclient.git "${TELCOSEC_OPT}/mtkclient"
cd "${TELCOSEC_OPT}/mtkclient"
grep -v '^keystone[[:space:]]*$' requirements.txt > /tmp/mtkclient-req.txt
pip_retry install -r /tmp/mtkclient-req.txt --break-system-packages
pip_retry install --break-system-packages .
record_tool "mtkclient" "$(command -v mtk 2>/dev/null)" "baseband"

# ─── 12. pySim (from 06-install-ue-analysis.sh) ─────────────────────────────
git_clone_retry --depth 1 https://github.com/osmocom/pysim.git "${TELCOSEC_OPT}/pysim"
cd "${TELCOSEC_OPT}/pysim"
pip_retry install -r requirements.txt --break-system-packages
pip_retry install --break-system-packages .
chmod +x pySim-shell.py pySim-prog.py pySim-read.py 2>/dev/null || true
ln -sf "${TELCOSEC_OPT}/pysim/pySim-shell.py" /usr/local/bin/pySim-shell
record_tool "pySim" "/usr/local/bin/pySim-shell" "sim"

# ─── 13. lpac — eSIM LPA (from 06-install-ue-analysis.sh) ──────────────────
git_clone_retry --depth 1 https://github.com/estkme-group/lpac.git "${TELCOSEC_OPT}/lpac"
cd "${TELCOSEC_OPT}/lpac"
mkdir build && cd build
if cmake -DCMAKE_BUILD_TYPE=Release .. && make -j"$(nproc)"; then
  cp src/lpac /usr/local/bin/lpac
  chmod 755 /usr/local/bin/lpac
else
  echo "WARNING: lpac build failed — tool will be unavailable"
fi
cd /
record_tool "lpac" "/usr/local/bin/lpac" "sim"

# ─── 14. SIMtrace 2 host tools (from 06-install-ue-analysis.sh) ────────────
git_clone_retry --depth 1 https://github.com/osmocom/simtrace2.git "${TELCOSEC_OPT}/simtrace2"
cd "${TELCOSEC_OPT}/simtrace2/host"
autoreconf -fi
./configure
make -j"$(nproc)"
make install
ldconfig
cd /
record_tool "simtrace2" "$(command -v simtrace2-list 2>/dev/null)" "sim"

# ─── 15. SIMurai (from 06-install-ue-analysis.sh) ───────────────────────────
# Requires --recurse-submodules --shallow-submodules (not --depth 1) — see
# CLAUDE.md Key Constraints. Build with `make main`, not `make main-dbg`.
git_clone_retry --recurse-submodules --shallow-submodules \
  https://github.com/tomasz-lisowski/simurai.git "${TELCOSEC_OPT}/simurai"
if [ -d "${TELCOSEC_OPT}/simurai/swsim" ]; then
  cd "${TELCOSEC_OPT}/simurai/swsim"
  make main -j"$(nproc)" || echo "WARNING: swsim build failed — simurai will be unavailable"
  [ -f build/swsim.elf ] && install -m 755 build/swsim.elf /usr/local/bin/simurai

  cd "${TELCOSEC_OPT}/simurai/swicc-pcsc"
  make main -j"$(nproc)" && make install || echo "WARNING: swicc-pcsc build/install failed"
  cd /
fi
record_tool "SIMurai" "/usr/local/bin/simurai" "sim"

# ─── 16. UERANSIM (from 10-install-telecom-advanced.sh) ────────────────────
git_clone_retry --depth 1 --branch v3.3.0 https://github.com/aligungr/UERANSIM "${TELCOSEC_OPT}/ueransim" \
  || git_clone_retry --depth 1 https://github.com/aligungr/UERANSIM "${TELCOSEC_OPT}/ueransim"
cd "${TELCOSEC_OPT}/ueransim"
cmake -DCMAKE_BUILD_TYPE=Release . 2>&1 | tail -3
make -j"$(nproc)" 2>&1 | tail -5
install -m 755 build/nr-gnb /usr/local/bin/nr-gnb
install -m 755 build/nr-ue  /usr/local/bin/nr-ue
install -m 755 build/nr-cli /usr/local/bin/nr-cli
rm -rf build
cd /
record_tool "UERANSIM" "/usr/local/bin/nr-ue" "5g"

# ─── 17. SCAT (from 10-install-telecom-advanced.sh) ─────────────────────────
pip_retry install scat --break-system-packages
record_tool "SCAT" "$(command -v scat 2>/dev/null || echo '/usr/local/bin/scat')" "baseband"

# ─── 18. Kalibrate-GSM (from 10-install-telecom-advanced.sh) ───────────────
git_clone_retry --depth 1 https://github.com/scateu/kalibrate-hackrf "${TELCOSEC_OPT}/kalibrate-gsm" 2>/dev/null || true
if [ -d "${TELCOSEC_OPT}/kalibrate-gsm" ]; then
  cd "${TELCOSEC_OPT}/kalibrate-gsm"
  ./bootstrap.sh 2>/dev/null || autoreconf -fi
  ./configure && make -j"$(nproc)"
  [ -f src/kal ] && cp -f src/kal /usr/local/bin/kal-gsm || true
  cd /
fi
record_tool "kalibrate-gsm" "/usr/local/bin/kal-gsm" "2g"

# ─── 19. SIMTester (from 10-install-telecom-advanced.sh) ───────────────────
git_clone_retry --depth 1 https://github.com/srlabs/SIMtester "${TELCOSEC_OPT}/simtester"
JAR=$(find "${TELCOSEC_OPT}/simtester/binaries" -name "SIMTester.jar" 2>/dev/null | sort -V | tail -n 1)
if [ -n "$JAR" ]; then
  cat << EOF > /usr/local/bin/simtester
#!/bin/bash
exec java -jar ${JAR} "\$@"
EOF
  chmod +x /usr/local/bin/simtester
fi
record_tool "SIMTester" "/usr/local/bin/simtester" "sim"

# ─── 20. LTESniffer (from 10-install-telecom-advanced.sh) ──────────────────
git_clone_retry --depth 1 --branch LTESniffer-v2.1.0 https://github.com/SysSec-KAIST/LTESniffer "${TELCOSEC_OPT}/ltesniffer" \
  || git_clone_retry --depth 1 https://github.com/SysSec-KAIST/LTESniffer "${TELCOSEC_OPT}/ltesniffer"
cd "${TELCOSEC_OPT}/ltesniffer"
mkdir -p build && cd build
export CFLAGS="-Wno-error -fcommon -fpermissive"
export CXXFLAGS="-Wno-error -fcommon -fpermissive -std=c++14"
cmake .. -DCMAKE_BUILD_TYPE=Release 2>&1 | tail -5
make -j"$(nproc)" 2>&1 | tail -10 || make 2>&1 | tail -10 || true
SNIFFER_BIN=$(find . -type f \( -name "LTESniffer" -o -name "ltesniffer" \) 2>/dev/null | head -1)
if [ -n "$SNIFFER_BIN" ] && [ -f "$SNIFFER_BIN" ]; then
  install -m 755 "$SNIFFER_BIN" /usr/local/bin/ltesniffer
elif [ -f "${TELCOSEC_OPT}/ltesniffer/src/LTESniffer" ]; then
  install -m 755 "${TELCOSEC_OPT}/ltesniffer/src/LTESniffer" /usr/local/bin/ltesniffer
fi
cd /
rm -rf "${TELCOSEC_OPT}/ltesniffer/build"
record_tool "LTESniffer" "/usr/local/bin/ltesniffer" "4g"

# ─── 21. RouterSploit (from 10-install-telecom-advanced.sh) ────────────────
git_clone_retry --depth 1 --branch v3.4.7 https://github.com/threat9/routersploit "${TELCOSEC_OPT}/routersploit" \
  || git_clone_retry --depth 1 https://github.com/threat9/routersploit "${TELCOSEC_OPT}/routersploit"
cd "${TELCOSEC_OPT}/routersploit"
pip_retry install -r requirements.txt --break-system-packages
cat << 'EOF' > /usr/local/bin/routersploit
#!/bin/bash
python3 /opt/telcosec/routersploit/rsf.py "$@"
EOF
chmod +x /usr/local/bin/routersploit
cd /
record_tool "RouterSploit" "/usr/local/bin/routersploit" "adsl"

# ─── 21b. Asleap (PPPoE / MS-CHAPv2 offline cracker) ───────────────────────
echo "Compiling Asleap..."
git_clone_retry --depth 1 https://github.com/joswr1ght/asleap.git "${TELCOSEC_OPT}/asleap"
if [ -d "${TELCOSEC_OPT}/asleap" ]; then
  cd "${TELCOSEC_OPT}/asleap"
  make CFLAGS="-O2 -Wno-error -fcommon" -j"$(nproc)" 2>&1 | tail -5 || true
  [ -f asleap ] && ln -sf "${TELCOSEC_OPT}/asleap/asleap" /usr/local/bin/asleap || true
  [ -f genkeys ] && ln -sf "${TELCOSEC_OPT}/asleap/genkeys" /usr/local/bin/genkeys || true
  cd /
fi
record_tool "Asleap" "/usr/local/bin/asleap" "adsl"

# ─── 21c. snmp-check (SNMP device enumerator) ──────────────────────────────
echo "Installing snmp-check..."
if [ ! -f /usr/local/bin/snmp-check ]; then
  wget -q https://gitlab.com/kalilinux/packages/snmpcheck/-/raw/kali/master/snmpcheck-1.9.rb -O /usr/local/bin/snmp-check || true
  if [ -s /usr/local/bin/snmp-check ]; then
    chmod +x /usr/local/bin/snmp-check
  fi
fi
record_tool "snmp-check" "/usr/local/bin/snmp-check" "adsl"

# ─── 21d. DOCSIS config tool ───────────────────────────────────────────────
echo "Compiling DOCSIS config tool..."
git_clone_retry --depth 1 https://github.com/rlaager/docsis.git "${TELCOSEC_OPT}/docsis"
if [ -d "${TELCOSEC_OPT}/docsis" ]; then
  cd "${TELCOSEC_OPT}/docsis"
  ./autogen.sh && ./configure && make -j"$(nproc)" 2>&1 | tail -5 || true
  make install || true
  cd /
fi
record_tool "docsis" "/usr/local/bin/docsis" "adsl"

# ─── 21e. RDNSx (Rapid DNS Reverse Resolver) ───────────────────────────────
echo "Installing RDNSx..."
if dpkg-query -W rdnsx 2>/dev/null; then
  echo "  RDNSx already installed via APT."
elif apt-cache show rdnsx >/dev/null 2>&1 && apt-get install -y rdnsx; then
  echo "  RDNSx installed via APT."
else
  git_clone_retry --depth 1 https://github.com/TelcoSec-Tools/RDNSx.git "${TELCOSEC_OPT}/rdnsx"
  if [ -d "${TELCOSEC_OPT}/rdnsx" ]; then
    cd "${TELCOSEC_OPT}/rdnsx"
    command -v cargo &>/dev/null || apt-get install -y --no-install-recommends cargo rustc 2>/dev/null || true
    if command -v cargo &>/dev/null; then
      cargo build --release --bin rdnsx -j"$(nproc)" 2>&1 | tail -5 || true
      if [ -f target/release/rdnsx ]; then
        install -m 755 target/release/rdnsx /usr/local/bin/rdnsx
      fi
    fi
    if [ ! -f /usr/local/bin/rdnsx ]; then
      cat > /usr/local/bin/rdnsx << 'LAUNCHER'
#!/bin/bash
if [ -x /opt/telcosec/rdnsx/target/release/rdnsx ]; then
  exec /opt/telcosec/rdnsx/target/release/rdnsx "$@"
fi
echo "RDNSx: binary not built. Please run 'cd /opt/telcosec/rdnsx && cargo build --release' first." >&2
exit 1
LAUNCHER
      chmod +x /usr/local/bin/rdnsx
    fi
    cd /
  fi
fi
record_tool "RDNSx" "/usr/local/bin/rdnsx" "adsl"

# ─── 22. SIPp (from 00-install-all-packages.sh — not in Ubuntu 24.04 apt) ──
git_clone_retry --depth 1 --branch v3.7.9 https://github.com/SIPp/sipp "${TELCOSEC_OPT}/sipp" \
  || git_clone_retry --depth 1 https://github.com/SIPp/sipp "${TELCOSEC_OPT}/sipp"
cmake -S "${TELCOSEC_OPT}/sipp" -B "${TELCOSEC_OPT}/sipp/build" \
  -DCMAKE_BUILD_TYPE=Release \
  -DUSE_SSL=1 \
  -DUSE_SCTP=1 \
  -DUSE_PCAP=1 \
  -DUSE_GSL=1 \
  -DTLS_KEY_LOGGING=1 \
  -DSIPP_MAX_MSG_SIZE=262144 \
  -DCMAKE_CXX_FLAGS="-O3 -pipe" \
  -DCMAKE_INSTALL_PREFIX=/usr/local >/dev/null
make -C "${TELCOSEC_OPT}/sipp/build" -j"$(nproc)" sipp >/dev/null
install -m 755 "${TELCOSEC_OPT}/sipp/build/sipp" /usr/local/bin/sipp
rm -rf "${TELCOSEC_OPT}/sipp/build"
record_tool "sipp" "/usr/local/bin/sipp" "voip"

# ─── 22b. rtpbleed (RTP stream bleeding and leaky media proxy auditor) ──────
cat << 'EOF' > /usr/local/bin/rtpbleed
#!/usr/bin/env python3
"""
RTP Bleed / Leaky Media Proxy Security Auditor
Audits target RTP proxy ports for unauthenticated audio leaking.
"""
import sys
import socket
import argparse

def audit_rtp(target, start_port, end_port, timeout=1.0):
    print(f"[*] Scanning {target} UDP ports {start_port}-{end_port} for leaky RTP streams...")
    found = 0
    for port in range(start_port, end_port + 1, 2):
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(timeout)
        try:
            dummy_rtp = b"\x80\x00\x00\x01\x00\x00\x00\x00\x12\x34\x56\x78"
            sock.sendto(dummy_rtp, (target, port))
            data, addr = sock.recvfrom(2048)
            if data and len(data) >= 12:
                v = (data[0] >> 6) & 0x3
                pt = data[1] & 0x7F
                print(f"[!] LEAK DETECTED: {target}:{port} responded with {len(data)} bytes (RTP v{v}, PT={pt})")
                found += 1
        except (socket.timeout, ConnectionRefusedError, OSError):
            pass
        finally:
            sock.close()
    print(f"[*] Scan finished. Leaky ports identified: {found}")

def main():
    parser = argparse.ArgumentParser(description="RTP Bleed Security Scanner")
    parser.add_argument("-t", "--target", required=True, help="Target SBC or RTPproxy IP/host")
    parser.add_argument("-p", "--ports", default="10000-20000", help="UDP port range (default: 10000-20000)")
    parser.add_argument("--timeout", type=float, default=0.5, help="Socket timeout in seconds")
    args = parser.parse_args()
    
    parts = args.ports.split("-")
    start_p = int(parts[0])
    end_p = int(parts[1]) if len(parts) > 1 else start_p
    audit_rtp(args.target, start_p, end_p, args.timeout)

if __name__ == "__main__":
    main()
EOF
chmod +x /usr/local/bin/rtpbleed
record_tool "rtpbleed" "/usr/local/bin/rtpbleed" "voip"

# ─── 22c. voiphopper (Voice VLAN hopping security assessment tool) ───────────
if [ ! -d "${TELCOSEC_OPT}/voiphopper" ]; then
  git_clone_retry https://github.com/hmgh0st/voiphopper.git "${TELCOSEC_OPT}/voiphopper" 2>/dev/null || \
  git_clone_retry https://gitlab.com/kalilinux/packages/voiphopper.git "${TELCOSEC_OPT}/voiphopper" 2>/dev/null || true
fi
if [ -d "${TELCOSEC_OPT}/voiphopper" ]; then
  cd "${TELCOSEC_OPT}/voiphopper"
  gcc -O2 -Wall voiphopper.c -o voiphopper -lpcap 2>/dev/null || make 2>/dev/null || true
  if [ -f voiphopper ]; then
    install -m 755 voiphopper /usr/local/bin/voiphopper
  fi
  cd /
fi
record_tool "voiphopper" "/usr/local/bin/voiphopper" "voip"

# ─── 22d. sdr-info & telcosec-ran-status telemetry helpers ───────────────────
cat << 'EOF' > /usr/local/bin/sdr-info
#!/bin/bash
echo "=== TelcoChisel SDR Transceiver Discovery & Driver Status ==="
echo ""
echo "--- USB Connected Radio Devices ---"
lsusb 2>/dev/null | grep -iE "ettus|usrp|hackrf|bladerf|limesdr|rtl2832|realtek" || echo "No recognized USB SDR devices detected (ensure --device /dev/bus/usb)."
echo ""
echo "--- SoapySDR Hardware Probe ---"
if command -v SoapySDRUtil >/dev/null 2>&1; then
  SoapySDRUtil --find || true
else
  echo "SoapySDRUtil not available in base container (use telcochisel-sdr)."
fi
EOF
chmod +x /usr/local/bin/sdr-info
record_tool "sdr-info" "/usr/local/bin/sdr-info" "sdr"

cat << 'EOF' > /usr/local/bin/telcosec-ran-status
#!/bin/bash
clear
echo -e "\033[1;36m=== 📡 TelcoChisel Container Telemetry & SDR Prober ===\033[0m"
echo -e "\033[1;30mTimestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')\033[0m\n"
echo -e "\033[1;33m[1] USB SDR Transceivers:\033[0m"
lsusb 2>/dev/null | grep -iE "ettus|usrp|hackrf|bladerf|limesdr|rtl2832|realtek" || echo "  (None detected; ensure container run with --device /dev/bus/usb)"
echo ""
echo -e "\033[1;33m[2] Network & Tunnel Interfaces:\033[0m"
ip -br addr show 2>/dev/null || ifconfig 2>/dev/null
EOF
chmod +x /usr/local/bin/telcosec-ran-status
record_tool "telcosec-ran-status" "/usr/local/bin/telcosec-ran-status" "telecom"


# ─── 23. Scoped sudo for the telcosec user ──────────────────────────────────
# Intentionally NOT NOPASSWD:ALL — that granted container-to-host root when
# combined with docker.sock / privileged. Package-management and a few
# first-run helpers are enough for on-demand deps; escalate further only
# when you deliberately re-run the image as root or add your own sudoers.
cat > /etc/sudoers.d/telcosec << 'SUDOERS'
# TelcoChisel container — scoped passwordless sudo (not ALL)
telcosec ALL=(root) NOPASSWD: /usr/bin/apt-get, /usr/bin/apt, /usr/bin/dpkg
telcosec ALL=(root) NOPASSWD: /usr/local/bin/srsran-install, /usr/local/bin/open5gs-install
telcosec ALL=(root) NOPASSWD: /usr/local/bin/oai-install, /usr/local/bin/5ghoul-install
telcosec ALL=(root) NOPASSWD: /usr/local/bin/gtp5g-load
SUDOERS
chmod 440 /etc/sudoers.d/telcosec
visudo -c -f /etc/sudoers.d/telcosec || echo "WARNING: telcosec sudoers failed visudo check"

# ─── 23b. TelcoSec & TelcoSec Academy interactive login banner ───────────────
cat << 'BANNER_EOF' > /etc/profile.d/00-telcosec-banner.sh
if [ -t 1 ] && [ -z "${TELCOSEC_BANNER_SHOWN:-}" ]; then
  export TELCOSEC_BANNER_SHOWN=1
  CYAN='\033[1;36m'
  AMBER='\033[1;33m'
  GREEN='\033[1;32m'
  BOLD='\033[1m'
  MUTED='\033[0;37m'
  RESET='\033[0m'

  printf "${CYAN}"
  cat << 'EOF'
  +-----------------------------------------------------------------------+
  |   _____ _____ _     ____ ___   ____ _   _ ___ ____  _____ _           |
  |  |_   _| ____| |   / ___/ _ \ / ___| | | |_ _/ ___|| ____| |          |
  |    | | |  _| | |  | |  | | | | |   | |_| || |\___ \|  _| | |          |
  |    | | | |___| |__| |__| |_| | |___|  _  || | ___) | |___| |__|       |
  |    |_| |_____|_____\____\___/ \____|_| |_|___|____/|_____|____|       |
  |                                                                       |
EOF
  printf "${RESET}${BOLD}"
  cat << 'EOF'
  |         TELCOCHISEL OS v2026.2 -- TELECOM SECURITY CONTAINER          |
  +-----------------------------------------------------------------------+
EOF
  printf "${RESET}"
  printf "${AMBER}  |  [*] TelcoSec Academy -- Hands-On Telecom & 5G Security Labs          |${RESET}\n"
  printf "${MUTED}  |      - Real-world SS7, Diameter, GTP-C & 5G SBI signaling audits      |${RESET}\n"
  printf "${MUTED}  |      - Air-gapped 4G LTE & 5G SA core / RAN exploit workflows         |${RESET}\n"
  printf "${MUTED}  |      - Specialized SDR RF signal interception & replay exercises      |${RESET}\n"
  printf "${GREEN}  |  >>> Access Academy Portal: ${AMBER}https://app.telcosec.net${RESET}${GREEN}                |${RESET}\n"
  printf "${GREEN}  |  >>> Explore Interactive Labs: ${AMBER}https://app.telcosec.net/courses${RESET}${GREEN}     |${RESET}\n"
  printf "${GREEN}  |  >>> ProLabs Advanced Testbeds: ${AMBER}https://app.telcosec.net/prolabs${RESET}${GREEN}    |${RESET}\n"
  printf "${BOLD}  +-----------------------------------------------------------------------+${RESET}\n"
  printf "${MUTED}  |  Quick Commands:                                                      |${RESET}\n"
  printf "${CYAN}  |    telcosec search <query>    ${MUTED}Search offline 100-tool catalog         |${RESET}\n"
  printf "${CYAN}  |    telcosec-pkg list          ${MUTED}Browse modular Debian metapackages      |${RESET}\n"
  printf "${CYAN}  |    telcosec-academy           ${MUTED}Open TelcoSec Academy portal helper     |${RESET}\n"
  printf "${CYAN}  |    telcosec-prolabs           ${MUTED}Open TelcoSec ProLabs testbed helper    |${RESET}\n"
  printf "${CYAN}  |    sdr-info                   ${MUTED}Probe connected USB SDR transceivers    |${RESET}\n"
  printf "${BOLD}  +-----------------------------------------------------------------------+${RESET}\n\n"
fi
BANNER_EOF
chmod 644 /etc/profile.d/00-telcosec-banner.sh

# ─── 24. Binary stripping, compiler purge & cache optimization ──────────────
echo "Stripping binary symbols and pruning build caches..."
strip --strip-unneeded /usr/local/bin/* 2>/dev/null || true

# Mark runtime shared libraries explicitly installed before purging build packages
echo "Purging temporary build packages to minimize container size..."
apt-mark manual "${RUNTIME_LIBRARIES[@]}" >/dev/null 2>&1 || true

apt-get purge -y --auto-remove "${BUILD_DEPS[@]}" 2>/dev/null || true

find "${TELCOSEC_OPT}" -maxdepth 3 -name ".git" -type d -exec rm -rf {} + 2>/dev/null || true
find "${TELCOSEC_OPT}" -maxdepth 3 -name "build" -type d -exec rm -rf {} + 2>/dev/null || true
find "${TELCOSEC_OPT}" -name "*.o" -delete 2>/dev/null || true
find "${TELCOSEC_OPT}" -name "*.a" -delete 2>/dev/null || true
find / -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
find / -name "*.pyc" -delete 2>/dev/null || true
rm -rf /root/.cache /tmp/* /var/tmp/* /var/lib/apt/lists/*

# ─── 25. Healthcheck, ownership & tool-manifest summary ──────────────────────
install_container_healthcheck
chown -R telcosec:telcosec "${TELCOSEC_OPT}"
record_tool_summary

echo "=== telcochisel-base tool installation complete ==="
