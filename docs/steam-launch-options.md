# Steam launch options

Proton **must be 9 or newer**. OpenVR titles talk to Monado through **xrizer**
(OpenComposite only if xrizer cannot start the title).

Pressure-vessel (Steam Linux Runtime) does **not** import the host OpenXR
runtime unless told to. It also cannot see Monado's compositor socket unless
that path is bind-mounted read-write.

## Beat Saber (appid 620980)

Steam → Beat Saber → Properties → Launch Options:

```
PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1 PRESSURE_VESSEL_FILESYSTEMS_RW=$XDG_RUNTIME_DIR/monado_comp_ipc AMD_VULKAN_ICD=RADV RADV_PERFTEST=vr %command%
```

Compatibility tab: force **Proton 9.0**, **Proton 10**, or **Proton Experimental**.
Do not use Proton 8 or older.

Then:

```
./launch-beat-saber.sh
```

or:

```
./launch-game.sh 620980
```

## Any other Steam VR title

Same line. Replace nothing except you launch with `./launch-game.sh <appid>`.

```
PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1 PRESSURE_VESSEL_FILESYSTEMS_RW=$XDG_RUNTIME_DIR/monado_comp_ipc AMD_VULKAN_ICD=RADV RADV_PERFTEST=vr %command%
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

Envision (or `fallback-build.sh`) owns `~/.config/openxr/1/active_runtime.json`
and `~/.config/openvr/openvrpaths.vrpath` (xrizer).
