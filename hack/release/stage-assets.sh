#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}"

while IFS=: read -r src asset; do
  [[ -n "${src}" && -n "${asset}" ]] || continue

  if [[ ! -f "${BIN_DIR}/${src}" ]]; then
    echo "Missing binary: ${BIN_DIR}/${src}" >&2
    exit 1
  fi

  cp "${BIN_DIR}/${src}" "${DIST_DIR}/${asset}"
  chmod 0755 "${DIST_DIR}/${asset}"
done < <(release_asset_pairs)
