# Steam launch options

**Daily path does not use this file.** Start Steam with `./vive-session.sh`
(or the **Vive** menu entry). The environment is already on that Steam
process. Click the game. Do not paste anything.

This page is only if you launched Steam from the normal dock icon.

Proton **must be 9 or newer** on Windows titles (Steam → Settings →
Compatibility → enable Steam Play for all titles — once).

Pressure-vessel (Steam Linux Runtime) does **not** import the host OpenXR
runtime unless told to. It also cannot see Monado's compositor socket unless
that path is bind-mounted read-write.

## The line

Steam → the game → Properties → Launch Options:

```
PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1 PRESSURE_VESSEL_FILESYSTEMS_RW=$XDG_RUNTIME_DIR/monado_comp_ipc AMD_VULKAN_ICD=RADV RADV_PERFTEST=vr %command%
```

Compatibility tab (Windows): force **Proton 9.0**, **Proton 10**, or
**Proton Experimental**. Do not use Proton 8 or older.

Then:

```
./launch-game.sh --list
./launch-game.sh --known
./launch-game.sh <appid|slug>
```

## What each token does

| Token | Why |
|---|---|
| `PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1` | Copy host `active_runtime.json` (Monado) into the container. |
| `PRESSURE_VESSEL_FILESYSTEMS_RW=$XDG_RUNTIME_DIR/monado_comp_ipc` | Bind-mount Monado's compositor IPC. Without this the game cannot submit frames. |
| `AMD_VULKAN_ICD=RADV` | Never amdvlk. RADV is the only ICD that DRM-leases the Vive on this GPU. |
| `RADV_PERFTEST=vr` | RADV VR compiler path. |
| `%command%` | Required Steam placeholder. |

`install.sh` also writes `~/.config/environment.d/99-vive-monado.conf` with
`PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1`. GNOME on X11 does not always
import `environment.d` into the Steam process — **the per-game line is the
source of truth**. Log out after install anyway.

## Do not put these in launch options

- Anything that starts SteamVR (`vrstartup`, `steam://run/250820`).
- `disableLinuxWaitForPresent` — that is a SteamVR compositor flag. We do not
  run that compositor. It will not light the panels.
- `VR_OVERRIDE` pointing at SteamVR's `vrclient.so`.
- `XR_RUNTIME_JSON` pointing at SteamVR's `vrserver` manifest.

`build.sh` owns `~/.config/openxr/1/active_runtime.json` and
`~/.config/openvr/openvrpaths.vrpath` (xrizer).
