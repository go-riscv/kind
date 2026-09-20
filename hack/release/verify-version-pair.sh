#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
KIND_VERSION=v0.33.0
KUBERNETES_VERSION=v1.37.0

actual_source=$(git -C "${ROOT_DIR}/pkg/kubernetes/build/kubernetes" describe --tags --exact-match HEAD)
if [[ "${actual_source}" != "${KUBERNETES_VERSION}" ]]; then
  echo "Kubernetes source is ${actual_source}, expected ${KUBERNETES_VERSION}" >&2
  exit 1
fi
expected_commit=$(git -C "${ROOT_DIR}/pkg/kubernetes/build/kubernetes" rev-parse HEAD)

actual_kind=$("${ROOT_DIR}/bin/kind" version)
if [[ "${actual_kind}" != "kind ${KIND_VERSION} "* ]]; then
  echo "KinD binary is ${actual_kind}, expected ${KIND_VERSION}" >&2
  exit 1
fi

for binary in kubectl kubeadm; do
  if [[ "${binary}" == "kubectl" ]]; then
    version_json=$("${ROOT_DIR}/bin/${binary}" version --client -o json)
  else
    version_json=$("${ROOT_DIR}/bin/${binary}" version -o json)
  fi
  if ! grep -Eq '"gitVersion"[[:space:]]*:[[:space:]]*"v1\.37\.0(-dirty)?"' <<< "${version_json}" ||
     ! grep -Eq "\"gitCommit\"[[:space:]]*:[[:space:]]*\"${expected_commit}\"" <<< "${version_json}"; then
    echo "${binary} does not report Kubernetes ${KUBERNETES_VERSION}: ${version_json}" >&2
    exit 1
  fi
done

echo "PASS: KinD ${KIND_VERSION} and Kubernetes ${KUBERNETES_VERSION} release binaries match."
