#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"
SECONDS=0
make -C "${ROOT_DIR}/pkg/release" release
make -C "${ROOT_DIR}/pkg/etcd" etcd
make -C "${ROOT_DIR}/pkg/kubernetes" pause
kind_make node-image
printf "release image build elapsed_seconds=%s\n" "${SECONDS}"
