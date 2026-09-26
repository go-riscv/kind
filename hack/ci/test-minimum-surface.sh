#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

for path in \
  pkg/golang \
  pkg/protobuf \
  .github/workflows/baseline-images.yaml \
  docs/ci-baseline-policy.md \
  hack/release/baseline-images.env.example \
  hack/release/verify-baseline-images.sh \
  hack/release/verify-no-apt-pr-path.sh \
  hack/ci/verify-ci-baseline-optimization.sh \
  config/alpine.yaml; do
  [[ ! -e "${ROOT_DIR}/${path}" ]] || fail "removed surface remains: ${path}"
done

grep -F 'PKG_LIST := release etcd kubernetes kind' "${ROOT_DIR}/Makefile" >/dev/null ||
  fail "root package list is not the minimum retained set"
if grep -Eq 'OPTIONAL_PKG_LIST|kind-cluster|app-deploy|kind-cluster-delete|verify-ci-baseline-optimization' "${ROOT_DIR}/Makefile"; then
  fail "removed root target wiring remains"
fi

grep -F 'DEBIAN_SUITE=trixie' "${ROOT_DIR}/pkg/common.mk" >/dev/null || fail "Trixie pin was removed"
grep -F 'GOLANG_VERSION=' "${ROOT_DIR}/pkg/common.mk" >/dev/null || fail "Go version pin was removed"
# shellcheck disable=SC2016 # Match the literal Make variable reference.
grep -F 'GO_TOOLCHAIN_VERSION=$(GOLANG_VERSION)' "${ROOT_DIR}/pkg/common.mk" >/dev/null || fail "Go toolchain pin was removed"
if grep -Eq 'GOLANG_IMAGE|PROTOBUF_VERSION|PROTOC_ZIP|BASELINE_IMAGE_REFS|print-baseline-image-refs' "${ROOT_DIR}/pkg/common.mk"; then
  fail "unused optional-build declarations remain"
fi
grep -F 'KUBERNETES_COMMIT=f54c212e3a2f75d674b717a9b29052b20b60aefc' "${ROOT_DIR}/pkg/common.mk" >/dev/null ||
  fail "canonical Kubernetes commit pin is missing"
if grep -q '^DEBIAN_VERSION=' "${ROOT_DIR}/pkg/common.mk"; then
  fail "unused Debian version declaration remains"
fi
if grep -F 'v1\.37\.0' "${ROOT_DIR}/hack/release/verify-version-pair.sh" >/dev/null; then
  fail "version verifier contains a literal Kubernetes release regex"
fi

cross_patch="${ROOT_DIR}/pkg/release/patches/cross.patch"
grep -F 'apt-get install -y protobuf-compiler' "${cross_patch}" >/dev/null || fail "RISC-V apt protoc path was removed"
grep -F 'wget "https://github.com/protocolbuffers/protobuf/releases/download/' "${cross_patch}" >/dev/null ||
  fail "non-RISC-V upstream protoc download was removed"
if grep -Eq 'COPY precompiled|/precompiled|linux-riscv_64.zip' "${cross_patch}"; then
  fail "removed precompiled protoc path remains"
fi
for suite in bookworm bullseye; do
  grep -F "distroless-${suite}/Dockerfile" "${ROOT_DIR}/pkg/release/patches/distroless-iptables.patch" >/dev/null ||
    fail "legacy ${suite} patch hunk was removed"
done

grep -F 'BUILDX_CONTAINER_CACHE_ARGS' "${ROOT_DIR}/.github/workflows/ci.yaml" >/dev/null || fail "CI buildx cache was removed"
grep -F 'BUILDX_CONTAINER_CACHE_ARGS' "${ROOT_DIR}/.github/workflows/release.yaml" >/dev/null || fail "release buildx cache was removed"
for workflow in ci.yaml release.yaml; do
  workflow_path="${ROOT_DIR}/.github/workflows/${workflow}"
  if command -v ruby >/dev/null 2>&1; then
    ruby -e 'require "yaml"; YAML.load_file(ARGV.fetch(0))' "${workflow_path}" || fail "invalid workflow YAML: ${workflow}"
  elif python3 -c 'import sys, yaml; assert isinstance(yaml.safe_load(open(sys.argv[1])), dict)' "${workflow_path}"; then
    :
  else
    fail "no working Ruby YAML or Python PyYAML parser for ${workflow}"
  fi
done

assert_action_pin() {
  local workflow="$1"
  local action="$2"
  local commit="$3"
  local version="$4"
  grep -F "uses: ${action}@${commit} # ${version}" "${ROOT_DIR}/.github/workflows/${workflow}" >/dev/null ||
    fail "${workflow} does not pin ${action} to ${version} (${commit})"
}
assert_action_pin ci.yaml actions/cache 0057852bfaa89a56745cba8c7296529d2fc39830 v4.3.0
assert_action_pin ci.yaml actions/upload-artifact ea165f8d65b6e75b540449e92b4886f43607fa02 v4.6.2
assert_action_pin release.yaml actions/cache 0057852bfaa89a56745cba8c7296529d2fc39830 v4.3.0
assert_action_pin release.yaml docker/login-action c94ce9fb468520275223c153574b00df6fe4bcc9 v3.7.0
assert_action_pin release.yaml softprops/action-gh-release 3bb12739c298aeb8a4eeaf626c5b8d85266b0e65 v2.6.2
if grep -ER 'uses: [^ ]+@(v[0-9]+|latest|main|master)([[:space:]#]|$)' "${ROOT_DIR}/.github/workflows"; then
  fail "workflow contains a mutable action reference"
fi

go_licenses_patch="${ROOT_DIR}/pkg/kind/patches/images_base.patch"
go_licenses_pin_count=$(grep -Ec '^\+.*github\.com/google/go-licenses@v1\.6\.0' "${go_licenses_patch}")
[[ "${go_licenses_pin_count}" -eq 3 ]] ||
  fail "all KinD image builders must pin go-licenses v1.6.0 (5348b744d0983d85713295ea08a20cca1654a45e)"
if grep -E '^\+.*github\.com/google/go-licenses@latest' "${go_licenses_patch}" >/dev/null; then
  fail "go-licenses still uses @latest"
fi

grep -F "KUBE_GIT_TREE_STATE='clean'" "${ROOT_DIR}/pkg/common.mk" >/dev/null ||
  fail "Kubernetes version metadata is not fixed to the pinned clean release"
# shellcheck disable=SC2016 # Match the literal Make variable reference.
grep -F 'KUBE_GIT_VERSION_FILE=$(KUBE_VERSION_FILE)' "${ROOT_DIR}/pkg/kind/Makefile" >/dev/null ||
  fail "KinD node image build does not consume pinned Kubernetes version metadata"
# shellcheck disable=SC2016 # Match the literal Make variable reference.
grep -F 'build node-image --image "$(NODE_IMAGE_SOURCE)"' "${ROOT_DIR}/pkg/kind/Makefile" >/dev/null ||
  fail "KinD node producer is not bound to NODE_IMAGE_SOURCE"
# shellcheck disable=SC2016 # Match the literal Make variable reference.
[[ $(grep -Fc 'KUBE_GIT_VERSION_FILE=$(KUBE_VERSION_FILE)' "${ROOT_DIR}/pkg/kubernetes/Makefile") -eq 2 ]] ||
  fail "kubectl and kubeadm builds do not both consume pinned Kubernetes version metadata"

mapfile -t assets < <(
  ROOT_DIR="${ROOT_DIR}" bash -c 'source "$ROOT_DIR/hack/release/env.sh"; release_asset_names'
)
expected_assets=(
  kind-linux-riscv64
  kubectl-linux-riscv64
  kubeadm-linux-riscv64
  kind-config-linux-riscv64.yaml
  verify-kind-release-riscv64.sh
)
[[ "${assets[*]}" == "${expected_assets[*]}" ]] || fail "unexpected retained release assets: ${assets[*]}"
for workflow in ci.yaml release.yaml; do
  for asset in "${expected_assets[@]}" SHA256SUMS; do
    grep -F "dist/release/${asset}" "${ROOT_DIR}/.github/workflows/${workflow}" >/dev/null ||
      fail "${workflow} omits asset: ${asset}"
  done
  mapfile -t workflow_assets < <(
    grep -Eo 'dist/release/[A-Za-z0-9._-]+' "${ROOT_DIR}/.github/workflows/${workflow}" |
      sed 's|.*/||' |
      sort -u
  )
  expected_workflow_assets=(SHA256SUMS "${expected_assets[@]}")
  mapfile -t expected_workflow_assets < <(printf '%s\n' "${expected_workflow_assets[@]}" | sort)
  [[ "${workflow_assets[*]}" == "${expected_workflow_assets[*]}" ]] ||
    fail "${workflow} references an unexpected release asset inventory: ${workflow_assets[*]}"
done
grep -F 'future release contract contains exactly six assets' "${ROOT_DIR}/README.md" >/dev/null || fail "README does not state the future six-asset contract"
grep -F 'already-published v0.33.0 release remains unchanged with seven assets' "${ROOT_DIR}/README.md" >/dev/null ||
  fail "README does not preserve the published v0.33.0 history"
grep -F "it also contains \`k9s-linux-riscv64\`" "${ROOT_DIR}/README.md" >/dev/null ||
  fail "README does not name the historical seventh v0.33.0 asset"
for asset in "${expected_assets[@]}" SHA256SUMS; do
  grep -F -- "- \`${asset}\`" "${ROOT_DIR}/README.md" >/dev/null || fail "README omits asset: ${asset}"
done

removed_dashboard=$(printf '\153\071\163')
if rg -i --glob '!.git/**' --glob '!.omx/**' --glob '!.omx-state-locks/**' \
  --glob '!README.md' --glob '!hack/ci/test-minimum-surface.sh' "${removed_dashboard}" "${ROOT_DIR}" >/dev/null; then
  fail "removed dashboard integration remains in tracked source"
fi
if rg --glob '!.git/**' --glob '!.omx/**' --glob '!.omx-state-locks/**' \
  --glob '!hack/ci/test-minimum-surface.sh' 'USE_PREBUILT_BASELINES|NO_APT_PR_CI|verify-baseline-images' "${ROOT_DIR}" >/dev/null; then
  fail "removed baseline/no-apt feature wiring remains"
fi

echo "PASS: repository exposes only the retained KinD and Kubernetes release surface."
