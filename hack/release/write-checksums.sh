#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

cd "${DIST_DIR}"
rm -f SHA256SUMS
mapfile -t assets < <(release_asset_names)
sha256sum "${assets[@]}" > SHA256SUMS
