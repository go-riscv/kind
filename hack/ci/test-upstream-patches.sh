#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
TEST_DIR=$(mktemp -d)
trap 'rm -rf "${TEST_DIR}"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

metadata=$(make -s -f "${ROOT_DIR}/pkg/common.mk" print-release-metadata)
kind_tag=$(sed -n 's/^KIND_RELEASE_TAG=//p' <<< "${metadata}")
release_sha=$(sed -n 's/^SHA=//p' "${ROOT_DIR}/pkg/release/Makefile" | head -n1)

[[ "${kind_tag}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "invalid canonical KinD tag: ${kind_tag}"
[[ "${release_sha}" =~ ^[0-9a-f]{40}$ ]] || fail "invalid pinned kubernetes/release commit: ${release_sha}"

fetch_source() {
  local destination="$1"
  local repository="$2"
  local revision="$3"

  git init -q "${destination}"
  git -C "${destination}" remote add origin "${repository}"
  if [[ "${revision}" == refs/tags/* ]]; then
    git -C "${destination}" fetch --quiet --depth 1 origin "${revision}:${revision}"
    git -C "${destination}" checkout --quiet --detach "${revision}"
  else
    git -C "${destination}" fetch --quiet --depth 1 origin "${revision}"
    git -C "${destination}" checkout --quiet --detach FETCH_HEAD
  fi
}

apply_stack() {
  local source_dir="$1"
  local patch_dir="$2"
  local patch_file

  for patch_file in "${patch_dir}"/*; do
    patch --fuzz=0 --batch --forward --no-backup-if-mismatch \
      -d "${source_dir}" -p1 < "${patch_file}"
  done
  git -C "${source_dir}" diff --check
}

fetch_source \
  "${TEST_DIR}/release" \
  "${RELEASE_REPOSITORY:-https://github.com/kubernetes/release.git}" \
  "${release_sha}"
[[ "$(git -C "${TEST_DIR}/release" rev-parse HEAD)" == "${release_sha}" ]] ||
  fail "kubernetes/release checkout does not match ${release_sha}"

fetch_source \
  "${TEST_DIR}/kind" \
  "${KIND_REPOSITORY:-https://github.com/kubernetes-sigs/kind.git}" \
  "refs/tags/${kind_tag}"
[[ "$(git -C "${TEST_DIR}/kind" describe --tags --exact-match HEAD)" == "${kind_tag}" ]] ||
  fail "KinD checkout does not match ${kind_tag}"

apply_stack "${TEST_DIR}/release" "${ROOT_DIR}/pkg/release/patches"
apply_stack "${TEST_DIR}/kind" "${ROOT_DIR}/pkg/kind/patches"

echo "PASS: complete release and KinD patch stacks apply to their pinned pristine upstream sources with zero fuzz."
