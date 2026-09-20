#!/usr/bin/env bash
# Start monado-service from the standalone prefix. Never start vrcompositor.
# Never start Envision.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

vive_source_env
vive_require_x11
vive_kill_steamvr

if vive_steamvr_running; then
  vive_err "SteamVR is still alive. Aborting so vrcompositor cannot steal the Vive HDMI."
  exit 1
fi

echo "----- HDMI connectors -----"
vive_hdmi_status || true
echo "---------------------------"

IPC="$(vive_ipc_path)"
if vive_ipc_up && pgrep -x monado-service >/dev/null 2>&1; then
  vive_log "monado-service already running, IPC ${IPC}"
  vive_check_cap_sys_nice
  exit 0
fi

MONADO_BIN=""
MONADO_BIN="$(vive_find_monado_service || true)"
if [[ -z "$MONADO_BIN" ]]; then
  vive_err "monado-service not found. Expected ~/.local/opt/vive-monado/bin/monado-service"
  vive_err "Run ./install.sh (builds Monado + xrizer). No Envision required."
  exit 1
fi

mkdir -p "${HOME}/.cache" "$(vive_runtime_dir)"
: >"${HOME}/.cache/vive-monado-service.log"
vive_log "starting ${MONADO_BIN}"
nohup "$MONADO_BIN" >"${HOME}/.cache/vive-monado-service.log" 2>&1 &
echo $! >"${HOME}/.cache/vive-monado-service.pid"
vive_log "monado-service pid $(cat "${HOME}/.cache/vive-monado-service.pid")  log ~/.cache/vive-monado-service.log"

vive_wait_ipc 90
vive_kill_steamvr
vive_check_cap_sys_nice

if vive_steamvr_running; then
  vive_err "SteamVR woke up while Monado was starting."
  vive_kill_steamvr || true
fi

vive_log "Monado compositor is the runtime. SteamVR compositor is not. Envision is not in this path."
vive_log "Headset panels may stay a solid color until a client submits frames. That is success so far."
vive_log "Then: ./vive-session.sh (or click a game if Steam is already this env). After play: ./vive-session.sh --stop"
