#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
BIN_DIR="${ROOT_DIR}/bin"
DIST_DIR="${ROOT_DIR}/dist/release"

REGISTRY="${REGISTRY:-ghcr.io/go-riscv}"
RELEASE_TAG="${RELEASE_TAG:-}"
KIND_BUILD_PROFILE="${KIND_BUILD_PROFILE:-local}"
NODE_IMAGE_REPO="${NODE_IMAGE_REPO:-${REGISTRY}/node}"
NODE_IMAGE_SOURCE="${NODE_IMAGE_SOURCE:-kindest/node:latest}"
K9S_SOURCE_DIR="${K9S_SOURCE_DIR:-${ROOT_DIR}/../k9s}"

if [[ -z "${RELEASE_TAG}" && "${GITHUB_REF_NAME:-}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  RELEASE_TAG="${GITHUB_REF_NAME}"
fi

if [[ -n "${RELEASE_TAG}" && ! "${RELEASE_TAG}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "RELEASE_TAG must match vX.Y.Z, got: ${RELEASE_TAG}" >&2
  exit 1
fi

if [[ "${KIND_BUILD_PROFILE}" != "local" && "${KIND_BUILD_PROFILE}" != "release" ]]; then
  echo "KIND_BUILD_PROFILE must be local or release, got: ${KIND_BUILD_PROFILE}" >&2
  exit 1
fi

if [[ "${KIND_BUILD_PROFILE}" == "release" && -z "${RELEASE_TAG}" ]]; then
  echo "RELEASE_TAG is required when KIND_BUILD_PROFILE=release" >&2
  exit 1
fi

mkdir -p "${BIN_DIR}" "${DIST_DIR}"

kind_source_image() {
  if docker image inspect "${NODE_IMAGE_SOURCE}" >/dev/null 2>&1; then
    echo "${NODE_IMAGE_SOURCE}"
    return 0
  fi

  local candidate
  candidate=$(docker image ls --format '{{.Repository}}:{{.Tag}}' | grep '^kindest/node:' | head -n1 || true)
  if [[ -n "${candidate}" ]]; then
    echo "${candidate}"
    return 0
  fi

  echo "Unable to find the built kind node image; checked ${NODE_IMAGE_SOURCE} and kindest/node:*" >&2
  return 1
}

release_asset_pairs() {
  cat <<'EOF'
kind:kind-linux-riscv64
kubectl:kubectl-linux-riscv64
kubeadm:kubeadm-linux-riscv64
k9s:k9s-linux-riscv64
EOF
}

release_asset_names() {
  release_asset_pairs | cut -d: -f2
  echo "kind-config-linux-riscv64.yaml"
  echo "verify-kind-release-riscv64.sh"
}

kind_make() {
  make -C "${ROOT_DIR}/pkg/kind" \
    REGISTRY="${REGISTRY}" \
    KIND_BUILD_PROFILE="${KIND_BUILD_PROFILE}" \
    RELEASE_TAG="${RELEASE_TAG}" \
    "$@"
}
