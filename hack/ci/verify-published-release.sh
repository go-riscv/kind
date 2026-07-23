#!/usr/bin/env bash

set -euo pipefail

RELEASE_TAG="${1:-}"
MODE="${RELEASE_SMOKE_MODE:-ha}"
REPOSITORY="${GITHUB_REPOSITORY:-go-riscv/kind}"
REGISTRY="${REGISTRY:-ghcr.io/go-riscv}"
ASSET_DIR="${ASSET_DIR:-${PWD}}"
CLUSTER_NAME="${CLUSTER_NAME:-release-consumer}"
KIND_WAIT="${KIND_WAIT:-10m}"
DOWNLOAD_RELEASE_ASSETS="${DOWNLOAD_RELEASE_ASSETS:-0}"

if [[ ! "${RELEASE_TAG}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "usage: $0 vX.Y.Z" >&2
  exit 1
fi

if [[ "${MODE}" != "default" && "${MODE}" != "single" && "${MODE}" != "ha" ]]; then
  echo "RELEASE_SMOKE_MODE must be default, single, or ha, got: ${MODE}" >&2
  exit 1
fi

temporary_asset_dir=""
kind_bin=""

cleanup() {
  if [[ -n "${kind_bin}" && -x "${kind_bin}" ]]; then
    "${kind_bin}" delete cluster --name "${CLUSTER_NAME}" >/dev/null 2>&1 || true
  fi
  if [[ -n "${temporary_asset_dir}" ]]; then
    rm -rf "${temporary_asset_dir}"
  fi
}
trap cleanup EXIT

if [[ "${DOWNLOAD_RELEASE_ASSETS}" == "1" ]]; then
  temporary_asset_dir=$(mktemp -d)
  ASSET_DIR="${temporary_asset_dir}"
  release_url="https://github.com/${REPOSITORY}/releases/download/${RELEASE_TAG}"
  for asset in kind-linux-riscv64 kubectl-linux-riscv64 kind-config-linux-riscv64.yaml SHA256SUMS; do
    curl --fail --location --retry 3 \
      --output "${ASSET_DIR}/${asset}" "${release_url}/${asset}"
  done
fi

kind_bin="${ASSET_DIR}/kind-linux-riscv64"
kubectl_bin="${ASSET_DIR}/kubectl-linux-riscv64"
release_config="${ASSET_DIR}/kind-config-linux-riscv64.yaml"

for asset in "${kind_bin}" "${kubectl_bin}" "${release_config}" "${ASSET_DIR}/SHA256SUMS"; do
  if [[ ! -f "${asset}" ]]; then
    echo "missing release asset: ${asset}" >&2
    exit 1
  fi
done

chmod 0755 "${kind_bin}" "${kubectl_bin}"
(
  cd "${ASSET_DIR}"
  sha256sum --ignore-missing -c SHA256SUMS
)

node_image="${REGISTRY}/node:${RELEASE_TAG}"
haproxy_image="${REGISTRY}/haproxy:${RELEASE_TAG}"
release_images=(node pause etcd kindnetd local-path-helper local-path-provisioner)
if [[ "${MODE}" == "ha" ]]; then
  release_images+=(haproxy)
fi

"${kind_bin}" delete cluster --name "${CLUSTER_NAME}" >/dev/null 2>&1 || true
for image in "${release_images[@]}"; do
  ref="${REGISTRY}/${image}:${RELEASE_TAG}"
  docker manifest inspect "${ref}" >/dev/null
  docker image rm -f "${ref}" >/dev/null 2>&1 || true
  if docker image inspect "${ref}" >/dev/null 2>&1; then
    echo "release image remained cached after removing its exact tag: ${ref}" >&2
    exit 1
  fi
done

# A release binary must not succeed by falling back to development-only tags.
docker image rm -f kindest/node:latest haproxy:riscv64 >/dev/null 2>&1 || true

cluster_args=()
if [[ "${MODE}" == "single" ]]; then
  cluster_args=(--config "${release_config}")
elif [[ "${MODE}" == "ha" ]]; then
  cluster_config="${ASSET_DIR}/kind-ha-linux-riscv64.yaml"
  sed 's/- role: worker/- role: control-plane\n- role: control-plane/' \
    "${release_config}" > "${cluster_config}"
  cluster_args=(--config "${cluster_config}")
fi

"${kind_bin}" create cluster \
  --name "${CLUSTER_NAME}" \
  "${cluster_args[@]}" \
  --wait "${KIND_WAIT}"

actual_node_image=$(docker inspect --format '{{.Config.Image}}' "${CLUSTER_NAME}-control-plane")
if [[ "${actual_node_image}" != "${node_image}" ]]; then
  echo "control-plane uses ${actual_node_image}, expected ${node_image}" >&2
  exit 1
fi
docker image inspect --format '{{range .RepoDigests}}{{println .}}{{end}}' "${node_image}" |
  grep -F "${REGISTRY}/node@sha256:" >/dev/null

if [[ "${MODE}" == "ha" ]]; then
  loadbalancer_container="${CLUSTER_NAME}-external-load-balancer"
  actual_haproxy_image=$(docker inspect --format '{{.Config.Image}}' "${loadbalancer_container}")
  if [[ "${actual_haproxy_image}" != "${haproxy_image}" ]]; then
    echo "external load balancer uses ${actual_haproxy_image}, expected ${haproxy_image}" >&2
    exit 1
  fi
  docker image inspect --format '{{range .RepoDigests}}{{println .}}{{end}}' "${haproxy_image}" |
    grep -F "${REGISTRY}/haproxy@sha256:" >/dev/null
  docker exec "${loadbalancer_container}" \
    haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg
fi

"${kubectl_bin}" --context "kind-${CLUSTER_NAME}" wait \
  --for=condition=Ready nodes --all --timeout=5m
"${kubectl_bin}" --context "kind-${CLUSTER_NAME}" get --raw=/readyz

echo "PASS: ${RELEASE_TAG} ${MODE} release pulled registry-backed images and became ready."
