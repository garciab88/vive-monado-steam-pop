#!/usr/bin/env bash
# Usage: ./launch-game.sh <appid>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <steam-appid>" >&2
  echo "Example: $0 620980   # Beat Saber" >&2
  exit 2
fi

APPID="$1"
if [[ ! "$APPID" =~ ^[0-9]+$ ]]; then
  vive_err "appid must be numeric, got: ${APPID}"
  exit 2
fi

vive_source_env
vive_require_x11
vive_kill_steamvr

if ! vive_ipc_up || ! pgrep -x monado-service >/dev/null 2>&1; then
  vive_log "Monado is not up — launching it first"
  "${SCRIPT_DIR}/launch-monado.sh"
fi

vive_wait_ipc 30
vive_kill_steamvr

STEAM="$(vive_steam_cmd || true)"
if [[ -z "$STEAM" ]]; then
  vive_err "steam binary not found. Expected ~/.steam/debian-installation/ or PATH."
  exit 1
fi

vive_log "launching steam://rungameid/${APPID} via ${STEAM}"
vive_log "Proton must be 9+. OpenVR titles go through xrizer (OpenComposite only as fallback)."
printf '\nPaste these launch options on the game if you have not already:\n'
printf 'PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1 PRESSURE_VESSEL_FILESYSTEMS_RW=$XDG_RUNTIME_DIR/monado_comp_ipc AMD_VULKAN_ICD=RADV RADV_PERFTEST=vr %%command%%\n\n'

# Export into the Steam process so even titles without launch options inherit
# the OpenXR import. Per-game Properties still win inside pressure-vessel.
export PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1
export PRESSURE_VESSEL_FILESYSTEMS_RW
export AMD_VULKAN_ICD
export RADV_PERFTEST
export XR_RUNTIME_JSON="${XR_RUNTIME_JSON:-}"

exec "$STEAM" "steam://rungameid/${APPID}"
