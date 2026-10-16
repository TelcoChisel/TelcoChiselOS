#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."

for f in build-iso.sh build-wsl.sh scripts/*.sh builder/scripts/*.sh builder/scripts/lib/*.sh builder/scripts/bin/* builder/vm/*.sh docker/*.sh docker/scripts/*.sh docker/pods/*.sh; do
    if [ -f "$f" ]; then
        bash -n "$f"
        echo "Syntax OK: $f"
    fi
done

echo "=== All scripts passed bash -n syntax check! ==="
