# Hardware this stack supports

AMD GPU + Mesa **RADV** + an HTC Vive-family PC headset, Linux.

Daily: `./vive-session.sh` then click a Steam VR game. Do not start SteamVR.

## Headsets (Vive 2016 → current PC Vives)

| HMD | Tracking | Video | Notes |
|---|---|---|---|
| **HTC Vive** (2016) | Lighthouse 1.0 | HDMI + USB | First-class. Proven. |
| **Vive Pro** | Lighthouse 1.0/2.0 | DisplayPort + USB | Same drivers. |
| **Vive Pro Eye** | same | DP + USB | Same path. Eye tracking unused. |
| **Vive Pro 2** | Lighthouse 2.0 | DP + USB | Native in Monado. Default res works. Full res on AMD may need kernel patches. Optional: `VP2_RESOLUTION`, `LH_OVERRIDE_IPD_MM`. |

Not in scope: Vive Focus / XR Elite (standalone), Vive Cosmos (inside-out, different driver), phones, ALVR.

SteamVR stays **installed** so `steamvr_lh` can read lighthouse calibration. It must not run as the compositor.

## GPUs

| GPU | Driver | Wired Vive |
|---|---|---|
| AMD RDNA+ (RX 5000 and newer) | **Mesa RADV** | Yes. This is the target. |
| AMD GCN (RX 400/500, Vega) | RADV | Works, weaker reprojection. |
| AMDVLK / amdgpu-pro | — | No. Cannot DRM-lease the HMD. Uninstall. |
| Nvidia / Intel | — | Not this repo. |

`AMD_VULKAN_ICD=RADV` is always set. `XRT_COMPOSITOR_COMPUTE=1` is the AMD reprojection path (`CAP_SYS_NICE` on `monado-service`).

## Distros

`./install.sh` picks packages for:

- Debian / Ubuntu / Pop!_OS / Mint
- Fedora / Nobara / Bazzite
- Arch / CachyOS / Manjaro / Endeavour

Xorg is the proven session for Vive DRM lease. AMD + KDE/wlroots Wayland can work. GNOME Wayland often cannot. If panels stay black, log into Xorg.

## Steam

Native Steam (deb/rpm/pacman), not a requirement on a specific path.
Discovered automatically:

- `~/.steam/debian-installation` (Pop/Ubuntu)
- `~/.steam/steam`
- `~/.local/share/Steam`
- extra libraries from `libraryfolders.vdf`

Flatpak Steam is a worse pressure-vessel fit. Prefer the distro Steam package.

## Reference box (the one that proved the black-lens bug)

Pop!_OS 24.04, GNOME on Xorg, Ryzen 5 5500, RX 6600 8GB RADV, Vive 1st gen HDMI, desktop 3440×1440 on DP, Steam at `~/.steam/debian-installation/`.

That machine is why `vrcompositor` is banned. Other AMD + Vive boxes use the same ban.
