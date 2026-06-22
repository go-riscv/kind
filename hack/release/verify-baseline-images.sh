#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"
MANIFEST_PATH="${BASELINE_IMAGES_ENV:-${ROOT_DIR}/hack/release/baseline-images.env}"
if [[ ! -f "${MANIFEST_PATH}" ]]; then
  echo "Missing baseline manifest: ${MANIFEST_PATH}" >&2
  echo "Copy hack/release/baseline-images.env.example and pin immutable digests." >&2
  exit 1
fi
# shellcheck disable=SC1090
source "${MANIFEST_PATH}"
require_digest_ref() {
  local name="$1" ref="$2"
  if [[ -z "${ref}" ]]; then
    echo "${name} is empty in ${MANIFEST_PATH}" >&2
    exit 1
  fi
  if [[ ! "${ref}" =~ @sha256:[0-9a-fA-F]{64}$ ]]; then
    echo "${name} must be pinned by immutable @sha256 digest, got: ${ref}" >&2
    exit 1
  fi
}
pull_and_tag() {
  local name="$1" digest_ref="$2" release_ref="$3" local_ref="$4" versioned_local_ref="${5:-}"
  require_digest_ref "${name}" "${digest_ref}"
  echo "Pulling trusted baseline ${name}: ${digest_ref}"
  docker pull "${digest_ref}"
  docker tag "${digest_ref}" "${release_ref}"
  docker tag "${digest_ref}" "${local_ref}"
  if [[ -n "${versioned_local_ref}" ]]; then
    docker tag "${digest_ref}" "${versioned_local_ref}"
  fi
}
pull_and_tag KUBE_CROSS_BASELINE_IMAGE "${KUBE_CROSS_BASELINE_IMAGE:-}" "${REGISTRY}/kube-cross-riscv64:${KUBE_CROSS_VERSION}" "kube-cross-riscv64" "kube-cross-riscv64:${KUBE_CROSS_VERSION}"
pull_and_tag DEBIAN_BASE_BASELINE_IMAGE "${DEBIAN_BASE_BASELINE_IMAGE:-}" "${REGISTRY}/debian-base-riscv64:${DEBIAN_BASE_VERSION}" "debian-base-riscv64:${DEBIAN_BASE_VERSION}"
pull_and_tag KUBE_GORUNNER_BASELINE_IMAGE "${KUBE_GORUNNER_BASELINE_IMAGE:-}" "${REGISTRY}/go-runner-riscv64:${KUBE_GORUNNER_VERSION}" "go-runner-riscv64:${KUBE_GORUNNER_VERSION}"
pull_and_tag KUBE_SETCAP_BASELINE_IMAGE "${KUBE_SETCAP_BASELINE_IMAGE:-}" "${REGISTRY}/setcap-riscv64:${KUBE_SETCAP_VERSION}" "setcap-riscv64:${KUBE_SETCAP_VERSION}"
pull_and_tag KUBE_PROXY_BASELINE_IMAGE "${KUBE_PROXY_BASELINE_IMAGE:-}" "${REGISTRY}/distroless-iptables-riscv64:${KUBE_PROXY_BASE_VERSION}" "distroless-iptables-riscv64:${KUBE_PROXY_BASE_VERSION}"
echo "Trusted baseline images verified and retagged for local Makefile consumers."
