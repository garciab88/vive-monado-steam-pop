# shared helpers for vive-monado-steam-pop launchers
# shellcheck shell=bash

if [[ -n "${VIVE_MONADO_COMMON_LOADED:-}" ]]; then
  return 0 2>/dev/null || true
fi
VIVE_MONADO_COMMON_LOADED=1

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREFIX="${VIVE_MONADO_PREFIX:-${HOME}/.local/opt/vive-monado}"
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

vive_find_monado_service() {
  local c prefix
  prefix="${VIVE_MONADO_PREFIX:-${PREFIX}}"
  if [[ -x "${prefix}/bin/monado-service" ]]; then
    printf '%s' "${prefix}/bin/monado-service"
    return 0
  fi
  c="$(command -v monado-service 2>/dev/null || true)"
  if [[ -n "$c" && -x "$c" ]]; then
    printf '%s' "$c"
    return 0
  fi
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

vive_print_launch_options() {
  local title="${1:-every Steam VR title}"
  cat <<EOF
===== ${title} — paste in Steam → Properties → Launch Options =====
PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1 PRESSURE_VESSEL_FILESYSTEMS_RW=\$XDG_RUNTIME_DIR/monado_comp_ipc AMD_VULKAN_ICD=RADV RADV_PERFTEST=vr %command%

Windows OpenVR/OpenXR titles: force Proton 9.0 or newer.
Native Linux OpenXR titles: same line still imports Monado into pressure-vessel.
Do NOT launch SteamVR. Do NOT add -vrmode steamvr if it starts Valve's compositor.
EOF
}

vive_print_beat_saber_launch_options() {
  vive_print_launch_options "any Steam VR title"
}

vive_steamapps_dirs() {
  local d
  for d in \
    "${STEAM_ROOT_DEFAULT}/steamapps" \
    "${HOME}/.steam/steam/steamapps" \
    "${HOME}/.steam/root/steamapps" \
    "${HOME}/.local/share/Steam/steamapps"
  do
    [[ -d "$d" ]] && printf '%s\n' "$d"
  done | awk 'BEGIN{seen[""]=1} !seen[$0]++'
}

vive_titles_file() {
  printf '%s' "${REPO_ROOT}/lib/titles.tsv"
}

vive_resolve_appid() {
  local raw="${1,,}"
  raw="${raw// /-}"
  if [[ -z "$raw" ]]; then
    return 1
  fi
  if [[ "$raw" =~ ^[0-9]+$ ]]; then
    printf '%s' "$raw"
    return 0
  fi
  local file appid
  file="$(vive_titles_file)"
  [[ -f "$file" ]] || return 1
  appid="$(awk -F '\t' -v s="$raw" '
    $0 ~ /^#/ { next }
    NF < 3 { next }
    tolower($2) == s { print $1; exit }
  ' "$file")"
  if [[ -n "$appid" ]]; then
    printf '%s' "$appid"
    return 0
  fi
  return 1
}

vive_list_known_titles() {
  local file
  file="$(vive_titles_file)"
  if [[ ! -f "$file" ]]; then
    vive_err "missing ${file}"
    return 1
  fi
  printf '%-8s  %-20s  %s\n' "appid" "slug" "name"
  awk -F '\t' '
    $0 ~ /^#/ { next }
    NF < 3 { next }
    { printf "%-8s  %-20s  %s\n", $1, $2, $3 }
  ' "$file"
}

vive_list_installed_games() {
  python3 - <<'PY'
import re, sys
from pathlib import Path
home = Path.home()
dirs = [
    home / ".steam/debian-installation/steamapps",
    home / ".steam/steam/steamapps",
    home / ".steam/root/steamapps",
    home / ".local/share/Steam/steamapps",
]
seen = set()
rows = []
for d in dirs:
    try:
        d = d.resolve()
    except Exception:
        continue
    if d in seen or not d.is_dir():
        continue
    seen.add(d)
    for p in sorted(d.glob("appmanifest_*.acf")):
        try:
            text = p.read_text(errors="replace")
        except OSError:
            continue
        appid = re.search(r'"appid"\s+"(\d+)"', text)
        name = re.search(r'"name"\s+"([^"]+)"', text)
        if appid and name:
            rows.append((int(appid.group(1)), name.group(1)))
uniq = {}
for appid, name in rows:
    uniq[appid] = name
if not uniq:
    sys.stderr.write("vive-monado: no Steam appmanifest_*.acf found\n")
    sys.exit(1)
width = max(len(str(i)) for i in uniq)
for appid in sorted(uniq):
    print(f"{str(appid).rjust(width)}  {uniq[appid]}")
PY
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
