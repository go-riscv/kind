#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
TEST_DIR=$(mktemp -d)
trap 'rm -rf "${TEST_DIR}"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

for package in release etcd kubernetes kind; do
  make_db="${TEST_DIR}/${package}.make-db"
  make_status=0
  make -qp -C "${ROOT_DIR}/pkg/${package}" > "${make_db}" 2>/dev/null || make_status=$?
  [[ "${make_status}" -eq 0 || "${make_status}" -eq 1 ]] || fail "could not inspect pkg/${package} make database"
  default_goal=$(sed -n 's/^\.DEFAULT_GOAL := //p' "${make_db}" | tail -n1)
  [[ "${default_goal}" == "all" ]] || fail "pkg/${package} default goal is ${default_goal:-unset}"
done
make -s -f "${ROOT_DIR}/pkg/common.mk" print-release-metadata >/dev/null

mkdir -p "${TEST_DIR}/packages" "${TEST_DIR}/bin" "${TEST_DIR}/dist"
for package in release etcd kubernetes kind; do
  mkdir -p "${TEST_DIR}/packages/${package}"
  if [[ "${package}" == "etcd" ]]; then
    result=false
  else
    result=true
  fi
  # shellcheck disable=SC2016 # TEST_LOG is expanded by the fixture Makefile.
  printf 'all:\n\t@printf "%%s\\n" "%s" >> "$(TEST_LOG)"\n\t@%s\n' \
    "${package}" "${result}" > "${TEST_DIR}/packages/${package}/Makefile"
done

export TEST_LOG="${TEST_DIR}/package-order.log"
if (
  cd "${ROOT_DIR}"
  make -f Makefile \
    PKG_DIR="${TEST_DIR}/packages" \
    BIN_DIR="${TEST_DIR}/bin" \
    DIST_DIR="${TEST_DIR}/dist" \
    all
) >/dev/null 2>&1; then
  fail "root all accepted an intermediate package failure"
fi
[[ "$(tr '\n' ' ' < "${TEST_LOG}")" == "release etcd " ]] ||
  fail "root all did not stop immediately after the failing package"

make_driver() {
  local name="$1"
  local delay="$2"
  cat > "${TEST_DIR}/${name}" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s-start\n' '${name}' >> "\${TEST_LOG}"
sleep '${delay}'
printf '%s-done\n' '${name}' >> "\${TEST_LOG}"
EOF
  chmod 0755 "${TEST_DIR}/${name}"
}

make_driver images 0.05
make_driver binaries 0.05
make_driver stage 0.05
make_driver checksums 0.05
make_driver publish 0.05
: > "${TEST_LOG}"
(
  cd "${ROOT_DIR}"
  make -j8 -f Makefile \
    BUILD_IMAGES_SCRIPT="${TEST_DIR}/images" \
    BUILD_BINARIES_SCRIPT="${TEST_DIR}/binaries" \
    STAGE_ASSETS_SCRIPT="${TEST_DIR}/stage" \
    WRITE_CHECKSUMS_SCRIPT="${TEST_DIR}/checksums" \
    PUBLISH_IMAGES_SCRIPT="${TEST_DIR}/publish" \
    BIN_DIR="${TEST_DIR}/bin" \
    DIST_DIR="${TEST_DIR}/dist" \
    release-publish
) >/dev/null
expected_order='images-start images-done binaries-start binaries-done stage-start stage-done checksums-start checksums-done publish-start publish-done '
[[ "$(tr '\n' ' ' < "${TEST_LOG}")" == "${expected_order}" ]] ||
  fail "release-publish did not preserve image/binary/stage/checksum/publish order"

mkdir -p "${TEST_DIR}/upstream" "${TEST_DIR}/patches" "${TEST_DIR}/docker-bin"
git -C "${TEST_DIR}/upstream" init -q
git -C "${TEST_DIR}/upstream" config user.name test
git -C "${TEST_DIR}/upstream" config user.email test@example.invalid
printf 'base\n' > "${TEST_DIR}/upstream/source.txt"
git -C "${TEST_DIR}/upstream" add source.txt
git -C "${TEST_DIR}/upstream" commit -qm base
release_sha=$(git -C "${TEST_DIR}/upstream" rev-parse HEAD)
printf 'base\npatched\n' > "${TEST_DIR}/upstream/source.txt"
git -C "${TEST_DIR}/upstream" diff > "${TEST_DIR}/patches/fixture.patch"
git -C "${TEST_DIR}/upstream" checkout -q -- source.txt
cat > "${TEST_DIR}/docker-bin/docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "$*" == "buildx use default" ]]
EOF
chmod 0755 "${TEST_DIR}/docker-bin/docker"

release_build_dir="${TEST_DIR}/release-build"
release_target="${release_build_dir}/release"
patched_tree=""
for _ in 1 2; do
  PATH="${TEST_DIR}/docker-bin:${PATH}" make -s -C "${ROOT_DIR}/pkg/release" \
    BUILD_DIR="${release_build_dir}" \
    PATCH_FOLDER="${TEST_DIR}/patches" \
    RELEASE_REPOSITORY="${TEST_DIR}/upstream" \
    BRANCH=master \
    SHA="${release_sha}" \
    "${release_target}"
  grep -Fx patched "${release_target}/source.txt" >/dev/null ||
    fail "release patch was not applied"
  current_tree=$(git -C "${release_target}" diff -- source.txt)
  [[ -n "${current_tree}" ]] || fail "release patch produced no source diff"
  if [[ -z "${patched_tree}" ]]; then
    patched_tree="${current_tree}"
  else
    [[ "${current_tree}" == "${patched_tree}" ]] ||
      fail "release patch was not repeatable"
  fi
done

for package in release etcd kubernetes kind; do
  clean_dir="${TEST_DIR}/clean-${package}"
  mkdir -p "${clean_dir}"
  : > "${clean_dir}/owned"
  make -s -C "${ROOT_DIR}/pkg/${package}" BUILD_DIR="${clean_dir}" distclean
  [[ ! -e "${clean_dir}" ]] || fail "pkg/${package} distclean did not remove its owned build directory"
done

echo "PASS: build orchestration is fail-fast, ordered, repeatable, and cleanup-safe."
