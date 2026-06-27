#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "${ROOT_DIR}"
fail() { echo "FAIL: $*" >&2; exit 1; }
require_file() { [[ -f "$1" ]] || fail "missing $1"; }
require_executable() { [[ -x "$1" ]] || fail "missing executable $1"; }
require_file pkg/common.mk
require_file pkg/release/Makefile
require_file Makefile
require_file .github/workflows/ci.yaml
require_file .github/workflows/release.yaml
require_file .github/workflows/baseline-images.yaml
require_file docs/ci-baseline-policy.md
require_file hack/release/baseline-images.env.example
require_executable hack/release/verify-baseline-images.sh
require_executable hack/release/verify-no-apt-pr-path.sh
require_executable hack/release/build-images.sh
! grep -RIn --exclude=verify-ci-baseline-optimization.sh "DEBIAN_VERSION=sid" Makefile pkg .github hack docs >/tmp/ci-baseline-sid.txt || fail "stale DEBIAN_VERSION=sid remains: $(cat /tmp/ci-baseline-sid.txt)"
! grep -RIn --exclude=verify-ci-baseline-optimization.sh "CONFIG=bookworm.*debian:.*trixie\|BASEIMAGE=debian:trixie-slim.*CONFIG=bookworm" pkg/release/Makefile docs >/tmp/ci-baseline-bookworm.txt || fail "unexplained bookworm/trixie baseline mismatch remains: $(cat /tmp/ci-baseline-bookworm.txt)"
grep -q "DEBIAN_SUITE=trixie" pkg/common.mk || fail "pkg/common.mk must define DEBIAN_SUITE=trixie"
grep -q "DEBIAN_VERSION=13" pkg/common.mk || fail "pkg/common.mk must define DEBIAN_VERSION=13"
grep -q "print-baseline-image-refs" pkg/common.mk || fail "pkg/common.mk must expose print-baseline-image-refs"
mapfile -t baselines < <(make -s -f pkg/common.mk print-baseline-image-refs)
[[ ${#baselines[@]} -eq 5 ]] || fail "expected 5 stable baseline refs, got ${#baselines[@]}: ${baselines[*]:-}"
for expected in kube-cross-riscv64 debian-base-riscv64 go-runner-riscv64 setcap-riscv64 distroless-iptables-riscv64; do
  printf "%s\n" "${baselines[@]}" | grep -q "/${expected}:" || fail "missing stable baseline ref for ${expected}"
done
for source_img in pause etcd base kindnetd local-path-helper local-path-provisioner "final kind node image"; do
  grep -q "${source_img}" docs/ci-baseline-policy.md || fail "source-derived image not documented: ${source_img}"
done
grep -q "pause" docs/ci-baseline-policy.md || fail "pause classification missing"
grep -q "@sha256" hack/release/baseline-images.env.example || fail "baseline env example must use immutable digest refs"
grep -q "must be pinned by immutable @sha256" hack/release/verify-baseline-images.sh || fail "verify-baseline-images must reject mutable tag-only refs"
grep -q "docker pull" hack/release/verify-baseline-images.sh || fail "verify-baseline-images must pull digest-pinned baselines"
grep -q "docker tag" hack/release/verify-baseline-images.sh || fail "verify-baseline-images must retag baselines for local Makefile consumers"
grep -q "USE_PREBUILT_BASELINES" .github/workflows/ci.yaml || fail "CI must expose USE_PREBUILT_BASELINES mode"
grep -q "NO_APT_PR_CI" .github/workflows/ci.yaml || fail "CI must expose NO_APT_PR_CI mode"
grep -q "Verify CI baseline optimization contract" .github/workflows/ci.yaml || fail "CI must run optimization verifier"
grep -q "USE_PREBUILT_BASELINES" hack/release/build-images.sh || fail "build-images must support prebuilt baseline mode"
grep -q "verify-baseline-images.sh" hack/release/build-images.sh || fail "prebuilt baseline mode must verify baseline images"
grep -q "make -C .*pkg/release.* release" hack/release/build-images.sh || fail "full source build fallback must remain"
grep -q "pkg/kubernetes.* pause\|pkg/kubernetes\" pause" hack/release/build-images.sh || fail "build-images must still build source-derived pause"
grep -q "pkg/kind.* node-image\|pkg/kind\" node-image" hack/release/build-images.sh || fail "build-images must still build source-derived node image"
grep -q "apt-get update\|apt update\|apt -y update" hack/release/verify-no-apt-pr-path.sh || fail "no-apt guard must check apt update commands"
grep -q "workflow_dispatch" .github/workflows/baseline-images.yaml || fail "baseline workflow must support manual dispatch"
grep -q "schedule:" .github/workflows/baseline-images.yaml || fail "baseline workflow must support scheduled freshness rebuilds"
grep -q "packages: write" .github/workflows/baseline-images.yaml || fail "baseline workflow must be able to push GHCR images"
grep -q "print-baseline-image-refs" .github/workflows/baseline-images.yaml || fail "baseline workflow must push baseline refs"
grep -q "test -x dist/release/kind-linux-riscv64" .github/workflows/ci.yaml || fail "artifact verification removed from CI"
grep -q "run_smoke" .github/workflows/ci.yaml || fail "smoke-test workflow_dispatch hook removed"
grep -q "elapsed_seconds" hack/release/build-images.sh || fail "timing evidence hook missing"
echo "PASS: CI baseline optimization contract is satisfied."
