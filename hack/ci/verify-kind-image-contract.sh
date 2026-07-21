#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
PROFILE="${1:-local}"
RELEASE_TAG="${2:-}"
REGISTRY="${REGISTRY:-ghcr.io/go-riscv}"
BINARY="${KIND_BINARY:-${ROOT_DIR}/dist/release/kind-linux-riscv64}"
CONFIG="${KIND_CONFIG:-${ROOT_DIR}/dist/release/kind-config-linux-riscv64.yaml}"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

if [[ "${PROFILE}" != "local" && "${PROFILE}" != "release" ]]; then
  fail "profile must be local or release, got: ${PROFILE}"
fi

if [[ "${PROFILE}" == "release" && ! "${RELEASE_TAG}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  fail "release verification requires a vX.Y.Z tag, got: ${RELEASE_TAG}"
fi

mapfile -t refs < <(
  make -s -C "${ROOT_DIR}/pkg/kind" \
    REGISTRY="${REGISTRY}" \
    KIND_BUILD_PROFILE="${PROFILE}" \
    RELEASE_TAG="${RELEASE_TAG}" \
    print-kind-runtime-image-refs
)

if [[ "${PROFILE}" == "release" ]]; then
  expected_refs=(
    "node=${REGISTRY}/node:${RELEASE_TAG}"
    "pause=${REGISTRY}/pause:${RELEASE_TAG}"
    "kindnetd=${REGISTRY}/kindnetd:${RELEASE_TAG}"
    "local-path-provisioner=${REGISTRY}/local-path-provisioner:${RELEASE_TAG}"
    "local-path-helper=${REGISTRY}/local-path-helper:${RELEASE_TAG}"
  )
  expected_etcd_tag="${RELEASE_TAG}"
else
  expected_refs=(
    "node=kindest/node:latest"
    "pause=pause:riscv64"
    "kindnetd=kindnetd:riscv64"
    "local-path-provisioner=local-path-provisioner:riscv64"
    "local-path-helper=local-path-helper:riscv64"
  )
  expected_etcd_tag="3.5-riscv64"
fi

[[ "${refs[*]}" == "${expected_refs[*]}" ]] ||
  fail "runtime refs differ: expected '${expected_refs[*]}', got '${refs[*]}'"

GENERATED_KIND_DIR="${ROOT_DIR}/pkg/kind/build/kind"
if [[ -d "${GENERATED_KIND_DIR}" ]]; then
  grep -Fxq "const Image = \"${expected_refs[0]#node=}\"" \
    "${GENERATED_KIND_DIR}/pkg/apis/config/defaults/image.go" ||
    fail "generated KinD source has the wrong default node image"
  grep -Fq "sandbox_image = \"${expected_refs[1]#pause=}\"" \
    "${GENERATED_KIND_DIR}/images/base/files/etc/containerd/config.toml" ||
    fail "generated node source has the wrong pause image"
  grep -Fxq "const kindnetdImage = \"${expected_refs[2]#kindnetd=}\"" \
    "${GENERATED_KIND_DIR}/pkg/build/nodeimage/const_cni.go" ||
    fail "generated node source has the wrong kindnetd image"
  grep -Fxq "const storageProvisionerImage = \"${expected_refs[3]#local-path-provisioner=}\"" \
    "${GENERATED_KIND_DIR}/pkg/build/nodeimage/const_storage.go" ||
    fail "generated node source has the wrong local-path provisioner image"
  grep -Fxq "const storageHelperImage = \"${expected_refs[4]#local-path-helper=}\"" \
    "${GENERATED_KIND_DIR}/pkg/build/nodeimage/const_storage.go" ||
    fail "generated node source has the wrong local-path helper image"
fi

if [[ -f "${BINARY}" ]]; then
  expected_node="${expected_refs[0]#node=}"
  if [[ "${PROFILE}" == "release" ]]; then
    strings "${BINARY}" | grep -aF "${expected_node}" >/dev/null ||
      fail "binary does not embed release node ref '${expected_node}'"
  else
    strings "${BINARY}" | grep -aF "${expected_node}" >/dev/null ||
      fail "binary does not embed local node ref '${expected_node}'"
    if strings "${BINARY}" | grep -aF "${REGISTRY}/node:v" >/dev/null; then
      fail "local binary unexpectedly embeds a released GHCR node ref"
    fi
  fi
fi

if [[ -f "${CONFIG}" ]]; then
  grep -q "imageRepository: ${REGISTRY}" "${CONFIG}" ||
    fail "config does not use image repository ${REGISTRY}"
  grep -q "imageTag: ${expected_etcd_tag}" "${CONFIG}" ||
    fail "config does not use etcd tag ${expected_etcd_tag}"
fi

echo "PASS: ${PROFILE} KinD image contract is consistent."
