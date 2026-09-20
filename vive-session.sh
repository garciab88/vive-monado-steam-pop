#!/usr/bin/env bash
# Alias: the Steam wrapper is the daily path.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "${1:-}" == "--stop" || "${1:-}" == "stop" ]]; then
  exec "${SCRIPT_DIR}/stop-monado.sh"
fi
exec "${SCRIPT_DIR}/wrappers/steam" "$@"
