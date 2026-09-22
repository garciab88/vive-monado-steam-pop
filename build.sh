#!/usr/bin/env bash
# Standalone Monado + xrizer prefix. No Envision.
# Proven on Pop!_OS 24.04 + RX 6600 + Vive: SIMULATED=ON (link), glslc,
# and Debian multiarch C++ headers for xrizer bindgen.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

PREFIX="${VIVE_MONADO_PREFIX:-${HOME}/.local/opt/vive-monado}"
SRC="${HOME}/.local/src/vive-monado-steam-pop"
MONADO_GIT="${MONADO_GIT:-https://gitlab.freedesktop.org/monado/monado.git}"
XRIZER_GIT="${XRIZER_GIT:-https://github.com/Supreeeme/xrizer.git}"
OPENCOMPOSITE_GIT="${OPENCOMPOSITE_GIT:-https://gitlab.com/znixian/OpenOVR.git}"
BUILD_OC=0
FORCE_MONADO=0

for arg in "$@"; do
  case "$arg" in
    --opencomposite) BUILD_OC=1 ;;
    --force-monado) FORCE_MONADO=1 ;;
    --prefix=*) PREFIX="${arg#*=}" ;;
    -h|--help)
      echo "Usage: $0 [--opencomposite] [--force-monado] [--prefix=DIR]"
      echo "Builds Monado (OpenXR compositor) + xrizer (OpenVR layer)."
      echo "Default prefix: ${PREFIX}"
      echo "Does not use Envision."
      exit 0
      ;;
  esac
done

# shellcheck disable=SC1091
if [[ -f "${HOME}/.cargo/env" ]]; then
  source "${HOME}/.cargo/env"
fi

have() { command -v "$1" >/dev/null 2>&1; }
as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

preflight() {
  local miss=()
  have cmake || miss+=(cmake)
  have ninja || miss+=(ninja)
  have cargo || miss+=(cargo)
  have rustc || miss+=(rustc)
  have glslc || miss+=(glslc)
  have g++ || miss+=(g++)
  if ((${#miss[@]})); then
    vive_err "missing: ${miss[*]}"
    vive_err "run ./install.sh (needs glslc, clang, g++, rustc, cmake, ninja)"
    exit 1
  fi
}

# libclang (bindgen) does not get GCC's C++ search path. Debian puts
# bits/c++config.h in /usr/include/<triplet>/c++/<ver>.
setup_bindgen_cxx() {
  local inc ver multi
  inc="$(ls -d /usr/include/c++/[0-9]* 2>/dev/null | sort -V | tail -n1 || true)"
  if [[ -z "$inc" ]]; then
    vive_err "no /usr/include/c++ — sudo apt install g++ libstdc++-dev"
    exit 1
  fi
  ver="$(basename "$inc")"
  multi="$(ls -d /usr/include/*-linux-gnu/c++/"${ver}" 2>/dev/null | head -n1 || true)"
  if [[ -z "$multi" || ! -f "${multi}/bits/c++config.h" ]]; then
    vive_err "bits/c++config.h not under /usr/include/*-linux-gnu/c++/${ver}"
    vive_err "sudo apt install g++ libstdc++-dev"
    exit 1
  fi
  export BINDGEN_EXTRA_CLANG_ARGS="-isystem ${inc} -isystem ${multi}"
  vive_log "bindgen C++: ${BINDGEN_EXTRA_CLANG_ARGS}"
}

clone_or_update() {
  local url="$1" dir="$2"
  if [[ -d "${dir}/.git" ]]; then
    git -C "$dir" fetch -q --depth 1 origin
    git -C "$dir" reset -q --hard FETCH_HEAD
  else
    git clone -q --depth 1 "$url" "$dir"
  fi
}

build_monado() {
  mkdir -p "$SRC" "$PREFIX"
  if [[ "$FORCE_MONADO" -eq 0 && -x "${PREFIX}/bin/monado-service" ]]; then
    vive_log "monado already at ${PREFIX} — skip cmake"
    return 0
  fi
  vive_log "building Monado → ${PREFIX} (several minutes; Vive + lighthouse only)"
  clone_or_update "$MONADO_GIT" "${SRC}/monado"
  local jobs clog
  jobs="$(vive_jobs)"
  clog="${SRC}/monado/cmake.log"
  # SIMULATED=ON is required: rgb_tracking still links simulated_hmd_create.
  # cmake config dump is huge and useless to users — keep it in cmake.log.
  if ! cmake -S "${SRC}/monado" -B "${SRC}/monado/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
    -DCMAKE_MESSAGE_LOG_LEVEL=ERROR \
    -DBUILD_TESTING=OFF \
    -DXRT_FEATURE_SERVICE=ON \
    -DXRT_FEATURE_OPENXR=ON \
    -DXRT_BUILD_DRIVER_STEAMVR_LIGHTHOUSE=ON \
    -DXRT_BUILD_DRIVER_SURVIVE=OFF \
    -DXRT_BUILD_DRIVER_OHMD=OFF \
    -DXRT_BUILD_DRIVER_NS=OFF \
    -DXRT_BUILD_DRIVER_PSVR=OFF \
    -DXRT_BUILD_DRIVER_HYDRA=OFF \
    -DXRT_BUILD_DRIVER_DAYDREAM=OFF \
    -DXRT_BUILD_DRIVER_ANDROID=OFF \
    -DXRT_BUILD_DRIVER_REMOTE=OFF \
    -DXRT_BUILD_DRIVER_SIMULATED=ON \
    -DXRT_BUILD_DRIVER_PSMV=OFF \
    -DXRT_BUILD_DRIVER_PSVR2=OFF \
    -DXRT_BUILD_DRIVER_RIFT_S=OFF \
    -DXRT_BUILD_DRIVER_WMR=OFF \
    -DXRT_BUILD_DRIVER_XREAL_AIR=OFF \
    -DXRT_BUILD_DRIVER_UVC=OFF \
    -DXRT_BUILD_DRIVER_V4L2=OFF \
    -DXRT_BUILD_DRIVER_SOLARXR=OFF \
    -DXRT_BUILD_DRIVER_ROKID=OFF \
    -DXRT_BUILD_DRIVER_HDK=OFF \
    -DXRT_BUILD_DRIVER_ARDUINO=OFF \
    -DXRT_FEATURE_WINDOW_PEEK=OFF \
    -DXRT_FEATURE_DEBUG_GUI=OFF \
    -DXRT_FEATURE_CLIENT_DEBUG_GUI=OFF \
    -DXRT_FEATURE_TRACING=OFF \
    -DXRT_FEATURE_STEAMVR_PLUGIN=OFF \
    -DXRT_FEATURE_SLAM=OFF \
    -DXRT_FEATURE_RENDERDOC=OFF \
    -DXRT_FEATURE_COLOR_LOG=OFF \
    -DXRT_MODULE_MONADO_GUI=OFF \
    -DXRT_MODULE_MONADO_CLI=OFF \
    -DXRT_MODULE_MERCURY_HANDTRACKING=OFF \
    -DXRT_FEATURE_SERVICE_SYSTEMD=OFF \
    >"$clog" 2>&1; then
    vive_err "cmake failed. last 40 lines of ${clog}:"
    tail -n 40 "$clog" >&2
    exit 1
  fi
  ninja -C "${SRC}/monado/build" -j "$jobs"
  ninja -C "${SRC}/monado/build" install
  if [[ ! -x "${PREFIX}/bin/monado-service" ]]; then
    vive_err "monado-service missing after install"
    exit 1
  fi
  vive_log "monado-service installed"
}

xrizer_present() {
  [[ -e "${PREFIX}/lib/xrizer/bin/linux64/vrclient.so" ]] \
    || [[ -e "${PREFIX}/lib/xrizer/libxrizer.so" ]]
}

build_xrizer() {
  vive_log "building xrizer (OpenVR → OpenXR; a few minutes)"
  clone_or_update "$XRIZER_GIT" "${SRC}/xrizer"
  if ! have cargo; then
    vive_err "cargo not found. ./install.sh first."
    exit 1
  fi
  local jobs
  jobs="$(vive_jobs)"
  (
    cd "${SRC}/xrizer"
    export CARGO_PROFILE_RELEASE_LTO="${CARGO_PROFILE_RELEASE_LTO:-thin}"
    export CARGO_PROFILE_RELEASE_STRIP="${CARGO_PROFILE_RELEASE_STRIP:-symbols}"
    unset CARGO_TERM_QUIET 2>/dev/null || true
    setup_bindgen_cxx
    cargo build --release -j "$jobs"
  )
  install_xrizer_runtime
  if ! xrizer_present; then
    vive_err "xrizer vrclient.so missing after cargo build"
    exit 1
  fi
  vive_log "xrizer installed"
}

install_xrizer_runtime() {
  local src="${SRC}/xrizer/target/release"
  local dst="${PREFIX}/lib/xrizer"
  rm -rf "$dst"
  mkdir -p "${dst}/bin/linux64"
  if [[ -d "${src}/bin/linux64" ]]; then
    cp -a "${src}/bin/linux64/." "${dst}/bin/linux64/"
  fi
  local f
  shopt -s nullglob
  for f in "${src}"/*.so "${src}"/*.json; do
    [[ -e "$f" ]] && cp -a "$f" "$dst/"
  done
  shopt -u nullglob
  if [[ ! -e "${dst}/bin/linux64/vrclient.so" ]] \
    && [[ -e "${dst}/libxrizer.so" ]]; then
    ln -sfn ../../libxrizer.so "${dst}/bin/linux64/vrclient.so"
  fi
  if [[ ! -e "${dst}/bin/linux64/vrclient.so" ]] \
    && [[ ! -e "${dst}/libxrizer.so" ]]; then
    vive_warn "xrizer vrclient.so not found — copying release dir as fallback"
    cp -a "${src}/." "$dst/"
    "${SCRIPT_DIR}/trim-prefix.sh" || true
  fi
}

build_opencomposite() {
  vive_log "building OpenComposite (fallback OpenVR layer)"
  if [[ -d "${SRC}/OpenOVR/.git" ]]; then
    git -C "${SRC}/OpenOVR" pull --ff-only || true
  else
    git clone -q --recursive --depth 1 "$OPENCOMPOSITE_GIT" "${SRC}/OpenOVR"
  fi
  cmake -S "${SRC}/OpenOVR" -B "${SRC}/OpenOVR/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_TESTING=OFF
  ninja -C "${SRC}/OpenOVR/build" -j "$(vive_jobs)"
  mkdir -p "${PREFIX}/lib/opencomposite"
  find "${SRC}/OpenOVR/build" -name 'vrclient*.so' -exec cp -a {} "${PREFIX}/lib/opencomposite/" \;
}

write_runtime_json() {
  local so json_src json_dst
  so="$(find "${PREFIX}" -name 'libopenxr_monado.so' | head -n1 || true)"
  if [[ -z "$so" ]]; then
    vive_err "libopenxr_monado.so not found under ${PREFIX}"
    exit 1
  fi
  mkdir -p "${PREFIX}/share/openxr/1" "${HOME}/.config/openxr/1"
  json_src="${PREFIX}/share/openxr/1/openxr_monado.json"
  cat >"$json_src" <<EOF
{
  "file_format_version": "1.0.0",
  "runtime": {
    "name": "Monado",
    "library_path": "${so}"
  }
}
EOF
  json_dst="${HOME}/.config/openxr/1/active_runtime.json"
  ln -sfn "$json_src" "$json_dst"
  vive_log "active OpenXR runtime → ${json_dst}"
}

write_openvrpaths() {
  local runtime_dir="${PREFIX}/lib/xrizer"
  local root cfg log
  root="$(vive_steam_root || true)"
  cfg="${root:-${HOME}/.steam/steam}/config"
  log="${root:-${HOME}/.steam/steam}/logs"
  if [[ "$BUILD_OC" -eq 1 && -d "${PREFIX}/lib/opencomposite" ]]; then
    vive_warn "OpenComposite built. xrizer remains the default OpenVR layer."
    vive_warn "To switch: point openvrpaths.vrpath runtime at ${PREFIX}/lib/opencomposite"
  fi
  mkdir -p "${HOME}/.config/openvr"
  cat >"${HOME}/.config/openvr/openvrpaths.vrpath" <<EOF
{
  "config": ["${cfg}"],
  "external_drivers": [],
  "jsonid": "vrpathreg",
  "log": ["${log}"],
  "runtime": ["${runtime_dir}"],
  "version": 1
}
EOF
  vive_log "openvrpaths.vrpath runtime → ${runtime_dir}  steam → ${root:-unset}"
}

main() {
  echo "=== standalone build: Monado + xrizer (no Envision, ultralight) ==="
  preflight
  chmod +x "${SCRIPT_DIR}/trim-prefix.sh" 2>/dev/null || true
  build_monado
  build_xrizer
  if [[ "$BUILD_OC" -eq 1 ]]; then
    build_opencomposite
  fi
  write_runtime_json
  write_openvrpaths
  "${SCRIPT_DIR}/trim-prefix.sh"
  if [[ ! -x "${PREFIX}/bin/monado-service" ]] || ! xrizer_present; then
    vive_err "prefix incomplete. not done."
    exit 1
  fi
  echo
  vive_log "prefix ${PREFIX}  monado=yes  xrizer=yes"
  vive_log "daily: open Steam, click a game. stop: Stop Vive desktop entry."
}

main "$@"
