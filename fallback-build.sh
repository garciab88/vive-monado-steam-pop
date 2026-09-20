#!/usr/bin/env bash
# Manual Monado + xrizer prefix when the Envision AppImage cannot be fetched.
# OpenComposite is built only with --opencomposite.
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

for arg in "$@"; do
  case "$arg" in
    --opencomposite) BUILD_OC=1 ;;
    --prefix=*) PREFIX="${arg#*=}" ;;
    -h|--help)
      echo "Usage: $0 [--opencomposite] [--prefix=DIR]"
      echo "Default prefix: ${PREFIX}"
      exit 0
      ;;
  esac
done

# shellcheck disable=SC1091
[[ -f "${HOME}/.cargo/env" ]] && source "${HOME}/.cargo/env"

have() { command -v "$1" >/dev/null 2>&1; }
as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

clone_or_update() {
  local url="$1" dir="$2"
  if [[ -d "${dir}/.git" ]]; then
    git -C "$dir" fetch --depth 1 origin
    git -C "$dir" reset --hard FETCH_HEAD
  else
    git clone --depth 1 "$url" "$dir"
  fi
}

build_monado() {
  vive_log "building Monado → ${PREFIX}"
  mkdir -p "$SRC" "$PREFIX"
  clone_or_update "$MONADO_GIT" "${SRC}/monado"
  cmake -S "${SRC}/monado" -B "${SRC}/monado/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
    -DXRT_FEATURE_SERVICE=ON \
    -DXRT_FEATURE_OPENXR=ON
  ninja -C "${SRC}/monado/build"
  ninja -C "${SRC}/monado/build" install
}

build_xrizer() {
  vive_log "building xrizer"
  clone_or_update "$XRIZER_GIT" "${SRC}/xrizer"
  if ! have cargo; then
    vive_err "cargo not found. ./install.sh first (rustup)."
    exit 1
  fi
  (cd "${SRC}/xrizer" && cargo build --release)
  mkdir -p "${PREFIX}/lib/xrizer"
  cp -a "${SRC}/xrizer/target/release/." "${PREFIX}/lib/xrizer/"
}

build_opencomposite() {
  vive_log "building OpenComposite (fallback OpenVR layer)"
  if [[ -d "${SRC}/OpenOVR/.git" ]]; then
    git -C "${SRC}/OpenOVR" pull --ff-only || true
  else
    git clone --recursive --depth 1 "$OPENCOMPOSITE_GIT" "${SRC}/OpenOVR"
  fi
  cmake -S "${SRC}/OpenOVR" -B "${SRC}/OpenOVR/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release
  ninja -C "${SRC}/OpenOVR/build"
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
  local runtime_dir
  runtime_dir="${PREFIX}/lib/xrizer"
  if [[ ! -e "${runtime_dir}/bin/linux64/vrclient.so" ]] \
    && [[ ! -e "${runtime_dir}/libopenvr_api.so" ]] \
    && [[ ! -e "${runtime_dir}/vrclient.so" ]]; then
    # xrizer release dir is itself the OpenVR runtime root
    runtime_dir="${PREFIX}/lib/xrizer"
  fi
  if [[ "$BUILD_OC" -eq 1 && -d "${PREFIX}/lib/opencomposite" ]]; then
    vive_warn "OpenComposite built. xrizer remains the default OpenVR layer."
    vive_warn "To switch: point openvrpaths.vrpath runtime at ${PREFIX}/lib/opencomposite"
  fi
  mkdir -p "${HOME}/.config/openvr"
  cat >"${HOME}/.config/openvr/openvrpaths.vrpath" <<EOF
{
  "config": ["${HOME}/.steam/debian-installation/config"],
  "external_drivers": [],
  "jsonid": "vrpathreg",
  "log": ["${HOME}/.steam/debian-installation/logs"],
  "runtime": ["${runtime_dir}"],
  "version": 1
}
EOF
  vive_log "openvrpaths.vrpath runtime → ${runtime_dir}"
}

setcap_monado() {
  local bin="${PREFIX}/bin/monado-service"
  if [[ -x "$bin" ]]; then
    vive_log "setcap CAP_SYS_NICE=eip ${bin}"
    as_root setcap CAP_SYS_NICE=eip "$bin" || vive_warn "setcap failed (nosuid mount?)"
  fi
}

main() {
  echo "=== fallback build: Monado + xrizer (no Envision) ==="
  build_monado
  build_xrizer
  if [[ "$BUILD_OC" -eq 1 ]]; then
    build_opencomposite
  fi
  write_runtime_json
  write_openvrpaths
  setcap_monado
  echo
  vive_log "prefix ${PREFIX}"
  vive_log "now: ./launch-monado.sh"
}

main "$@"
