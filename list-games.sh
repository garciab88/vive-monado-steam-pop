#!/usr/bin/env bash
# List installed Steam appids so you can ./launch-game.sh <appid>
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
exec "${SCRIPT_DIR}/launch-game.sh" --list
