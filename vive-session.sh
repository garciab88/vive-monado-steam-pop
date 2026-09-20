#!/usr/bin/env bash
# Daily path. Starts Monado, restarts Steam with the right env, you click a game.
# Do not open SteamVR. Do not open Envision.
# Usage: ./vive-session.sh
#        ./vive-session.sh --stop
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

if [[ "${1:-}" == "--stop" || "${1:-}" == "stop" ]]; then
  exec "${SCRIPT_DIR}/stop-monado.sh"
fi

vive_source_env
vive_require_x11

vive_log "this is not SteamVR. Do not click 'Play SteamVR'."
"${SCRIPT_DIR}/launch-monado.sh"

STEAM="$(vive_steam_cmd || true)"
if [[ -z "$STEAM" ]]; then
  vive_err "steam binary not found."
  exit 1
fi

steam_running() {
  pgrep -x steam >/dev/null 2>&1 || pgrep -x steam-runtime-steam >/dev/null 2>&1
}

if steam_running; then
  vive_log "restarting Steam so every title inherits Monado (dock Steam is missing those vars)"
  "$STEAM" -shutdown >/dev/null 2>&1 || true
  for _ in $(seq 1 40); do
    steam_running || break
    sleep 0.5
  done
  if steam_running; then
    pkill -x steam >/dev/null 2>&1 || true
    sleep 0.5
  fi
fi

vive_kill_steamvr || true

vive_log "headset is Monado. Click any VR title in Steam. After you are done: ./vive-session.sh --stop"
# Steam daemonizes; this still plants the env on the process tree.
exec "$STEAM"
