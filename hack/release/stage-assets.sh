#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}"

while IFS=: read -r src asset; do
  [[ -n "${src}" && -n "${asset}" ]] || continue

  if [[ ! -f "${BIN_DIR}/${src}" ]]; then
    echo "Missing binary: ${BIN_DIR}/${src}" >&2
    exit 1
  fi

  cp "${BIN_DIR}/${src}" "${DIST_DIR}/${asset}"
  chmod 0755 "${DIST_DIR}/${asset}"
done < <(release_asset_pairs)

if [[ "${KIND_BUILD_PROFILE}" == "release" ]]; then
  sed \
    -e "s|@REGISTRY@|${REGISTRY}|g" \
    -e "s|@RELEASE_TAG@|${RELEASE_TAG}|g" \
    "${ROOT_DIR}/config/kind.release.yaml.tmpl" \
    > "${DIST_DIR}/kind-config-linux-riscv64.yaml"
else
  cp "${ROOT_DIR}/config/kind.yaml" "${DIST_DIR}/kind-config-linux-riscv64.yaml"
fi

install -m 0755 \
  "${ROOT_DIR}/hack/ci/verify-published-release.sh" \
  "${DIST_DIR}/verify-kind-release-riscv64.sh"
