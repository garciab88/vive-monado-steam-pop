#!/usr/bin/env bash
# Idempotent Pop!_OS 24.04 setup for Monado + Envision + xrizer around SteamVR.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

ENVISION_DIR="${HOME}/.local/opt/envision"
ENVISION_APPIMAGE="${ENVISION_DIR}/Envision-x86_64.AppImage"
ENV_D_DIR="${HOME}/.config/environment.d"
ENV_D_FILE="${ENV_D_DIR}/99-vive-monado.conf"
DESKTOP_DIR="${HOME}/.local/share/applications"
DESKTOP_FILE="${DESKTOP_DIR}/org.gabmus.envision-vive-monado.desktop"

# GitLab project gabmus/envision (id 46446166). Artifact job name is "appimage".
# Verified 2026-09: https://gitlab.com/gabmus/envision/-/jobs/artifacts/main/download?job=appimage
ENVISION_ARTIFACT_URLS=(
  "https://gitlab.com/gabmus/envision/-/jobs/artifacts/main/download?job=appimage"
  "https://gitlab.com/api/v4/projects/46446166/jobs/artifacts/main/download?job=appimage"
)
XR_HARDWARE_GIT="https://gitlab.freedesktop.org/monado/utilities/xr-hardware.git"

need_reboot_note=0

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
    vulkan-tools
    libgl1-mesa-dri
    libopenxr-loader1
    libopenxr-dev
    libfuse2t64
    desktop-file-utils
    libhidapi-hidraw0
    libusb-1.0-0
    udev
  )
  local extra=(
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
    libwayland-dev
    wayland-protocols
    libusb-1.0-0-dev
    libhidapi-dev
    libudev-dev
    libeigen3-dev
    libbsd-dev
    libcjson-dev
    libgtk-4-dev
    libadwaita-1-dev
    libssl-dev
    libvte-2.91-gtk4-dev
    meson
    gettext
    rustc
    cargo
  )
  # i386 mesa is required for Proton; ignore if architecture not enabled.
  as_root dpkg --add-architecture i386 || true
  as_root apt-get update -y

  local p install=()
  for p in "${pkgs[@]}" "${extra[@]}"; do
    install+=("$p")
  done
  # libfuse2 name flipped on noble; try both.
  as_root apt-get install -y --no-install-recommends "${install[@]}" \
    || as_root apt-get install -y --no-install-recommends \
         git curl wget unzip ca-certificates build-essential cmake ninja-build \
         pkg-config python3 mesa-vulkan-drivers libvulkan1 vulkan-tools \
         libopenxr-loader1 libopenxr-dev desktop-file-utils meson \
         libdrm-dev libvulkan-dev libx11-xcb-dev libxcb-randr0-dev \
         libusb-1.0-0-dev libhidapi-dev libeigen3-dev glslang-tools \
         rustc cargo libfuse2 || true

  as_root apt-get install -y libfuse2t64 2>/dev/null || as_root apt-get install -y libfuse2 2>/dev/null || true
  as_root apt-get install -y xr-hardware 2>/dev/null || true
}

ensure_rust() {
  if have rustc && have cargo; then
    local maj
    maj="$(rustc --version 2>/dev/null | awk '{print $2}' | cut -d. -f1 || echo 0)"
    if [[ "${maj:-0}" -ge 1 ]]; then
      vive_log "rustc $(rustc --version | awk '{print $2}')"
    fi
  fi
  if ! have rustup; then
    if ! have rustc; then
      vive_log "installing rustup (xrizer / Envision builds need a recent stable)"
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

download_envision() {
  mkdir -p "$ENVISION_DIR"
  if [[ -x "$ENVISION_APPIMAGE" && -s "$ENVISION_APPIMAGE" ]]; then
    vive_log "Envision AppImage already at ${ENVISION_APPIMAGE}"
    return 0
  fi

  local tmp zip job_id
  tmp="$(mktemp -d)"
  zip="${tmp}/envision.zip"

  local url ok=0
  for url in "${ENVISION_ARTIFACT_URLS[@]}"; do
    vive_log "downloading Envision artifacts: $url"
    if curl -fL --retry 3 --retry-delay 2 -o "$zip" "$url"; then
      ok=1
      break
    fi
  done

  if [[ "$ok" -ne 1 ]]; then
    vive_warn "direct artifact URL failed; querying GitLab API for latest successful appimage job"
    job_id="$(curl -fsSL "https://gitlab.com/api/v4/projects/46446166/jobs?per_page=40" \
      | python3 -c '
import json,sys
jobs=json.load(sys.stdin)
for j in jobs:
    if j.get("name")=="appimage" and j.get("status")=="success":
        print(j["id"]); break
' || true)"
    if [[ -n "${job_id:-}" ]]; then
      vive_log "GitLab job ${job_id}"
      if curl -fL --retry 2 -o "$zip" "https://gitlab.com/api/v4/projects/46446166/jobs/${job_id}/artifacts"; then
        ok=1
      else
        curl -fL -o "${tmp}/Envision-x86_64.AppImage" \
          "https://gitlab.com/gabmus/envision/-/jobs/${job_id}/artifacts/raw/Envision-x86_64.AppImage" \
          && ok=2
      fi
    fi
  fi

  if [[ "$ok" -eq 0 ]]; then
    rm -rf "$tmp"
    vive_err "Envision AppImage download failed."
    vive_err "Open https://gitlab.com/gabmus/envision/-/pipelines?ref=main&status=success"
    vive_err "and save Envision-x86_64.AppImage to ${ENVISION_APPIMAGE}"
    vive_err "or run ./fallback-build.sh for a manual Monado + xrizer prefix."
    return 1
  fi

  if [[ "$ok" -eq 2 ]]; then
    mv "${tmp}/Envision-x86_64.AppImage" "$ENVISION_APPIMAGE"
  else
    if unzip -t "$zip" >/dev/null 2>&1; then
      unzip -o "$zip" -d "${tmp}/out"
      local found
      found="$(find "${tmp}/out" -type f -name 'Envision*.AppImage' | head -n1)"
      if [[ -z "$found" ]]; then
        vive_err "zip had no Envision*.AppImage"
        rm -rf "$tmp"
        return 1
      fi
      mv "$found" "$ENVISION_APPIMAGE"
    else
      # maybe it was the AppImage itself
      mv "$zip" "$ENVISION_APPIMAGE"
    fi
  fi

  chmod +x "$ENVISION_APPIMAGE"
  ln -sfn "$ENVISION_APPIMAGE" "${ENVISION_DIR}/envision"
  rm -rf "$tmp"
  vive_log "installed ${ENVISION_APPIMAGE}"

  # FUSE-less fallback extract for boxes without libfuse.
  if ! "$ENVISION_APPIMAGE" --appimage-help >/dev/null 2>&1; then
    vive_warn "AppImage may need FUSE; extracting squashfs"
    (
      cd "$ENVISION_DIR"
      APPIMAGE_EXTRACT_AND_RUN=1 "$ENVISION_APPIMAGE" --appimage-extract >/dev/null 2>&1 || \
        "$ENVISION_APPIMAGE" --appimage-extract >/dev/null 2>&1 || true
    )
  fi
}

write_desktop_entry() {
  mkdir -p "$DESKTOP_DIR"
  local exec_line="$ENVISION_APPIMAGE"
  if [[ -x "${ENVISION_DIR}/squashfs-root/usr/bin/envision" ]]; then
    exec_line="${ENVISION_DIR}/squashfs-root/usr/bin/envision"
  fi
  cat >"$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Envision (Vive / Monado)
Comment=FOSS XR orchestrator — Monado compositor, not SteamVR
Exec=${exec_line}
Icon=applications-games
Terminal=false
Categories=Game;Utility;
Keywords=VR;XR;Monado;Vive;OpenXR;
StartupNotify=true
EOF
  if have update-desktop-database; then
    update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
  fi
  vive_log "desktop entry ${DESKTOP_FILE}"
}

write_environment_d() {
  mkdir -p "$ENV_D_DIR"
  cat >"$ENV_D_FILE" <<'EOF'
# vive-monado-steam-pop
# Tell Steam Linux Runtime / Proton to import the host OpenXR 1 runtime
# (Monado via ~/.config/openxr/1/active_runtime.json).
PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1
AMD_VULKAN_ICD=RADV
EOF
  chmod 644 "$ENV_D_FILE"
  vive_log "wrote ${ENV_D_FILE}"
  need_reboot_note=1
}

disable_steamvr_autolaunch() {
  python3 - <<'PY' || true
import json, os
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
           launch-game.sh list-games.sh fallback-build.sh; do
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

main() {
  echo "=== vive-monado-steam-pop install (Pop!_OS 24.04 / X11 / RADV) ==="
  echo "This is not SteamVR. Success = frames in the Vive lenses."
  echo
  install_packages
  ensure_rust
  install_xr_hardware
  if ! download_envision; then
    vive_warn "continuing without Envision AppImage — use ./fallback-build.sh"
  fi
  write_desktop_entry
  write_environment_d
  disable_steamvr_autolaunch
  chmod_scripts
  print_session_hint

  echo
  echo "log out or reboot after udev/environment.d"
  echo
  echo "Next:"
  echo "  1. Log out / reboot (udev + environment.d)."
  echo "  2. Confirm: echo \$XDG_SESSION_TYPE   →  x11"
  echo "  3. Open Envision → profile Lighthouse (Vive + base stations)."
  echo "     First build compiles Monado + xrizer. Do not start SteamVR from"
  echo "     Envision except one-time room setup if chaperone is missing."
  echo "  4. ./launch-monado.sh"
  echo "  5. Paste the launch options on each VR title (docs/steam-launch-options.md)"
  echo "  6. ./launch-game.sh --list && ./launch-game.sh <appid>"
  echo
  echo "If Envision is down: ./fallback-build.sh && ./launch-monado.sh"
}

main "$@"
