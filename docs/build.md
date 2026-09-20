# Standalone build (no Envision)

This stack compiles **Monado** and **xrizer** into
`~/.local/opt/vive-monado`. Envision is not downloaded, not launched, and not
required. The prefix is **ultralight**: unused drivers off, no debug GUI, no
window peek, stripped binaries, xrizer runtime files only (no cargo `deps/`).

```
./install.sh          # deps + first compile
./build.sh            # rebuild later (picks up cmake cuts)
./trim-prefix.sh      # strip + drop junk without recompiling
./build.sh --opencomposite   # extra OpenVR fallback
```

Prefix: `~/.local/opt/vive-monado` (override with `VIVE_MONADO_PREFIX`).
Sources: `~/.local/src/vive-monado-steam-pop/{monado,xrizer}`.
Compile uses `nproc - 2` jobs so the 3440×1440 desktop stays alive.

## What gets built

| Piece | Why |
|---|---|
| `monado-service` | OpenXR runtime + compositor. DRM-leases the Vive HDMI on X11. |
| `libopenxr_monado.so` | Linked from `~/.config/openxr/1/active_runtime.json`. |
| xrizer | OpenVR → OpenXR. Written into `openvrpaths.vrpath`. |
| `CAP_SYS_NICE` | `setcap` on `monado-service` so AMD compute reprojection can hitch-less. |

CMake (Vive 1st gen + lighthouse only):

```
-DXRT_FEATURE_SERVICE=ON
-DXRT_FEATURE_OPENXR=ON
-DXRT_BUILD_DRIVER_STEAMVR_LIGHTHOUSE=ON
-DXRT_BUILD_DRIVER_SURVIVE=OFF
-DXRT_FEATURE_WINDOW_PEEK=OFF
-DXRT_FEATURE_DEBUG_GUI=OFF
-DXRT_FEATURE_TRACING=OFF
-DXRT_FEATURE_STEAMVR_PLUGIN=OFF
-DXRT_MODULE_MERCURY_HANDTRACKING=OFF
```

The built-in **vive** HMD driver stays on (default). **steamvr_lh** wraps
SteamVR's lighthouse binary for 6DoF. SteamVR itself stays dead
(`STEAMVR_LH_ENABLE=1` in `vive.env`). Survive, OpenHMD, simulated, SLAM,
hand tracking, and the Monado-in-SteamVR plugin stay off.

Runtime (`vive.env`): `XRT_LOG=error`, compositor scale 100%, no Vulkan
validation, no Steam overlay, no DXVK HUD, `MALLOC_ARENA_MAX=2`. Compute
reprojection stays on — turning it off hitch-steps on this RX 6600.

## Start / stop

```
./launch-monado.sh     # nohup monado-service
./stop-monado.sh       # after the session — do not leave it idle
```

Log: `~/.cache/vive-monado-service.log` (truncated each start).

## OpenComposite

Only if a given OpenVR title cannot start under xrizer:

```
./build.sh --opencomposite
```

Then point `~/.config/openvr/openvrpaths.vrpath` `runtime` at
`~/.local/opt/vive-monado/lib/opencomposite`. Keep that as fallback, not default.
