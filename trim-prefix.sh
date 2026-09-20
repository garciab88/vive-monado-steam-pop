#!/usr/bin/env bash
# Drop cargo junk, strip binaries, re-apply CAP_SYS_NICE. No recompile.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

PREFIX="${VIVE_MONADO_PREFIX:-${HOME}/.local/opt/vive-monado}"

as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

trim_xrizer() {
  local dst="${PREFIX}/lib/xrizer"
  [[ -d "$dst" ]] || return 0
  vive_log "trimming cargo leftovers under ${dst}"
  rm -rf \
    "${dst}/deps" \
    "${dst}/incremental" \
    "${dst}/build" \
    "${dst}/examples" \
    "${dst}/.fingerprint" \
    "${dst}/.cargo-lock" \
    "${dst}/incremental" \
    "${dst}/native" 2>/dev/null || true
  find "$dst" -type f \( \
      -name '*.rlib' -o -name '*.rmeta' -o -name '*.d' \
      -o -name '*.pdb' -o -name '*.crate' \
      -o -name 'libxrizer.d' -o -name '.cargo-lock' \
    \) -delete 2>/dev/null || true
}

strip_prefix() {
  command -v strip >/dev/null 2>&1 || return 0
  vive_log "strip --strip-unneeded"
  if [[ -x "${PREFIX}/bin/monado-service" ]]; then
    strip --strip-unneeded "${PREFIX}/bin/monado-service" 2>/dev/null || true
  fi
  find "${PREFIX}" -type f -name '*.so' -print0 2>/dev/null \
    | xargs -0 -r strip --strip-unneeded 2>/dev/null || true
}

setcap_again() {
  local bin="${PREFIX}/bin/monado-service"
  [[ -x "$bin" ]] || return 0
  as_root setcap CAP_SYS_NICE=eip "$bin" || vive_warn "setcap failed"
}

main() {
  if [[ ! -d "$PREFIX" ]]; then
    vive_err "no prefix at ${PREFIX} — ./build.sh first"
    exit 1
  fi
  trim_xrizer
  strip_prefix
  setcap_again
  vive_log "prefix trimmed: ${PREFIX}"
}

main "$@"
