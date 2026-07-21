#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

if [[ "${KIND_BUILD_PROFILE}" != "release" ]]; then
  echo "Published-image verification requires KIND_BUILD_PROFILE=release" >&2
  exit 1
fi

mapfile -t source_refs < <(
  make -s -f "${ROOT_DIR}/pkg/common.mk" REGISTRY="${REGISTRY}" print-release-image-refs
)

for source_ref in "${source_refs[@]}"; do
  target_ref="${source_ref%:*}:${RELEASE_TAG}"
  docker manifest inspect "${target_ref}" >/dev/null
  echo "Verified published image: ${target_ref}"
done

docker manifest inspect "${NODE_IMAGE_REPO}:${RELEASE_TAG}" >/dev/null
echo "Verified published image: ${NODE_IMAGE_REPO}:${RELEASE_TAG}"
