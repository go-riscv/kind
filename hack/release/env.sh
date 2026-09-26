#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
BIN_DIR="${BIN_DIR:-${ROOT_DIR}/bin}"
DIST_DIR="${DIST_DIR:-${ROOT_DIR}/dist/release}"
KUBERNETES_SOURCE_DIR="${KUBERNETES_SOURCE_DIR:-${ROOT_DIR}/pkg/kubernetes/build/kubernetes}"

REGISTRY="${REGISTRY:-ghcr.io/go-riscv}"
RELEASE_TAG="${RELEASE_TAG:-}"
KIND_BUILD_PROFILE="${KIND_BUILD_PROFILE:-local}"
NODE_IMAGE_REPO="${NODE_IMAGE_REPO:-${REGISTRY}/node}"
NODE_IMAGE_SOURCE="${NODE_IMAGE_SOURCE:-kindest/node:latest}"
NODE_IMAGE_ID_FILE="${NODE_IMAGE_ID_FILE:-${ROOT_DIR}/pkg/kind/build/node-image.id}"

KIND_UPSTREAM_VERSION=""
KIND_RELEASE_TAG=""
KUBERNETES_VERSION=""
KUBERNETES_COMMIT=""
release_metadata=$(make -s -f "${ROOT_DIR}/pkg/common.mk" print-release-metadata)
while IFS='=' read -r key value; do
  case "${key}" in
    KIND_UPSTREAM_VERSION) KIND_UPSTREAM_VERSION="${value}" ;;
    KIND_RELEASE_TAG) KIND_RELEASE_TAG="${value}" ;;
    KUBERNETES_VERSION) KUBERNETES_VERSION="${value}" ;;
    KUBERNETES_COMMIT) KUBERNETES_COMMIT="${value}" ;;
  esac
done <<< "${release_metadata}"

if [[ -z "${KIND_UPSTREAM_VERSION}" || -z "${KIND_RELEASE_TAG}" || -z "${KUBERNETES_VERSION}" ||
      ! "${KUBERNETES_COMMIT}" =~ ^[0-9a-f]{40}$ ]]; then
  echo "Unable to query canonical release metadata from pkg/common.mk" >&2
  exit 1
fi

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

if [[ "${KIND_BUILD_PROFILE}" == "release" && "${RELEASE_TAG}" != "${KIND_RELEASE_TAG}" ]]; then
  echo "RELEASE_TAG must equal canonical KinD tag ${KIND_RELEASE_TAG}, got: ${RELEASE_TAG}" >&2
  exit 1
fi

kind_source_image() {
  docker image inspect "${NODE_IMAGE_SOURCE}" >/dev/null 2>&1 || {
    echo "Missing exact built node image: ${NODE_IMAGE_SOURCE}" >&2
    return 1
  }
  echo "${NODE_IMAGE_SOURCE}"
}

release_asset_pairs() {
  cat <<'EOF'
kind:kind-linux-riscv64
kubectl:kubectl-linux-riscv64
kubeadm:kubeadm-linux-riscv64
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
    NODE_IMAGE_SOURCE="${NODE_IMAGE_SOURCE}" \
    "$@"
}
