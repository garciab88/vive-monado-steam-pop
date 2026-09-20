#!/usr/bin/env bash
# Launch Beat Saber (appid 620980) into Monado. SteamVR compositor must stay dead.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

vive_source_env
vive_print_beat_saber_launch_options
echo
echo "Set those once in Steam → Beat Saber → Properties → Launch Options,"
echo "and Compatibility → Proton 9.0 or newer. Then re-run this script."
echo

exec "${SCRIPT_DIR}/launch-game.sh" 620980
