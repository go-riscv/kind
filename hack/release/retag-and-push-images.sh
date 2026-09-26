#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

MODE="${1:-publish}"

if [[ "${MODE}" != "retag" && "${MODE}" != "push" && "${MODE}" != "publish" ]]; then
  echo "Usage: $0 [retag|push|publish]" >&2
  exit 1
fi

if [[ "${KIND_BUILD_PROFILE}" != "release" ]]; then
  echo "KIND_BUILD_PROFILE=release is required for image retag or publish" >&2
  exit 1
fi

if [[ "${RELEASE_TAG}" != "${KIND_RELEASE_TAG}" ]]; then
  echo "RELEASE_TAG must equal canonical KinD tag ${KIND_RELEASE_TAG}, got: ${RELEASE_TAG}" >&2
  exit 1
fi

image_sources_output=$(make -s -f "${ROOT_DIR}/pkg/common.mk" \
  REGISTRY="${REGISTRY}" print-release-image-refs)
if [[ -z "${image_sources_output}" ]]; then
  echo "pkg/common.mk did not provide release image references" >&2
  exit 1
fi
mapfile -t image_sources <<< "${image_sources_output}"

declare -a image_pairs=()
for source_ref in "${image_sources[@]}"; do
  [[ -n "${source_ref}" ]] || continue
  image_pairs+=("${source_ref}|${source_ref%:*}:${RELEASE_TAG}")
done

# Finish every read-only validation before the first tag or push. This avoids
# partially publishing a release when a later source is missing or stale.
for pair in "${image_pairs[@]}"; do
  IFS='|' read -r source_ref _ <<< "${pair}"
  if ! docker image inspect "${source_ref}" >/dev/null 2>&1; then
    echo "Missing source image: ${source_ref}" >&2
    exit 1
  fi
done

node_source="$(kind_source_image)"
if [[ ! -f "${NODE_IMAGE_ID_FILE}" ]]; then
  echo "Missing recorded node image ID: ${NODE_IMAGE_ID_FILE}" >&2
  exit 1
fi
IFS= read -r recorded_node_id < "${NODE_IMAGE_ID_FILE}"
if [[ ! "${recorded_node_id}" =~ ^sha256:[0-9a-f]{64}$ ]]; then
  echo "Invalid recorded node image ID in ${NODE_IMAGE_ID_FILE}" >&2
  exit 1
fi
actual_node_id=$(docker image inspect --format '{{.Id}}' "${node_source}")
if [[ "${actual_node_id}" != "${recorded_node_id}" ]]; then
  echo "Node image ${node_source} resolves to ${actual_node_id}, expected recorded candidate ${recorded_node_id}" >&2
  exit 1
fi

if [[ "${MODE}" == "push" ]]; then
  for pair in "${image_pairs[@]}"; do
    IFS='|' read -r source_ref target_ref <<< "${pair}"
    if ! docker image inspect "${target_ref}" >/dev/null 2>&1; then
      echo "Missing target image: ${target_ref}" >&2
      exit 1
    fi
    source_id=$(docker image inspect --format '{{.Id}}' "${source_ref}")
    target_id=$(docker image inspect --format '{{.Id}}' "${target_ref}")
    if [[ "${target_id}" != "${source_id}" ]]; then
      echo "Target image ${target_ref} resolves to ${target_id}, expected source ${source_ref} at ${source_id}" >&2
      exit 1
    fi
  done
  node_target="${NODE_IMAGE_REPO}:${RELEASE_TAG}"
  if ! docker image inspect "${node_target}" >/dev/null 2>&1; then
    echo "Missing target image: ${node_target}" >&2
    exit 1
  fi
  node_target_id=$(docker image inspect --format '{{.Id}}' "${node_target}")
  if [[ "${node_target_id}" != "${recorded_node_id}" ]]; then
    echo "Target image ${node_target} resolves to ${node_target_id}, expected recorded candidate ${recorded_node_id}" >&2
    exit 1
  fi
fi

if [[ "${MODE}" == "retag" || "${MODE}" == "publish" ]]; then
  for pair in "${image_pairs[@]}"; do
    IFS='|' read -r source_ref target_ref <<< "${pair}"
    docker tag "${source_ref}" "${target_ref}"
  done

  docker tag "${recorded_node_id}" "${NODE_IMAGE_REPO}:${RELEASE_TAG}"
fi

if [[ "${MODE}" == "push" || "${MODE}" == "publish" ]]; then
  for pair in "${image_pairs[@]}"; do
    IFS='|' read -r _ target_ref <<< "${pair}"
    docker push "${target_ref}"
  done
  docker push "${NODE_IMAGE_REPO}:${RELEASE_TAG}"
fi
