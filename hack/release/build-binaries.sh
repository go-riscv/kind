#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

make -C "${ROOT_DIR}/pkg/kind" kind
make -C "${ROOT_DIR}/pkg/kubernetes" kubectl kubeadm

if [[ ! -d "${K9S_SOURCE_DIR}" ]]; then
  echo "Missing k9s source directory: ${K9S_SOURCE_DIR}" >&2
  exit 1
fi

make -C "${K9S_SOURCE_DIR}" build \
  GOOS=linux \
  GOARCH=riscv64 \
  OUTPUT_BIN="${BIN_DIR}/k9s"
