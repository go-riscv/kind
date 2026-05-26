#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

make -C "${ROOT_DIR}/pkg/kind" kind
make -C "${ROOT_DIR}/pkg/kubernetes" kubectl kubeadm
