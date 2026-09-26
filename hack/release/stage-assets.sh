#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

canonical_directory_target() {
  local path="$1"
  local parent
  local base

  if [[ -e "${path}" ]]; then
    [[ -d "${path}" ]] || return 1
    (cd "${path}" && pwd -P)
    return
  fi

  parent=$(dirname "${path}")
  base=$(basename "${path}")
  [[ -d "${parent}" ]] || return 1
  parent=$(cd "${parent}" && pwd -P)
  printf '%s/%s\n' "${parent}" "${base}"
}

path_is_same_or_ancestor() {
  local possible_ancestor="$1"
  local path="$2"
  [[ "${path}" == "${possible_ancestor}" || "${path}" == "${possible_ancestor}/"* ]]
}

paths_intersect() {
  path_is_same_or_ancestor "$1" "$2" || path_is_same_or_ancestor "$2" "$1"
}

dist_canonical=$(canonical_directory_target "${DIST_DIR}") || {
  echo "DIST_DIR must be a directory with an existing parent: ${DIST_DIR}" >&2
  exit 1
}
root_canonical=$(cd "${ROOT_DIR}" && pwd -P)
home_canonical=$(cd "${HOME}" && pwd -P)
bin_canonical=$(canonical_directory_target "${BIN_DIR}") || {
  echo "BIN_DIR must be an existing directory: ${BIN_DIR}" >&2
  exit 1
}
kubernetes_canonical=$(canonical_directory_target "${KUBERNETES_SOURCE_DIR}") || {
  echo "KUBERNETES_SOURCE_DIR must be an existing directory: ${KUBERNETES_SOURCE_DIR}" >&2
  exit 1
}
for protected in "${root_canonical}" "${home_canonical}"; do
  if [[ "${dist_canonical}" == "/" ]] || path_is_same_or_ancestor "${dist_canonical}" "${protected}"; then
    echo "Refusing unsafe DIST_DIR: ${dist_canonical}" >&2
    exit 1
  fi
done
if paths_intersect "${dist_canonical}" "${bin_canonical}"; then
  echo "DIST_DIR intersects BIN_DIR: ${dist_canonical}" >&2
  exit 1
fi
if paths_intersect "${dist_canonical}" "${kubernetes_canonical}"; then
  echo "DIST_DIR intersects KUBERNETES_SOURCE_DIR: ${dist_canonical}" >&2
  exit 1
fi
if path_is_same_or_ancestor "${root_canonical}" "${dist_canonical}" &&
   ! path_is_same_or_ancestor "${root_canonical}/dist" "${dist_canonical}"; then
  echo "DIST_DIR inside the repository must be under ${root_canonical}/dist: ${dist_canonical}" >&2
  exit 1
fi

# Use the proven canonical destination for ownership checks and all mutations.
DIST_DIR="${dist_canonical}"

mapfile -t recognized_staging_names < <(
  release_asset_names
  printf '%s\n' SHA256SUMS
)

is_recognized_staging_name() {
  local name="$1"
  local recognized
  for recognized in "${recognized_staging_names[@]}"; do
    [[ "${name}" == "${recognized}" ]] && return 0
  done
  return 1
}

if [[ -d "${DIST_DIR}" ]]; then
  if ! find "${DIST_DIR}" -mindepth 1 -maxdepth 1 -print0 |
    while IFS= read -r -d '' child; do
      child_name=${child##*/}
      if ! is_recognized_staging_name "${child_name}"; then
        echo "DIST_DIR contains unrelated entry: ${child}" >&2
        exit 1
      fi
      if [[ ! -f "${child}" && ! -L "${child}" ]]; then
        echo "DIST_DIR contains non-file staging entry: ${child}" >&2
        exit 1
      fi
    done; then
    echo "Unable to prove DIST_DIR ownership: ${DIST_DIR}" >&2
    exit 1
  fi
fi

while IFS=: read -r src asset; do
  [[ -n "${src}" && -n "${asset}" ]] || continue
  if [[ ! -f "${BIN_DIR}/${src}" ]]; then
    echo "Missing binary: ${BIN_DIR}/${src}" >&2
    exit 1
  fi
done < <(release_asset_pairs)

kubernetes_checkout="${KUBERNETES_SOURCE_DIR}"
actual_kubernetes_tag=$(git -C "${kubernetes_checkout}" describe --tags --exact-match HEAD)
if [[ "${actual_kubernetes_tag}" != "${KUBERNETES_VERSION}" ]]; then
  echo "Kubernetes source is ${actual_kubernetes_tag}, expected ${KUBERNETES_VERSION}" >&2
  exit 1
fi
kubernetes_commit=$(git -C "${kubernetes_checkout}" rev-parse HEAD)
# shellcheck disable=SC2153 # Assigned by the sourced canonical release environment.
if [[ "${kubernetes_commit}" != "${KUBERNETES_COMMIT}" ]]; then
  echo "Kubernetes source commit is ${kubernetes_commit}, expected ${KUBERNETES_COMMIT}" >&2
  exit 1
fi

mkdir -p "${DIST_DIR}"
for staged_name in "${recognized_staging_names[@]}"; do
  staged_path="${DIST_DIR}/${staged_name}"
  if [[ -e "${staged_path}" || -L "${staged_path}" ]]; then
    rm -f -- "${staged_path}"
  fi
done

while IFS=: read -r src asset; do
  [[ -n "${src}" && -n "${asset}" ]] || continue

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

sed \
  -e "s|@EXPECTED_KUBERNETES_VERSION@|${KUBERNETES_VERSION}|g" \
  -e "s|@EXPECTED_KUBERNETES_COMMIT@|${KUBERNETES_COMMIT}|g" \
  "${ROOT_DIR}/hack/ci/verify-published-release.sh" \
  > "${DIST_DIR}/verify-kind-release-riscv64.sh"
chmod 0755 "${DIST_DIR}/verify-kind-release-riscv64.sh"
