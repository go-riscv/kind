#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

cd "${DIST_DIR}"
rm -f SHA256SUMS
sha256sum kind-linux-riscv64 kubectl-linux-riscv64 kubeadm-linux-riscv64 k9s-linux-riscv64 > SHA256SUMS
