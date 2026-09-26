#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "${ROOT_DIR}/hack/release/env.sh"
KIND_VERSION="${KIND_RELEASE_TAG}"

actual_source=$(git -C "${KUBERNETES_SOURCE_DIR}" describe --tags --exact-match HEAD)
if [[ "${actual_source}" != "${KUBERNETES_VERSION}" ]]; then
  echo "Kubernetes source is ${actual_source}, expected ${KUBERNETES_VERSION}" >&2
  exit 1
fi
expected_commit=$(git -C "${KUBERNETES_SOURCE_DIR}" rev-parse HEAD)
if [[ "${expected_commit}" != "${KUBERNETES_COMMIT}" ]]; then
  echo "Kubernetes source commit is ${expected_commit}, expected ${KUBERNETES_COMMIT}" >&2
  exit 1
fi
expected_version_pattern=$(printf '%s\n' "${KUBERNETES_VERSION}" | sed 's/[][\\.^$*+?(){}|]/\\&/g')

actual_kind=$("${BIN_DIR}/kind" version)
if [[ "${actual_kind}" != "kind ${KIND_VERSION} "* ]]; then
  echo "KinD binary is ${actual_kind}, expected ${KIND_VERSION}" >&2
  exit 1
fi

for binary in kubectl kubeadm; do
  if [[ "${binary}" == "kubectl" ]]; then
    version_json=$("${BIN_DIR}/${binary}" version --client -o json)
  else
    version_json=$("${BIN_DIR}/${binary}" version -o json)
  fi
  if ! grep -Eq "\"gitVersion\"[[:space:]]*:[[:space:]]*\"${expected_version_pattern}\"" <<< "${version_json}" ||
     ! grep -Eq "\"gitCommit\"[[:space:]]*:[[:space:]]*\"${expected_commit}\"" <<< "${version_json}"; then
    echo "${binary} does not report Kubernetes ${KUBERNETES_VERSION}: ${version_json}" >&2
    exit 1
  fi
done

echo "PASS: KinD ${KIND_VERSION} and Kubernetes ${KUBERNETES_VERSION} release binaries match."
