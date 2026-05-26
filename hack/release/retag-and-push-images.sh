#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

MODE="${1:-publish}"

if [[ "${MODE}" != "retag" && "${MODE}" != "push" && "${MODE}" != "publish" ]]; then
  echo "Usage: $0 [retag|push|publish]" >&2
  exit 1
fi

if [[ -z "${RELEASE_TAG}" ]]; then
  echo "RELEASE_TAG must be set for image publishing" >&2
  exit 1
fi

mapfile -t image_sources < <(
  make -s -f "${ROOT_DIR}/pkg/common.mk" REGISTRY="${REGISTRY}" print-release-image-refs
)

if [[ ${#image_sources[@]} -eq 0 ]]; then
  echo "pkg/common.mk did not provide release image references" >&2
  exit 1
fi

declare -a image_pairs=()
for source_ref in "${image_sources[@]}"; do
  [[ -n "${source_ref}" ]] || continue
  image_pairs+=("${source_ref}|${source_ref%:*}:${RELEASE_TAG}")
done

retag() {
  local source_ref="$1"
  local target_ref="$2"

  if ! docker image inspect "${source_ref}" >/dev/null 2>&1; then
    echo "Missing source image: ${source_ref}" >&2
    exit 1
  fi

  docker tag "${source_ref}" "${target_ref}"
}

push_image() {
  local target_ref="$1"

  if ! docker image inspect "${target_ref}" >/dev/null 2>&1; then
    echo "Missing target image: ${target_ref}" >&2
    exit 1
  fi

  docker push "${target_ref}"
}

if [[ "${MODE}" == "retag" || "${MODE}" == "publish" ]]; then
  for pair in "${image_pairs[@]}"; do
    IFS='|' read -r source_ref target_ref <<< "${pair}"
    retag "${source_ref}" "${target_ref}"
  done

  node_source="$(kind_source_image)"
  docker tag "${node_source}" "${NODE_IMAGE_REPO}:${RELEASE_TAG}"
fi

if [[ "${MODE}" == "push" || "${MODE}" == "publish" ]]; then
  for pair in "${image_pairs[@]}"; do
    IFS='|' read -r _ target_ref <<< "${pair}"
    push_image "${target_ref}"
  done
  push_image "${NODE_IMAGE_REPO}:${RELEASE_TAG}"
fi
