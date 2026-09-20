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

# Leave two cores for the desktop during compiles.
vive_jobs() {
  local n jobs
  n="$(nproc 2>/dev/null || echo 2)"
  jobs=$((n - 2))
  if [[ "$jobs" -lt 1 ]]; then
    jobs=1
  fi
  printf '%s' "$jobs"
}

vive_os_id() {
  # shellcheck disable=SC1091
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    printf '%s' "${ID:-unknown}"
  else
    printf 'unknown'
  fi
}

vive_os_like() {
  # shellcheck disable=SC1091
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    printf '%s' "${ID_LIKE:-${ID:-unknown}}"
  else
    printf 'unknown'
  fi
}

# debian | fedora | arch | unknown
vive_pkg_family() {
  local id like
  id="$(vive_os_id)"
  like="$(vive_os_like)"
  case "$id" in
    debian|ubuntu|pop|linuxmint|elementary|zorin|neon|kali)
      printf 'debian'; return 0 ;;
    fedora|rhel|centos|rocky|almalinux|nobara|bazzite)
      printf 'fedora'; return 0 ;;
    arch|manjaro|endeavouros|cachyos|garuda|artix)
      printf 'arch'; return 0 ;;
  esac
  case "$like" in
    *debian*|*ubuntu*) printf 'debian'; return 0 ;;
    *fedora*|*rhel*) printf 'fedora'; return 0 ;;
    *arch*) printf 'arch'; return 0 ;;
  esac
  if command -v apt-get >/dev/null 2>&1; then
    printf 'debian'; return 0
  fi
  if command -v dnf >/dev/null 2>&1; then
    printf 'fedora'; return 0
  fi
  if command -v pacman >/dev/null 2>&1; then
    printf 'arch'; return 0
  fi
  printf 'unknown'
}

vive_steam_root() {
  if [[ -n "${VIVE_STEAM_ROOT:-}" && -d "${VIVE_STEAM_ROOT}" ]]; then
    printf '%s' "${VIVE_STEAM_ROOT}"
    return 0
  fi
  local d
  for d in \
    "${HOME}/.steam/debian-installation" \
    "${HOME}/.steam/steam" \
    "${HOME}/.steam/root" \
    "${HOME}/.local/share/Steam" \
    "${HOME}/.var/app/com.valvesoftware.Steam/.local/share/Steam"
  do
    if [[ -d "${d}/steamapps" || -x "${d}/steam.sh" || -d "${d}/config" ]]; then
      printf '%s' "$d"
      return 0
    fi
  done
  return 1
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
  case "$st" in
    x11)
      return 0
      ;;
    wayland)
      vive_warn "XDG_SESSION_TYPE=wayland. Xorg is the proven Vive DRM-lease path."
      vive_warn "AMD + KDE/wlroots can work. GNOME Wayland often cannot lease the HMD."
      vive_warn "If the panels stay black, log into an Xorg session and run Vive again."
      return 0
      ;;
    *)
      vive_err "XDG_SESSION_TYPE is '${st:-unset}'. Need an Xorg session (or AMD Wayland on KDE/wlroots)."
      vive_err "At the greeter: gear menu → 'GNOME on Xorg' / 'Plasma (X11)' / your distro's Xorg session."
      return 1
      ;;
  esac
}

vive_amd_ok() {
  local pci icd
  pci="$(lspci 2>/dev/null | grep -Ei 'VGA|3D|Display' || true)"
  if ! printf '%s' "$pci" | grep -qiE 'AMD|ATI|Advanced Micro Devices'; then
    vive_warn "no AMD GPU in lspci. This stack is Mesa RADV + DRM lease."
    vive_warn "Nvidia/Intel wired HMDs are a different fight. You can still try."
  fi
  shopt -s nullglob
  for icd in /usr/share/vulkan/icd.d/*amdvlk*.json /etc/vulkan/icd.d/*amdvlk*.json \
             /usr/share/vulkan/icd.d/amd_icd*.json; do
    if [[ -e "$icd" ]]; then
      vive_warn "amdvlk ICD present (${icd}). It cannot DRM-lease the Vive."
      vive_warn "uninstall amdvlk / amdgpu-pro. Keep mesa RADV. AMD_VULKAN_ICD=RADV is set."
    fi
  done
  shopt -u nullglob
  return 0
}

# HDMI Vive, or two+ connected displays (Pro on DP + desktop on DP).
vive_hmd_connected() {
  local f n=0
  shopt -s nullglob
  for f in /sys/class/drm/card*-HDMI-A-*/status; do
    if [[ "$(cat "$f" 2>/dev/null || true)" == "connected" ]]; then
      shopt -u nullglob
      return 0
    fi
  done
  for f in /sys/class/drm/card*-HDMI-A-*/status \
           /sys/class/drm/card*-DP-*/status \
           /sys/class/drm/card*-DisplayPort-*/status; do
    if [[ "$(cat "$f" 2>/dev/null || true)" == "connected" ]]; then
      n=$((n + 1))
    fi
  done
  shopt -u nullglob
  [[ "$n" -ge 2 ]]
}

# Reference box = RDNA2 Navi 23 (RX 6600 / 6600 XT). Same flags are correct on
# other AMD RADV GPUs; we only special-case known PCI IDs for logging.
vive_apply_profile() {
  local pci
  pci="$(lspci -n 2>/dev/null | grep -Ei '1002:' || true)"
  export VIVE_PROFILE="${VIVE_PROFILE:-amd}"
  if printf '%s' "$pci" | grep -qiE '1002:73ff|1002:73e3|1002:73ef'; then
    export VIVE_PROFILE="rx6600"
  elif printf '%s' "$pci" | grep -qi '1002:'; then
    export VIVE_PROFILE="amd"
  fi
  export RADV_PERFTEST="${RADV_PERFTEST:-vr}"
  export XRT_COMPOSITOR_COMPUTE="${XRT_COMPOSITOR_COMPUTE:-1}"
}

vive_drm_status() {
  local f status
  shopt -s nullglob
  for f in /sys/class/drm/card*-HDMI-A-*/status \
           /sys/class/drm/card*-DP-*/status \
           /sys/class/drm/card*-DisplayPort-*/status; do
    status="$(cat "$f" 2>/dev/null || true)"
    printf '%s %s\n' "$f" "$status"
  done
  shopt -u nullglob
}

vive_hdmi_status() {
  vive_drm_status
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
  local root c
  root="$(vive_steam_root || true)"
  for c in \
    ${root:+"${root}/steam.sh"} \
    "${HOME}/.steam/debian-installation/steam.sh" \
    "${HOME}/.steam/steam/steam.sh" \
    "${HOME}/.steam/root/steam.sh" \
    "${HOME}/.local/share/Steam/steam.sh"
  do
    if [[ -n "$c" && -x "$c" ]]; then
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
  python3 - <<'PY'
from pathlib import Path
import os, re
home = Path.home()
forced = os.environ.get("VIVE_STEAM_ROOT", "").strip()
candidates = []
if forced:
    candidates.append(Path(forced))
candidates += [
    home / ".steam/debian-installation",
    home / ".steam/steam",
    home / ".steam/root",
    home / ".local/share/Steam",
    home / ".var/app/com.valvesoftware.Steam/.local/share/Steam",
]
seen = set()
roots = []
for c in candidates:
    try:
        c = c.resolve()
    except Exception:
        continue
    if c in seen:
        continue
    if (c / "steamapps").is_dir() or (c / "steam.sh").is_file():
        seen.add(c)
        roots.append(c)

def libraries(root):
    out = [root / "steamapps"]
    vdf = root / "steamapps" / "libraryfolders.vdf"
    if not vdf.is_file():
        return out
    try:
        text = vdf.read_text(errors="replace")
    except OSError:
        return out
    for m in re.finditer(r'"path"\s+"([^"]+)"', text):
        p = Path(m.group(1)) / "steamapps"
        out.append(p)
    return out

printed = set()
for root in roots:
    for d in libraries(root):
        try:
            d = d.resolve()
        except Exception:
            continue
        if d in printed or not d.is_dir():
            continue
        printed.add(d)
        print(d)
PY
}

vive_list_installed_games() {
  local dirs
  dirs="$(vive_steamapps_dirs || true)"
  VIVE_STEAMAPPS_DIRS="$dirs" python3 - <<'PY'
import os, re, sys
from pathlib import Path
raw = os.environ.get("VIVE_STEAMAPPS_DIRS", "")
dirs = [Path(x) for x in raw.splitlines() if x.strip()]
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
