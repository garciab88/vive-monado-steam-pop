# shared helpers for vive-monado-steam-pop launchers
# shellcheck shell=bash

if [[ -n "${VIVE_MONADO_COMMON_LOADED:-}" ]]; then
  return 0 2>/dev/null || true
fi
VIVE_MONADO_COMMON_LOADED=1

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENVISION_DIR="${HOME}/.local/opt/envision"
ENVISION_APPIMAGE="${ENVISION_DIR}/Envision-x86_64.AppImage"
FALLBACK_PREFIX="${HOME}/.local/opt/vive-monado"
STEAM_ROOT_DEFAULT="${HOME}/.steam/debian-installation"

vive_log() { printf 'vive-monado: %s\n' "$*"; }
vive_err() { printf 'vive-monado: ERROR: %s\n' "$*" >&2; }
vive_warn() { printf 'vive-monado: warn: %s\n' "$*" >&2; }

vive_source_env() {
  # shellcheck source=../vive.env
  source "${REPO_ROOT}/vive.env"
}

vive_runtime_dir() {
  if [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
    printf '%s' "${XDG_RUNTIME_DIR}"
  else
    printf '/run/user/%s' "$(id -u)"
  fi
}

vive_ipc_path() {
  printf '%s/monado_comp_ipc' "$(vive_runtime_dir)"
}

vive_require_x11() {
  local st="${XDG_SESSION_TYPE:-}"
  if [[ "$st" != "x11" ]]; then
    vive_err "XDG_SESSION_TYPE is '${st:-unset}', expected x11."
    vive_err "This box must stay on GNOME on Xorg. Log out, click the gear, pick 'Pop!_OS' / 'GNOME on Xorg'."
    vive_err "Wayland: stop. Do not continue."
    return 1
  fi
  return 0
}

vive_hdmi_status() {
  local f status
  shopt -s nullglob
  for f in /sys/class/drm/card*-HDMI-A-*/status; do
    status="$(cat "$f" 2>/dev/null || true)"
    printf '%s %s\n' "$f" "$status"
  done
  shopt -u nullglob
}

vive_kill_steamvr() {
  if [[ -x "${REPO_ROOT}/kill-steamvr.sh" ]]; then
    "${REPO_ROOT}/kill-steamvr.sh" || true
  else
    local p
    for p in vrcompositor vrcompositor-launcher vrserver vrmonitor vrwebhelper vrdashboard vrstartup; do
      pkill -x "$p" >/dev/null 2>&1 || true
    done
  fi
}

vive_steamvr_running() {
  pgrep -x vrcompositor >/dev/null 2>&1 \
    || pgrep -x vrserver >/dev/null 2>&1 \
    || pgrep -x vrmonitor >/dev/null 2>&1
}

vive_find_envision() {
  local c
  if [[ -x "${ENVISION_APPIMAGE}" ]]; then
    printf '%s' "${ENVISION_APPIMAGE}"
    return 0
  fi
  if [[ -x "${ENVISION_DIR}/envision" ]]; then
    printf '%s' "${ENVISION_DIR}/envision"
    return 0
  fi
  if [[ -x "${ENVISION_DIR}/squashfs-root/usr/bin/envision" ]]; then
    printf '%s' "${ENVISION_DIR}/squashfs-root/usr/bin/envision"
    return 0
  fi
  c="$(command -v envision 2>/dev/null || true)"
  if [[ -n "$c" ]]; then
    printf '%s' "$c"
    return 0
  fi
  return 1
}

vive_find_monado_service() {
  local c f
  c="$(command -v monado-service 2>/dev/null || true)"
  if [[ -n "$c" && -x "$c" ]]; then
    printf '%s' "$c"
    return 0
  fi
  if [[ -x "${FALLBACK_PREFIX}/bin/monado-service" ]]; then
    printf '%s' "${FALLBACK_PREFIX}/bin/monado-service"
    return 0
  fi
  shopt -s nullglob
  for f in \
    "${HOME}"/.local/share/envision/prefixes/*/bin/monado-service \
    "${HOME}"/.local/share/envision/*/bin/monado-service
  do
    if [[ -x "$f" ]]; then
      printf '%s' "$f"
      shopt -u nullglob
      return 0
    fi
  done
  shopt -u nullglob
  return 1
}

vive_ipc_up() {
  local ipc
  ipc="$(vive_ipc_path)"
  [[ -e "$ipc" || -S "$ipc" ]]
}

vive_wait_ipc() {
  local timeout="${1:-90}" i ipc
  ipc="$(vive_ipc_path)"
  vive_log "waiting up to ${timeout}s for ${ipc}"
  for ((i = 0; i < timeout; i++)); do
    if vive_ipc_up; then
      vive_log "Monado compositor IPC is up: ${ipc}"
      return 0
    fi
    sleep 1
  done
  vive_err "timed out waiting for ${ipc}"
  vive_err "Is monado-service running? HDMI connected? SteamVR compositor killed?"
  return 1
}

vive_steam_cmd() {
  if command -v steam >/dev/null 2>&1; then
    command -v steam
    return 0
  fi
  local c
  for c in \
    "${STEAM_ROOT_DEFAULT}/steam.sh" \
    "${HOME}/.steam/steam/steam.sh" \
    "${HOME}/.steam/root/steam.sh"
  do
    if [[ -x "$c" ]]; then
      printf '%s' "$c"
      return 0
    fi
  done
  return 1
}

vive_print_beat_saber_launch_options() {
  cat <<'EOF'
===== Beat Saber (appid 620980) Steam launch options — paste in Properties =====
PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1 PRESSURE_VESSEL_FILESYSTEMS_RW=$XDG_RUNTIME_DIR/monado_comp_ipc AMD_VULKAN_ICD=RADV RADV_PERFTEST=vr %command%

Compatibility: force Proton 9.0 or newer (Proton 9, 10, or Experimental).
Do NOT launch SteamVR. Do NOT add -vrmode steamvr if it starts Valve's compositor.
EOF
}

vive_lighthouse_uuid_from_envision() {
  local envbin out
  envbin="$(vive_find_envision)" || return 1
  out="$("$envbin" --list-profiles 2>/dev/null || true)"
  if [[ -z "$out" ]]; then
    return 1
  fi
  printf '%s\n' "$out" >&2
  # Prefer a line that mentions lighthouse / steamvr. UUID is 8-4-4-4-12 hex.
  local line uuid
  uuid="$(printf '%s\n' "$out" | grep -iE 'lighthouse|steamvr_lh|steamvr lh' | grep -oE '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}' | head -n1 || true)"
  if [[ -z "$uuid" ]]; then
    uuid="$(printf '%s\n' "$out" | grep -oE '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}' | head -n1 || true)"
  fi
  if [[ -n "$uuid" ]]; then
    printf '%s' "$uuid"
    return 0
  fi
  return 1
}

vive_check_cap_sys_nice() {
  local bin
  bin="$(vive_find_monado_service)" || return 0
  if command -v getcap >/dev/null 2>&1; then
    if ! getcap "$bin" 2>/dev/null | grep -q 'cap_sys_nice'; then
      vive_warn "monado-service lacks CAP_SYS_NICE (AMD reprojection will hitch):"
      vive_warn "  sudo setcap CAP_SYS_NICE=eip $bin"
    fi
  fi
}
