#!/usr/bin/env bash
# Run on Ubuntu 22.04+ or WSL2 (not native Windows). From repo root:
#   chmod +x scripts/build-on-linux.sh && ./scripts/build-on-linux.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

CUSTOMPIOS="${CUSTOMPIOS:-${ROOT}/../CustomPiOS}"

if [[ ! -f "${CUSTOMPIOS}/src/build" && ! -f "${CUSTOMPIOS}/src/build_dist" ]]; then
  echo "CustomPiOS not found at: ${CUSTOMPIOS}"
  echo "Clone it next to this repo:"
  echo "  git clone https://github.com/guysoft/CustomPiOS.git \"${CUSTOMPIOS}\""
  exit 1
fi

export CUSTOMPIOS_PATH="${CUSTOMPIOS}"
make update-paths

if [[ ! -f src/image/raspios_lite_arm64_latest.img.xz ]]; then
  echo "Downloading base Raspberry Pi OS image (one-time, large)..."
  make download-image
fi

echo "Starting image build (30–90+ minutes, needs sudo)..."
make build

echo "Done. Output: ${ROOT}/src/workspace/<clone-folder-name>.img (CustomPiOS names it after the parent of src/, e.g. R3DTOS-PI5.img)"
