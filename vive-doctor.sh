#!/usr/bin/env bash
# Print whether this machine can run the Vive + Monado stack.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

echo "=== vive-monado doctor ==="
echo "os          $(vive_os_id)  family=$(vive_pkg_family)"
echo "kernel      $(uname -r)"
echo "session     ${XDG_SESSION_TYPE:-unset}  desktop=${XDG_CURRENT_DESKTOP:-unset}"
echo "prefix      ${PREFIX}"
if root="$(vive_steam_root 2>/dev/null)"; then
  echo "steam       ${root}"
else
  echo "steam       NOT FOUND"
fi
if cmd="$(vive_steam_cmd 2>/dev/null)"; then
  echo "steam cmd   ${cmd}"
else
  echo "steam cmd   NOT FOUND"
fi

echo "----- GPU -----"
lspci 2>/dev/null | grep -Ei 'VGA|3D|Display' || echo "(lspci missing)"
vive_amd_ok || true
echo "RADV ICD files:"
ls /usr/share/vulkan/icd.d/*radeon* /usr/share/vulkan/icd.d/*radv* 2>/dev/null || echo "  (none named radeon/radv — mesa-vulkan-drivers?)"

echo "----- DRM (HMD should be connected HDMI-A or DP) -----"
vive_drm_status || true

echo "----- Monado -----"
if bin="$(vive_find_monado_service 2>/dev/null)"; then
  echo "monado-service  $bin"
  vive_check_cap_sys_nice
else
  echo "monado-service  NOT BUILT  → ./install.sh"
fi
json="${HOME}/.config/openxr/1/active_runtime.json"
echo "openxr json     $( [[ -L $json || -f $json ]] && echo "$json" || echo missing )"
echo "xrizer          $( [[ -e ${PREFIX}/lib/xrizer/bin/linux64/vrclient.so || -e ${PREFIX}/lib/xrizer/libxrizer.so ]] && echo present || echo missing )"
echo "monado running  $(pgrep -x monado-service >/dev/null 2>&1 && echo yes || echo no)"
echo "vrcompositor    $(pgrep -x vrcompositor >/dev/null 2>&1 && echo YES-BAD || echo down)"

echo "----- HMD family -----"
echo "Supported: HTC Vive (2016), Vive Pro, Vive Pro Eye, Vive Pro 2."
echo "Vive / Pro / Pro Eye: plug HDMI or DP + USB, lighthouse bases on."
echo "Vive Pro 2: same stack. Full res on AMD may need kernel patches; default mode works without."
echo "Not this repo: Nvidia-only boxes, ALVR/WiVRn, SteamVR as compositor."
echo "=== done ==="
