#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

declare -A asset_map=(
  ["kind"]="kind-linux-riscv64"
  ["kubectl"]="kubectl-linux-riscv64"
  ["kubeadm"]="kubeadm-linux-riscv64"
)

rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}"

for src in "${!asset_map[@]}"; do
  if [[ ! -f "${BIN_DIR}/${src}" ]]; then
    echo "Missing binary: ${BIN_DIR}/${src}" >&2
    exit 1
  fi

  cp "${BIN_DIR}/${src}" "${DIST_DIR}/${asset_map[${src}]}"
  chmod 0755 "${DIST_DIR}/${asset_map[${src}]}"
done
