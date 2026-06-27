#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SECONDS=0
USE_PREBUILT_BASELINES="${USE_PREBUILT_BASELINES:-0}"
NO_APT_PR_CI="${NO_APT_PR_CI:-${USE_PREBUILT_BASELINES}}"
if [[ "${USE_PREBUILT_BASELINES}" == "1" ]]; then
  echo "Using digest-pinned prebuilt baseline images for PR no-apt consumer mode"
  "${ROOT_DIR}/hack/release/verify-baseline-images.sh"
else
  echo "Building release baseline/helper images from source"
  make -C "${ROOT_DIR}/pkg/release" release
fi
# etcd, pause, and kind-derived images are source-derived/current-output by default; never silently trust prebuilt variants in PR validation.
make -C "${ROOT_DIR}/pkg/etcd" etcd
make -C "${ROOT_DIR}/pkg/kubernetes" pause
make -C "${ROOT_DIR}/pkg/kind" node-image
printf "release image build elapsed_seconds=%s mode=%s no_apt_pr_ci=%s\n" "${SECONDS}" "${USE_PREBUILT_BASELINES}" "${NO_APT_PR_CI}"
