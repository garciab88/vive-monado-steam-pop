#!/usr/bin/env bash
# Stop monado-service so it does not sit idle after a session.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

vive_kill_steamvr || true

PIDFILE="${HOME}/.cache/vive-monado-service.pid"
if [[ -f "$PIDFILE" ]]; then
  pid="$(cat "$PIDFILE" 2>/dev/null || true)"
  if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    sleep 0.2
    kill -9 "$pid" 2>/dev/null || true
  fi
  rm -f "$PIDFILE"
fi

pkill -x monado-service >/dev/null 2>&1 || true
sleep 0.2
pkill -9 -x monado-service >/dev/null 2>&1 || true

ipc="$(vive_ipc_path)"
rm -f "$ipc" 2>/dev/null || true

if pgrep -x monado-service >/dev/null 2>&1; then
  vive_err "monado-service still running"
  pgrep -a monado-service || true
  exit 1
fi

vive_log "monado-service stopped. SteamVR compositor still down."
exit 0
