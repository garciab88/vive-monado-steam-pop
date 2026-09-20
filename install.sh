#!/usr/bin/env bash
# Idempotent Pop!_OS 24.04 setup: deps + standalone Monado + xrizer prefix.
# Does not download or launch Envision.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

PREFIX="${VIVE_MONADO_PREFIX:-${HOME}/.local/opt/vive-monado}"
ENV_D_DIR="${HOME}/.config/environment.d"
ENV_D_FILE="${ENV_D_DIR}/99-vive-monado.conf"
DESKTOP_DIR="${HOME}/.local/share/applications"
DESKTOP_FILE="${DESKTOP_DIR}/vive-monado.desktop"
STOP_DESKTOP_FILE="${DESKTOP_DIR}/vive-monado-stop.desktop"
XR_HARDWARE_GIT="https://gitlab.freedesktop.org/monado/utilities/xr-hardware.git"

need_reboot_note=0
SKIP_BUILD=0
FORCE_REBUILD=0

for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=1 ;;
    --rebuild) FORCE_REBUILD=1 ;;
    -h|--help)
      echo "Usage: $0 [--skip-build] [--rebuild]"
      echo "Installs deps, xr-hardware udev, environment.d, then builds Monado + xrizer."
      echo "No Envision. Rebuild later with ./build.sh or $0 --rebuild."
      exit 0
      ;;
  esac
done

have() { command -v "$1" >/dev/null 2>&1; }

as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  elif have sudo; then
    sudo "$@"
  else
    vive_err "need root for: $*"
    return 1
  fi
}

pkg_installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'
}

install_packages() {
  vive_log "apt packages (idempotent)"
  as_root apt-get update -y
  local pkgs=(
    git
    curl
    wget
    unzip
    ca-certificates
    build-essential
    cmake
    ninja-build
    pkg-config
    python3
    mesa-vulkan-drivers
    mesa-vulkan-drivers:i386
    libvulkan1
    libgl1-mesa-dri
    libopenxr-loader1
    libopenxr-dev
    libhidapi-hidraw0
    libusb-1.0-0
    udev
    glslang-tools
    libdrm-dev
    libgbm-dev
    libegl1-mesa-dev
    libgl1-mesa-dev
    libvulkan-dev
    libx11-xcb-dev
    libxcb-randr0-dev
    libx11-dev
    libxrandr-dev
    libxxf86vm-dev
    libusb-1.0-0-dev
    libhidapi-dev
    libudev-dev
    libsystemd-dev
    libeigen3-dev
    libbsd-dev
    libcjson-dev
    rustc
    cargo
    desktop-file-utils
  )
  as_root dpkg --add-architecture i386 || true
  as_root apt-get update -y

  as_root apt-get install -y --no-install-recommends "${pkgs[@]}" \
    || as_root apt-get install -y --no-install-recommends \
         git curl wget unzip ca-certificates build-essential cmake ninja-build \
         pkg-config python3 mesa-vulkan-drivers libvulkan1 \
         libopenxr-loader1 libopenxr-dev desktop-file-utils \
         libdrm-dev libvulkan-dev libx11-xcb-dev libxcb-randr0-dev \
         libusb-1.0-0-dev libhidapi-dev libeigen3-dev glslang-tools \
         libsystemd-dev rustc cargo || true

  as_root apt-get install -y xr-hardware 2>/dev/null || true
}

ensure_rust() {
  if have rustc && have cargo; then
    vive_log "rustc $(rustc --version | awk '{print $2}')"
  fi
  if ! have rustup; then
    if ! have rustc; then
      vive_log "installing rustup (xrizer needs a recent stable)"
      curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
    fi
  fi
  # shellcheck disable=SC1091
  [[ -f "${HOME}/.cargo/env" ]] && source "${HOME}/.cargo/env"
}

install_xr_hardware() {
  if [[ -f /usr/lib/udev/rules.d/70-xrhardware.rules ]] \
    || [[ -f /etc/udev/rules.d/70-xrhardware.rules ]] \
    || [[ -f /usr/lib/udev/rules.d/70-xr-hardware.rules ]]; then
    vive_log "xr-hardware udev rules already present"
    return 0
  fi
  if pkg_installed xr-hardware; then
    vive_log "xr-hardware package installed"
    return 0
  fi
  vive_log "installing xr-hardware udev rules from ${XR_HARDWARE_GIT}"
  local tmp
  tmp="$(mktemp -d)"
  git clone --depth 1 "$XR_HARDWARE_GIT" "$tmp/xr-hardware"
  (
    cd "$tmp/xr-hardware"
    make
    as_root make install
  )
  rm -rf "$tmp"
  as_root udevadm control --reload-rules || true
  as_root udevadm trigger || true
  need_reboot_note=1
}

write_desktop_entry() {
  mkdir -p "$DESKTOP_DIR"
  cat >"$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Vive
Comment=HTC Vive via Monado — starts compositor + Steam. Not SteamVR.
Exec=${SCRIPT_DIR}/vive-session.sh
Icon=applications-games
Terminal=false
Categories=Game;
Keywords=VR;XR;Monado;Vive;OpenXR;Steam;
StartupNotify=false
EOF
  cat >"$STOP_DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Stop Vive
Comment=Stop Monado compositor after a VR session
Exec=${SCRIPT_DIR}/stop-monado.sh
Icon=application-exit
Terminal=false
Categories=Game;
Keywords=VR;Monado;Vive;
StartupNotify=false
EOF
  if have update-desktop-database; then
    update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
  fi
  vive_log "desktop entries ${DESKTOP_FILE} ${STOP_DESKTOP_FILE}"
}

write_environment_d() {
  mkdir -p "$ENV_D_DIR"
  local uid ipc json vr
  uid="$(id -u)"
  ipc="/run/user/${uid}/monado_comp_ipc"
  json="${PREFIX}/share/openxr/1/openxr_monado.json"
  vr="${PREFIX}/lib/xrizer"
  cat >"$ENV_D_FILE" <<EOF
# vive-monado-steam-pop — written by install.sh (literal paths, no shell expand)
PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1
PRESSURE_VESSEL_FILESYSTEMS_RW=${ipc}
AMD_VULKAN_ICD=RADV
RADV_PERFTEST=vr
STEAMVR_LH_ENABLE=1
XR_RUNTIME_JSON=${json}
VR_OVERRIDE=${vr}
VR_DISABLE_STEAMVR=1
EOF
  chmod 644 "$ENV_D_FILE"
  vive_log "wrote ${ENV_D_FILE}"
  need_reboot_note=1
}

disable_steamvr_autolaunch() {
  python3 - <<'PY' || true
import json
from pathlib import Path
home = Path.home()
candidates = [
    home / ".steam/debian-installation/config/steamvr.vrsettings",
    home / ".steam/root/config/steamvr.vrsettings",
    home / ".steam/steam/config/steamvr.vrsettings",
    home / ".local/share/Steam/config/steamvr.vrsettings",
]
seen = set()
for p in candidates:
    try:
        p = p.resolve()
    except Exception:
        continue
    if p in seen or not p.is_file():
        continue
    seen.add(p)
    try:
        data = json.loads(p.read_text())
    except Exception:
        continue
    power = data.setdefault("power", {})
    if power.get("autoLaunchSteamVROnButtonPress") is False:
        print(f"vive-monado: steamvr autolaunch already off ({p})")
        continue
    power["autoLaunchSteamVROnButtonPress"] = False
    steamvr = data.setdefault("steamvr", {})
    steamvr.setdefault("enableHomeApp", False)
    p.write_text(json.dumps(data, indent=2) + "\n")
    print(f"vive-monado: disabled autoLaunchSteamVROnButtonPress in {p}")
PY
}

chmod_scripts() {
  local s
  for s in install.sh kill-steamvr.sh launch-monado.sh launch-beat-saber.sh \
           launch-game.sh list-games.sh build.sh fallback-build.sh \
           stop-monado.sh trim-prefix.sh vive-session.sh; do
    [[ -f "${SCRIPT_DIR}/${s}" ]] && chmod +x "${SCRIPT_DIR}/${s}"
  done
}

print_session_hint() {
  echo
  echo "XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-unset}  (must be x11)"
  if [[ "${XDG_SESSION_TYPE:-}" != "x11" ]]; then
    vive_warn "You are not on X11. Log into GNOME on Xorg before launching VR."
  fi
}

maybe_build() {
  if [[ "$SKIP_BUILD" -eq 1 ]]; then
    vive_log "skipping build (--skip-build). Later: ./build.sh"
    return 0
  fi
  if [[ "$FORCE_REBUILD" -eq 0 && -x "${PREFIX}/bin/monado-service" ]]; then
    vive_log "prefix already at ${PREFIX} — skip compile (./build.sh or $0 --rebuild)"
    "${SCRIPT_DIR}/trim-prefix.sh" || true
    return 0
  fi
  vive_log "compiling Monado + xrizer into ${PREFIX} (several minutes)"
  "${SCRIPT_DIR}/build.sh"
}

main() {
  echo "=== vive-monado-steam-pop install (Pop!_OS 24.04 / X11 / RADV) ==="
  echo "Standalone Monado + xrizer. No Envision. Success = frames in the Vive lenses."
  echo
  install_packages
  ensure_rust
  install_xr_hardware
  write_desktop_entry
  write_environment_d
  disable_steamvr_autolaunch
  chmod_scripts
  maybe_build
  print_session_hint

  echo
  echo "log out or reboot after udev/environment.d"
  echo
  echo "Next:"
  echo "  1. Log out / reboot (udev + environment.d)."
  echo "  2. Confirm: echo \$XDG_SESSION_TYPE   →  x11"
  echo "  3. Steam → Settings → Compatibility → Proton 9+ for all titles (once)."
  echo "  4. Daily: click Vive  (or ./vive-session.sh) then click a game in Steam."
  echo "     Do not open SteamVR. Do not open Envision."
  echo "  5. After play: click Stop Vive  (or ./vive-session.sh --stop)"
  echo
  echo "You do not paste per-game launch options if Steam was started from Vive."
}

main "$@"
