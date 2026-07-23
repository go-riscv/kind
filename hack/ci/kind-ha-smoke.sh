#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
KIND_BIN="${KIND_BIN:-${ROOT_DIR}/bin/kind}"
KUBECTL_BIN="${KUBECTL_BIN:-${ROOT_DIR}/bin/kubectl}"
NODE_IMAGE="${NODE_IMAGE:-kindest/node:latest}"
LOADBALANCER_IMAGE="${LOADBALANCER_IMAGE:-haproxy:riscv64}"
CLUSTER_NAME="${CLUSTER_NAME:-kind-rv64-ha-ci}"
CONFIG="${KIND_CONFIG:-${ROOT_DIR}/config/kind-ha.yaml}"
LOADBALANCER_CONTAINER="${CLUSTER_NAME}-external-load-balancer"

cleanup() {
  "${KIND_BIN}" delete cluster --name "${CLUSTER_NAME}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

cleanup
"${KIND_BIN}" create cluster \
  --name "${CLUSTER_NAME}" \
  --config "${CONFIG}" \
  --image "${NODE_IMAGE}" \
  --wait 5m

actual_image=$(docker inspect --format '{{.Config.Image}}' "${LOADBALANCER_CONTAINER}")
if [[ "${actual_image}" != "${LOADBALANCER_IMAGE}" ]]; then
  echo "external load balancer uses ${actual_image}, expected ${LOADBALANCER_IMAGE}" >&2
  exit 1
fi

docker exec "${LOADBALANCER_CONTAINER}" \
  haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg
"${KUBECTL_BIN}" --context "kind-${CLUSTER_NAME}" wait \
  --for=condition=Ready nodes \
  --all \
  --timeout=2m
"${KUBECTL_BIN}" --context "kind-${CLUSTER_NAME}" get --raw=/readyz
