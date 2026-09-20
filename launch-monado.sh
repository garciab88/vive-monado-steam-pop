#!/usr/bin/env bash
# Start Monado (via Envision profile or monado-service). Never start vrcompositor.
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

ENVISION_BIN=""
ENVISION_BIN="$(vive_find_envision || true)"
MONADO_BIN=""
MONADO_BIN="$(vive_find_monado_service || true)"

start_monado_direct() {
  local bin="$1"
  vive_log "starting ${bin}"
  mkdir -p "$(vive_runtime_dir)"
  # Do not daemonize via systemd — we want this env, not SteamVR's.
  nohup "$bin" >"${HOME}/.cache/vive-monado-service.log" 2>&1 &
  echo $! >"${HOME}/.cache/vive-monado-service.pid"
  vive_log "monado-service pid $(cat "${HOME}/.cache/vive-monado-service.pid")  log ~/.cache/vive-monado-service.log"
}

mkdir -p "${HOME}/.cache"

if [[ -n "$ENVISION_BIN" ]]; then
  UUID=""
  UUID="$(vive_lighthouse_uuid_from_envision || true)"
  if [[ -n "$UUID" ]]; then
    vive_log "Envision lighthouse profile ${UUID}"
    vive_log "starting Envision --profile ${UUID} --start"
    # GTK app; keep it in the background so this script can wait on IPC.
    nohup "$ENVISION_BIN" --profile "$UUID" --start \
      >"${HOME}/.cache/vive-envision.log" 2>&1 &
    echo $! >"${HOME}/.cache/vive-envision.pid"
  elif [[ -n "$MONADO_BIN" ]]; then
    vive_warn "Envision has no listed lighthouse profile yet; starting monado-service directly."
    start_monado_direct "$MONADO_BIN"
  else
    vive_log "First Envision run: opening the GUI."
    vive_log "Profile = Lighthouse (Vive + base stations)."
    vive_log "First build compiles Monado + xrizer. Do NOT start SteamVR from Envision except for one-time room setup if chaperone is missing."
    exec "$ENVISION_BIN"
  fi
elif [[ -n "$MONADO_BIN" ]]; then
  start_monado_direct "$MONADO_BIN"
else
  vive_err "No Envision AppImage and no monado-service."
  vive_err "Run ./install.sh then open Envision (Lighthouse profile), or ./fallback-build.sh"
  exit 1
fi

vive_wait_ipc 90
vive_kill_steamvr
vive_check_cap_sys_nice

if vive_steamvr_running; then
  vive_err "SteamVR woke up while Monado was starting. Killed? $(vive_kill_steamvr || true)"
  vive_kill_steamvr || true
fi

vive_log "Monado compositor is the runtime. SteamVR compositor is not."
vive_log "Headset panels may stay a solid color until a client (Beat Saber) submits frames. That is success so far."
