#!/usr/bin/env bash
set -euo pipefail
LOG_PATH="${1:-}"
if [[ -z "${LOG_PATH}" || ! -f "${LOG_PATH}" ]]; then
  echo "Usage: $0 <pr-consumer-build-log>" >&2
  exit 2
fi
if grep -E "(^|[[:space:]])(apt-get update|apt update|apt -y update)([[:space:]]|$)" "${LOG_PATH}" >/dev/null; then
  echo "No-apt PR consumer path executed apt update; see ${LOG_PATH}" >&2
  exit 1
fi
echo "No apt update command observed in PR consumer build log: ${LOG_PATH}"
