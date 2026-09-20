#!/usr/bin/env bash
# Launch any Steam VR title into Monado. SteamVR compositor must stay dead.
# Usage: ./launch-game.sh <appid|slug>
#        ./launch-game.sh --list
#        ./launch-game.sh --known
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: ./launch-game.sh <appid|slug>
       ./launch-game.sh --list     installed Steam titles
       ./launch-game.sh --known    catalog slugs (lib/titles.tsv)

This stack is one compositor (Monado) and one launch-options line.
Every VR title on this box uses that path. No per-game compositor.

  ./launch-game.sh 546560
  ./launch-game.sh alyx
  ./launch-game.sh bonelab

Find appid:  ./launch-game.sh --list
             store.steampowered.com/app/<appid>/
Add a slug:  edit lib/titles.tsv

Paste this on EVERY VR title (Properties → Launch Options):
PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1 PRESSURE_VESSEL_FILESYSTEMS_RW=$XDG_RUNTIME_DIR/monado_comp_ipc AMD_VULKAN_ICD=RADV RADV_PERFTEST=vr %command%

Windows titles: force Proton 9.0 / 10 / Experimental.
Native Linux OpenXR titles: same line still imports Monado into pressure-vessel.
OpenVR titles go through xrizer (OpenComposite only as fallback).
EOF
}

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 2
fi

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "$1" == "--list" || "$1" == "-l" ]]; then
  vive_log "installed Steam titles (appid  name)"
  vive_list_installed_games
  exit 0
fi

if [[ "$1" == "--known" || "$1" == "-k" ]]; then
  vive_log "known slugs (lib/titles.tsv) — ./launch-game.sh <slug>"
  vive_list_known_titles
  exit 0
fi

APPID="$(vive_resolve_appid "$1" || true)"
if [[ -z "$APPID" ]]; then
  vive_err "need a numeric Steam appid or a slug from lib/titles.tsv. Got: $1"
  vive_err "try: ./launch-game.sh --known   or   ./launch-game.sh --list"
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
vive_print_launch_options "appid ${APPID}"
echo

export PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1
export PRESSURE_VESSEL_FILESYSTEMS_RW
export AMD_VULKAN_ICD
export RADV_PERFTEST
export XR_RUNTIME_JSON="${XR_RUNTIME_JSON:-}"

exec "$STEAM" "steam://rungameid/${APPID}"
