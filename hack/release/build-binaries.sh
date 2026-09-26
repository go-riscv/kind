#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

kind_make kind
make -C "${ROOT_DIR}/pkg/kubernetes" kubectl kubeadm
