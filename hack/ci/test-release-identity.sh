#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
TEST_DIR=$(mktemp -d)
UNREADABLE_DIST=""
cleanup_test_dir() {
  if [[ -n "${UNREADABLE_DIST}" ]]; then
    chmod 0700 "${UNREADABLE_DIST}" 2>/dev/null || true
  fi
  rm -rf "${TEST_DIR}"
}
trap cleanup_test_dir EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

metadata=$(make -s -f "${ROOT_DIR}/pkg/common.mk" print-release-metadata)
grep -Fx 'KIND_RELEASE_TAG=v0.33.0' <<< "${metadata}" >/dev/null || fail "wrong canonical KinD tag"
grep -Fx 'KUBERNETES_VERSION=v1.37.0' <<< "${metadata}" >/dev/null || fail "wrong canonical Kubernetes version"
canonical_kubernetes_commit='f54c212e3a2f75d674b717a9b29052b20b60aefc'
grep -Fx "KUBERNETES_COMMIT=${canonical_kubernetes_commit}" <<< "${metadata}" >/dev/null ||
  fail "wrong canonical Kubernetes commit"

if KIND_BUILD_PROFILE=release RELEASE_TAG=v0.34.0 bash -c \
  'source "$1/hack/release/env.sh"' _ "${ROOT_DIR}" >"${TEST_DIR}/mismatch.out" 2>&1; then
  fail "mismatched release tag was accepted"
fi
grep -F 'must equal canonical KinD tag v0.33.0' "${TEST_DIR}/mismatch.out" >/dev/null ||
  fail "mismatched release tag did not explain canonical value"

mkdir -p "${TEST_DIR}/bin"
cat > "${TEST_DIR}/bin/docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${DOCKER_LOG}"

if [[ "${TEST_DOCKER_MODE:-}" == "consumer" ]]; then
  if [[ "$1 $2" == "manifest inspect" || "$1 $2" == "image rm" ]]; then
    exit 0
  fi
  if [[ "$1 $2" == "image inspect" ]]; then
    if [[ "${3:-}" == "--format" ]]; then
      if [[ "${!#}" == *'/haproxy:'* ]]; then
        printf '%s\n' 'ghcr.io/go-riscv/haproxy@sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd'
      else
        printf '%s\n' 'ghcr.io/go-riscv/node@sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc'
      fi
      exit 0
    fi
    exit 1
  fi
  if [[ "$1" == "inspect" ]]; then
    if [[ "${!#}" == *external-load-balancer ]]; then
      printf '%s\n' 'ghcr.io/go-riscv/haproxy:v0.33.0'
    else
      printf '%s\n' 'ghcr.io/go-riscv/node:v0.33.0'
    fi
    exit 0
  fi
  [[ "$1" == "exec" ]] && exit 0
  exit 1
fi

if [[ "$1 $2" == "image inspect" ]]; then
  ref="${!#}"
  if [[ "${ref}" == "${NODE_IMAGE_SOURCE}" ]]; then
    [[ "${TEST_NODE_MODE}" != "missing" ]] || exit 1
    if [[ "${3:-}" == "--format" ]]; then
      if [[ "${TEST_NODE_MODE}" == "replaced" ]]; then
        printf '%s\n' 'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
      else
        printf '%s\n' 'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
      fi
    fi
  elif [[ "${3:-}" == "--format" ]]; then
    if [[ "${TEST_DEST_MODE:-matching}" == "wrong" && "${ref}" == *:v0.33.0 ]]; then
      printf '%s\n' 'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
    else
      printf '%s\n' 'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
    fi
  fi
  exit 0
fi

case "$1" in
  tag|push) exit 0 ;;
esac
exit 1
EOF
chmod 0755 "${TEST_DIR}/bin/docker"

recorded_id='sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
printf '%s\n' "${recorded_id}" > "${TEST_DIR}/node-image.id"

: > "${TEST_DIR}/docker.log"
if PATH="${TEST_DIR}/bin:${PATH}" \
  DOCKER_LOG="${TEST_DIR}/docker.log" \
  TEST_NODE_MODE=matching \
  NODE_IMAGE_SOURCE=kindest/node:expected \
  NODE_IMAGE_ID_FILE="${TEST_DIR}/node-image.id" \
  KIND_BUILD_PROFILE=local \
  RELEASE_TAG=v0.33.0 \
  "${ROOT_DIR}/hack/release/retag-and-push-images.sh" retag \
  >"${TEST_DIR}/direct-local.out" 2>&1; then
  fail "direct publishing entry accepted the local build profile"
fi
if grep -Eq '^(tag|push) ' "${TEST_DIR}/docker.log"; then
  fail "wrong direct-entry profile performed a tag or push"
fi

run_retag() {
  local mode="$1"
  : > "${TEST_DIR}/docker.log"
  PATH="${TEST_DIR}/bin:${PATH}" \
    DOCKER_LOG="${TEST_DIR}/docker.log" \
    TEST_NODE_MODE="${mode}" \
    NODE_IMAGE_SOURCE=kindest/node:expected \
    NODE_IMAGE_ID_FILE="${TEST_DIR}/node-image.id" \
    KIND_BUILD_PROFILE=release \
    RELEASE_TAG=v0.33.0 \
    "${ROOT_DIR}/hack/release/retag-and-push-images.sh" retag
}

for failure_mode in missing replaced; do
  if run_retag "${failure_mode}" >"${TEST_DIR}/${failure_mode}.out" 2>&1; then
    fail "${failure_mode} node source was accepted"
  fi
  if grep -Eq '^(tag|push) ' "${TEST_DIR}/docker.log"; then
    fail "${failure_mode} preflight performed a tag or push"
  fi
done

rm -f "${TEST_DIR}/node-image.id"
if run_retag matching >"${TEST_DIR}/missing-record.out" 2>&1; then
  fail "missing recorded node image ID was accepted"
fi
if grep -Eq '^(tag|push) ' "${TEST_DIR}/docker.log"; then
  fail "missing recorded node image ID performed a tag or push"
fi
printf '%s\n' "${recorded_id}" > "${TEST_DIR}/node-image.id"

run_retag matching
grep -Fx "tag ${recorded_id} ghcr.io/go-riscv/node:v0.33.0" "${TEST_DIR}/docker.log" >/dev/null ||
  fail "node release tag was not created from the recorded image ID"

first_mutation=$(grep -nE '^(tag|push) ' "${TEST_DIR}/docker.log" | head -n1 | cut -d: -f1)
node_id_inspect=$(grep -nF "image inspect --format {{.Id}} kindest/node:expected" "${TEST_DIR}/docker.log" | cut -d: -f1)
if [[ -z "${first_mutation}" || -z "${node_id_inspect}" || "${node_id_inspect}" -ge "${first_mutation}" ]]; then
  fail "node ID was not verified before the first mutation"
fi

: > "${TEST_DIR}/docker.log"
if PATH="${TEST_DIR}/bin:${PATH}" \
  DOCKER_LOG="${TEST_DIR}/docker.log" \
  TEST_NODE_MODE=matching \
  TEST_DEST_MODE=wrong \
  NODE_IMAGE_SOURCE=kindest/node:expected \
  NODE_IMAGE_ID_FILE="${TEST_DIR}/node-image.id" \
  KIND_BUILD_PROFILE=release \
  RELEASE_TAG=v0.33.0 \
  "${ROOT_DIR}/hack/release/retag-and-push-images.sh" push \
  >"${TEST_DIR}/wrong-destination.out" 2>&1; then
  fail "push accepted a destination image with the wrong ID"
fi
if grep -Eq '^(tag|push) ' "${TEST_DIR}/docker.log"; then
  fail "wrong destination preflight performed a tag or push"
fi

: > "${TEST_DIR}/docker.log"
PATH="${TEST_DIR}/bin:${PATH}" \
  DOCKER_LOG="${TEST_DIR}/docker.log" \
  TEST_NODE_MODE=matching \
  TEST_DEST_MODE=matching \
  NODE_IMAGE_SOURCE=kindest/node:expected \
  NODE_IMAGE_ID_FILE="${TEST_DIR}/node-image.id" \
  KIND_BUILD_PROFILE=release \
  RELEASE_TAG=v0.33.0 \
  "${ROOT_DIR}/hack/release/retag-and-push-images.sh" push
grep -Fx 'push ghcr.io/go-riscv/node:v0.33.0' "${TEST_DIR}/docker.log" >/dev/null ||
  fail "validated push-only mode did not push the recorded node destination"
if grep -Eq '^tag ' "${TEST_DIR}/docker.log"; then
  fail "push-only mode unexpectedly retagged an image"
fi

mkdir -p "${TEST_DIR}/safety-bin"
cat > "${TEST_DIR}/safety-bin/rm" <<'EOF'
#!/usr/bin/env bash
printf 'rm %s\n' "$*" >> "${MUTATION_LOG}"
exit 97
EOF
cat > "${TEST_DIR}/safety-bin/mkdir" <<'EOF'
#!/usr/bin/env bash
printf 'mkdir %s\n' "$*" >> "${MUTATION_LOG}"
exit 97
EOF
cat > "${TEST_DIR}/safety-bin/cp" <<'EOF'
#!/usr/bin/env bash
printf 'cp %s\n' "$*" >> "${MUTATION_LOG}"
exit 97
EOF
cat > "${TEST_DIR}/safety-bin/chmod" <<'EOF'
#!/usr/bin/env bash
printf 'chmod %s\n' "$*" >> "${MUTATION_LOG}"
exit 97
EOF
cat > "${TEST_DIR}/safety-bin/git" <<EOF
#!/usr/bin/env bash
set -euo pipefail
case "\$*" in
  *'describe --tags --exact-match HEAD') printf '%s\n' v1.37.0 ;;
  *'rev-parse HEAD')
    if [[ "\${TEST_GIT_MODE:-}" == wrong ]]; then
      printf '%s\n' ffffffffffffffffffffffffffffffffffffffff
    else
      printf '%s\n' '${canonical_kubernetes_commit}'
    fi
    ;;
  *) exit 1 ;;
esac
EOF
chmod 0755 "${TEST_DIR}/safety-bin/rm" "${TEST_DIR}/safety-bin/mkdir" \
  "${TEST_DIR}/safety-bin/cp" "${TEST_DIR}/safety-bin/chmod" "${TEST_DIR}/safety-bin/git"

mkdir -p "${TEST_DIR}/safety-assets" "${TEST_DIR}/safety-kubernetes" \
  "${TEST_DIR}/safe-dist" "${TEST_DIR}/recognized-preflight-dist" \
  "${TEST_DIR}/recognized-directory-dist/kind-linux-riscv64"
for binary in kind kubectl kubeadm; do
  printf '#!/usr/bin/env bash\nexit 0\n' > "${TEST_DIR}/safety-assets/${binary}"
  chmod 0755 "${TEST_DIR}/safety-assets/${binary}"
done
printf 'keep\n' > "${TEST_DIR}/safety-assets/sentinel"
printf 'keep\n' > "${TEST_DIR}/safety-kubernetes/sentinel"
printf 'keep\n' > "${TEST_DIR}/safe-dist/sentinel"
printf 'keep\n' > "${TEST_DIR}/recognized-preflight-dist/kind-linux-riscv64"
printf 'keep\n' > "${TEST_DIR}/recognized-directory-dist/kind-linux-riscv64/sentinel"
mkdir -p "${TEST_DIR}/private-tmp-style/unrelated-directory"
printf 'keep\n' > "${TEST_DIR}/private-tmp-style/unrelated-directory/sentinel"
UNREADABLE_DIST="${TEST_DIR}/unreadable-dist"
mkdir -p "${UNREADABLE_DIST}"
printf 'keep\n' > "${UNREADABLE_DIST}/sentinel"

assert_stage_rejected_without_mutation() {
  local label="$1"
  local dist_dir="$2"
  local bin_dir="${3:-${TEST_DIR}/safety-assets}"
  local source_dir="${4:-${TEST_DIR}/safety-kubernetes}"
  local git_mode="${5:-matching}"

  : > "${TEST_DIR}/mutation.log"
  if PATH="${TEST_DIR}/safety-bin:${PATH}" \
    MUTATION_LOG="${TEST_DIR}/mutation.log" \
    TEST_GIT_MODE="${git_mode}" \
    BIN_DIR="${bin_dir}" \
    DIST_DIR="${dist_dir}" \
    KUBERNETES_SOURCE_DIR="${source_dir}" \
    KIND_BUILD_PROFILE=release \
    RELEASE_TAG=v0.33.0 \
    "${ROOT_DIR}/hack/release/stage-assets.sh" >"${TEST_DIR}/${label}.out" 2>&1; then
    fail "stage-assets accepted ${label}"
  fi
  [[ ! -s "${TEST_DIR}/mutation.log" ]] ||
    fail "${label} caused a filesystem mutation"
}

assert_stage_rejected_without_mutation dist-is-bin "${TEST_DIR}/safety-assets"
assert_stage_rejected_without_mutation dist-is-source "${TEST_DIR}/safety-kubernetes"
assert_stage_rejected_without_mutation dist-is-pkg "${ROOT_DIR}/pkg"
assert_stage_rejected_without_mutation dist-is-repo "${ROOT_DIR}"
assert_stage_rejected_without_mutation dist-is-home "${HOME}"
assert_stage_rejected_without_mutation dist-is-root /
assert_stage_rejected_without_mutation dist-is-home-parent "$(dirname "${HOME}")"
assert_stage_rejected_without_mutation missing-binary "${TEST_DIR}/recognized-preflight-dist" "${TEST_DIR}/missing-assets"
assert_stage_rejected_without_mutation wrong-source-commit "${TEST_DIR}/recognized-preflight-dist" \
  "${TEST_DIR}/safety-assets" "${TEST_DIR}/safety-kubernetes" wrong
assert_stage_rejected_without_mutation unrelated-external-content "${TEST_DIR}/safe-dist"
assert_stage_rejected_without_mutation private-tmp-style-content "${TEST_DIR}/private-tmp-style"
assert_stage_rejected_without_mutation recognized-name-directory "${TEST_DIR}/recognized-directory-dist"
chmod 0300 "${UNREADABLE_DIST}"
if ! find "${UNREADABLE_DIST}" -mindepth 1 -maxdepth 1 -print >/dev/null 2>&1; then
  assert_stage_rejected_without_mutation unreadable-content "${UNREADABLE_DIST}"
fi
chmod 0700 "${UNREADABLE_DIST}"
grep -Fx keep "${TEST_DIR}/safety-assets/sentinel" >/dev/null || fail "DIST_DIR=BIN_DIR deleted its sentinel"
grep -Fx keep "${TEST_DIR}/safety-kubernetes/sentinel" >/dev/null || fail "DIST_DIR=KUBERNETES_SOURCE_DIR deleted its sentinel"
grep -Fx keep "${TEST_DIR}/safe-dist/sentinel" >/dev/null || fail "preflight failure deleted its destination sentinel"
grep -Fx keep "${TEST_DIR}/recognized-preflight-dist/kind-linux-riscv64" >/dev/null ||
  fail "binary or source preflight failure deleted a recognized staged output"
grep -Fx keep "${TEST_DIR}/private-tmp-style/unrelated-directory/sentinel" >/dev/null ||
  fail "external unrelated directory sentinel was deleted"
grep -Fx keep "${UNREADABLE_DIST}/sentinel" >/dev/null || fail "unreadable destination sentinel was deleted"
grep -Fx keep "${TEST_DIR}/recognized-directory-dist/kind-linux-riscv64/sentinel" >/dev/null ||
  fail "recognized-name directory sentinel was deleted"

mkdir -p "${TEST_DIR}/kubernetes" "${TEST_DIR}/assets"
git -C "${TEST_DIR}/kubernetes" init -q
git -C "${TEST_DIR}/kubernetes" config user.name test
git -C "${TEST_DIR}/kubernetes" config user.email test@example.invalid
printf '%s\n' fixture > "${TEST_DIR}/kubernetes/README"
git -C "${TEST_DIR}/kubernetes" add README
git -C "${TEST_DIR}/kubernetes" commit -qm fixture
git -C "${TEST_DIR}/kubernetes" tag v1.37.0
kubernetes_commit="${canonical_kubernetes_commit}"
cat > "${TEST_DIR}/bin/git" <<EOF
#!/usr/bin/env bash
set -euo pipefail
case "\$*" in
  *'describe --tags --exact-match HEAD') printf '%s\n' v1.37.0 ;;
  *'rev-parse HEAD')
    if [[ "\${TEST_GIT_MODE:-}" == wrong ]]; then
      printf '%s\n' ffffffffffffffffffffffffffffffffffffffff
    else
      printf '%s\n' '${canonical_kubernetes_commit}'
    fi
    ;;
  *) exit 1 ;;
esac
EOF
chmod 0755 "${TEST_DIR}/bin/git"
cat > "${TEST_DIR}/assets/kind" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${KIND_LOG}"
EOF
chmod 0755 "${TEST_DIR}/assets/kind"
printf '#!/usr/bin/env bash\nexit 0\n' > "${TEST_DIR}/assets/kubeadm"
chmod 0755 "${TEST_DIR}/assets/kubeadm"
cat > "${TEST_DIR}/assets/kubectl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
  *'get --raw=/version'*)
    printf '{"gitVersion":"%s","gitCommit":"%s"}\n' "${STUB_KUBERNETES_VERSION}" "${STUB_KUBERNETES_COMMIT}"
    ;;
  *'get --raw=/readyz'*) printf 'ok\n' ;;
  *) exit 0 ;;
esac
EOF
chmod 0755 "${TEST_DIR}/assets/kubectl"

PATH="${TEST_DIR}/bin:${PATH}" \
  BIN_DIR="${TEST_DIR}/assets" \
  DIST_DIR="${TEST_DIR}/dist" \
  KUBERNETES_SOURCE_DIR="${TEST_DIR}/kubernetes" \
  KIND_BUILD_PROFILE=release \
  RELEASE_TAG=v0.33.0 \
  "${ROOT_DIR}/hack/release/stage-assets.sh"

generated_verifier="${TEST_DIR}/dist/verify-kind-release-riscv64.sh"
grep -F 'EXPECTED_KUBERNETES_VERSION="v1.37.0"' "${generated_verifier}" >/dev/null ||
  fail "generated verifier lacks canonical Kubernetes version"
grep -F "EXPECTED_KUBERNETES_COMMIT=\"${kubernetes_commit}\"" "${generated_verifier}" >/dev/null ||
  fail "generated verifier lacks checked-out Kubernetes commit"
if grep -F 'RELEASE_TAG}" == "v0.33.0' "${generated_verifier}" >/dev/null; then
  fail "generated verifier retains a v0.33.0-only condition"
fi
bash -n "${generated_verifier}"
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "${generated_verifier}"
else
  echo "SKIP: shellcheck is unavailable; Bash syntax validation completed." >&2
fi

(
  cd "${TEST_DIR}/dist"
  sha256sum kind-linux-riscv64 kubectl-linux-riscv64 kubeadm-linux-riscv64 \
    kind-config-linux-riscv64.yaml verify-kind-release-riscv64.sh > SHA256SUMS
)

mapfile -t staged_assets < <(find "${TEST_DIR}/dist" -maxdepth 1 -type f -exec basename {} \; | sort)
expected_staged_assets=(
  SHA256SUMS
  kind-config-linux-riscv64.yaml
  kind-linux-riscv64
  kubeadm-linux-riscv64
  kubectl-linux-riscv64
  verify-kind-release-riscv64.sh
)
[[ "${staged_assets[*]}" == "${expected_staged_assets[*]}" ]] ||
  fail "staging produced an unexpected asset inventory: ${staged_assets[*]}"

PATH="${TEST_DIR}/bin:${PATH}" \
  BIN_DIR="${TEST_DIR}/assets" \
  DIST_DIR="${TEST_DIR}/dist" \
  KUBERNETES_SOURCE_DIR="${TEST_DIR}/kubernetes" \
  KIND_BUILD_PROFILE=release \
  RELEASE_TAG=v0.33.0 \
  "${ROOT_DIR}/hack/release/stage-assets.sh"
(
  cd "${TEST_DIR}/dist"
  sha256sum kind-linux-riscv64 kubectl-linux-riscv64 kubeadm-linux-riscv64 \
    kind-config-linux-riscv64.yaml verify-kind-release-riscv64.sh > SHA256SUMS
)
mapfile -t restaged_assets < <(find "${TEST_DIR}/dist" -maxdepth 1 -type f -exec basename {} \; | sort)
[[ "${restaged_assets[*]}" == "${expected_staged_assets[*]}" ]] ||
  fail "recognized prior outputs could not be restaged to the exact six-file inventory: ${restaged_assets[*]}"

mkdir -p "${TEST_DIR}/version-bin"
cat > "${TEST_DIR}/version-bin/kind" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' 'kind v0.33.0 go1.26.7 linux/riscv64'
EOF
cat > "${TEST_DIR}/version-bin/kubectl" <<'EOF'
#!/usr/bin/env bash
printf '{"clientVersion":{"gitVersion":"%s","gitCommit":"%s"}}\n' \
  "${STUB_BINARY_VERSION}" "${STUB_KUBERNETES_COMMIT}"
EOF
cp "${TEST_DIR}/version-bin/kubectl" "${TEST_DIR}/version-bin/kubeadm"
chmod 0755 "${TEST_DIR}/version-bin/kind" \
  "${TEST_DIR}/version-bin/kubectl" "${TEST_DIR}/version-bin/kubeadm"

run_version_pair() {
  PATH="${TEST_DIR}/bin:${PATH}" \
    BIN_DIR="${TEST_DIR}/version-bin" \
    STUB_BINARY_VERSION="$1" \
    STUB_KUBERNETES_COMMIT="${kubernetes_commit}" \
    "${ROOT_DIR}/hack/release/verify-version-pair.sh"
}

run_version_pair v1.37.0 >/dev/null
if run_version_pair v1.37.0-dirty >"${TEST_DIR}/dirty-binary.out" 2>&1; then
  fail "binary version verification accepted dirty Kubernetes provenance"
fi

run_consumer() {
  PATH="${TEST_DIR}/bin:${PATH}" \
    DOCKER_LOG="${TEST_DIR}/docker.log" \
    KIND_LOG="${TEST_DIR}/kind.log" \
    TEST_DOCKER_MODE=consumer \
    STUB_KUBERNETES_VERSION="$1" \
    STUB_KUBERNETES_COMMIT="$2" \
    ASSET_DIR="${TEST_DIR}/dist" \
    RELEASE_SMOKE_MODE="$3" \
    "${generated_verifier}" v0.33.0
}

for smoke_mode in default single ha; do
  : > "${TEST_DIR}/kind.log"
  run_consumer v1.37.0 "${kubernetes_commit}" "${smoke_mode}" >/dev/null
  create_command=$(grep '^create cluster ' "${TEST_DIR}/kind.log")
  case "${smoke_mode}" in
    default)
      [[ "${create_command}" != *'--config'* ]] ||
        fail "default consumer mode unexpectedly passed --config: ${create_command}"
      ;;
    single)
      [[ "${create_command}" == *"--config ${TEST_DIR}/dist/kind-config-linux-riscv64.yaml"* ]] ||
        fail "single consumer mode did not use the released config: ${create_command}"
      ;;
    ha)
      [[ "${create_command}" == *"--config ${TEST_DIR}/dist/kind-ha-linux-riscv64.yaml"* ]] ||
        fail "HA consumer mode did not use its generated config: ${create_command}"
      [[ $(grep -c '^- role: control-plane$' "${TEST_DIR}/dist/kind-ha-linux-riscv64.yaml") -eq 3 ]] ||
        fail "generated HA config does not contain exactly three control-plane roles"
      [[ $(grep -c '^- role: worker$' "${TEST_DIR}/dist/kind-ha-linux-riscv64.yaml" || true) -eq 0 ]] ||
        fail "generated HA config still contains a worker role"
      ;;
  esac
done
if run_consumer v1.38.0 "${kubernetes_commit}" default >"${TEST_DIR}/wrong-version.out" 2>&1; then
  fail "generated verifier accepted the wrong Kubernetes version"
fi
if run_consumer v1.37.0 ffffffffffffffffffffffffffffffffffffffff default >"${TEST_DIR}/wrong-commit.out" 2>&1; then
  fail "generated verifier accepted the wrong Kubernetes commit"
fi
if run_consumer v1.37.0-dirty "${kubernetes_commit}" default >"${TEST_DIR}/dirty-server.out" 2>&1; then
  fail "generated verifier accepted dirty Kubernetes server provenance"
fi

mkdir -p "${TEST_DIR}/download-source"
cp "${TEST_DIR}/dist/kind-linux-riscv64" \
  "${TEST_DIR}/dist/kubectl-linux-riscv64" \
  "${TEST_DIR}/dist/kind-config-linux-riscv64.yaml" \
  "${TEST_DIR}/dist/SHA256SUMS" \
  "${TEST_DIR}/download-source/"
cat > "${TEST_DIR}/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
output=""
url=""
while (($#)); do
  case "$1" in
    --output) output="$2"; shift 2 ;;
    http*) url="$1"; shift ;;
    *) shift ;;
  esac
done
cp "${DOWNLOAD_SOURCE}/$(basename "${url}")" "${output}"
EOF
chmod 0755 "${TEST_DIR}/bin/curl"
PATH="${TEST_DIR}/bin:${PATH}" \
  DOCKER_LOG="${TEST_DIR}/docker.log" \
  KIND_LOG="${TEST_DIR}/kind.log" \
  TEST_DOCKER_MODE=consumer \
  STUB_KUBERNETES_VERSION=v1.37.0 \
  STUB_KUBERNETES_COMMIT="${kubernetes_commit}" \
  DOWNLOAD_SOURCE="${TEST_DIR}/download-source" \
  DOWNLOAD_RELEASE_ASSETS=1 \
  RELEASE_SMOKE_MODE=single \
  "${generated_verifier}" v0.33.0 >/dev/null

echo "PASS: canonical release identity and node candidate provenance are enforced."
