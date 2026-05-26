#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
KIND_BIN="${KIND_BIN:-${ROOT_DIR}/bin/kind}"
KUBECTL_BIN="${KUBECTL_BIN:-${ROOT_DIR}/bin/kubectl}"
NODE_IMAGE="${NODE_IMAGE:-kindest/node:latest}"
CLUSTER_NAME="${CLUSTER_NAME:-kind-rv64-ci}"

cleanup() {
  "${KIND_BIN}" delete cluster --name "${CLUSTER_NAME}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

cleanup
"${KIND_BIN}" create cluster \
  --name "${CLUSTER_NAME}" \
  --image "${NODE_IMAGE}" \
  --wait 5m

"${KUBECTL_BIN}" --context "kind-${CLUSTER_NAME}" get nodes -o wide
"${KUBECTL_BIN}" --context "kind-${CLUSTER_NAME}" -n kube-system get pods -o wide
"${KUBECTL_BIN}" --context "kind-${CLUSTER_NAME}" wait \
  --for=condition=Ready nodes \
  --all \
  --timeout=2m
