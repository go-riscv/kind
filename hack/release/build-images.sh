#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

make -C "${ROOT_DIR}/pkg/release" release
make -C "${ROOT_DIR}/pkg/kubernetes" pause
make -C "${ROOT_DIR}/pkg/kind" node-image
