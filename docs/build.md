# Standalone build (no Envision)

This stack compiles **Monado** and **xrizer** into
`~/.local/opt/vive-monado`. Envision is not downloaded, not launched, and not
required.

```
./install.sh          # deps + first compile
./build.sh            # rebuild later
./build.sh --opencomposite   # extra OpenVR fallback
```

Prefix: `~/.local/opt/vive-monado` (override with `VIVE_MONADO_PREFIX`).
Sources: `~/.local/src/vive-monado-steam-pop/{monado,xrizer}`.

## What gets built

| Piece | Why |
|---|---|
| `monado-service` | OpenXR runtime + compositor. DRM-leases the Vive HDMI on X11. |
| `libopenxr_monado.so` | Linked from `~/.config/openxr/1/active_runtime.json`. |
| xrizer | OpenVR → OpenXR. Written into `openvrpaths.vrpath`. |
| `CAP_SYS_NICE` | `setcap` on `monado-service` so AMD compute reprojection can hitch-less. |

CMake flags (Vive 1st gen + lighthouse):

```
-DXRT_FEATURE_SERVICE=ON
-DXRT_FEATURE_OPENXR=ON
-DXRT_BUILD_DRIVER_STEAMVR_LIGHTHOUSE=ON
-DXRT_BUILD_DRIVER_SURVIVE=OFF
```

The built-in **vive** HMD driver stays on (default). **steamvr_lh** wraps
SteamVR's lighthouse binary for 6DoF. SteamVR itself stays dead
(`STEAMVR_LH_ENABLE=1` in `vive.env`). Survive is worse tracking on this box.

## Start

```
./launch-monado.sh
```

That is `nohup ~/.local/opt/vive-monado/bin/monado-service`. No GTK orchestrator.

Log: `~/.cache/vive-monado-service.log`

## OpenComposite

Only if a given OpenVR title cannot start under xrizer:

```
./build.sh --opencomposite
```

Then point `~/.config/openvr/openvrpaths.vrpath` `runtime` at
`~/.local/opt/vive-monado/lib/opencomposite`. Keep that as fallback, not default.
