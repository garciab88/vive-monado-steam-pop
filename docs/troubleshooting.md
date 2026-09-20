# Troubleshooting

Proven failure (AMD + SteamVR on Linux): `vrcompositor` starts, desktop
preview can show the game, Vive panels stay black.

```
Vulkan wait-for-present-ID support is present, and will be used
WaitForPendingPresent: failed to wait for present
```

`disableLinuxWaitForPresent` in `steamvr.vrsettings` did **not** light the
panels. Stop routing through Valve's compositor. This stack is Monado.

Run `./vive-doctor.sh` first.

## Session

```
echo $XDG_SESSION_TYPE
```

`x11` is the proven Vive DRM-lease path. AMD + KDE/wlroots Wayland can work.
**GNOME Wayland** often cannot lease the HMD — log into **GNOME on Xorg**
(or Plasma X11).

## HMD connector

Vive 1st gen is usually HDMI. Vive Pro / Pro 2 are usually DisplayPort.

```
./vive-doctor.sh
# or
cat /sys/class/drm/card*-HDMI-A-*/status
cat /sys/class/drm/card*-DP-*/status
```

At least one connector must be `connected` when the headset is plugged in
and powered.

```
xrandr --prop | grep -A2 -i 'hdmi\|dp-\|non-desktop'
```

The HMD should show `non-desktop: 1`. If it appears as an extra desktop
monitor, unplug/replug power, then the video cable, then USB.

## AMD only (RADV)

```
echo $AMD_VULKAN_ICD    # must be RADV
# uninstall amdvlk / amdgpu-pro if present
```

## Preview works, lenses black

SteamVR compositor stole the display.

```
./kill-steamvr.sh
pgrep -a vrcompositor; pgrep -a vrserver; pgrep -a vrmonitor
```

All three must be empty. Then `./launch-monado.sh` and start the game again.

`install.sh` sets `power.autoLaunchSteamVROnButtonPress = false` in
`steamvr.vrsettings` if that file exists. Vive proximity / a Steam "Start in
VR" toggle can still wake `vrcompositor`. The kill script is the guard.

## Monado IPC missing

```
ls -l $XDG_RUNTIME_DIR/monado_comp_ipc
```

If that path does not exist, the game cannot submit frames into Monado
(pressure-vessel will look for it too). Start `./launch-monado.sh` and wait
until it prints that IPC is up.

## CAP_SYS_NICE for AMD reprojection

```
MONADO=~/.local/opt/vive-monado/bin/monado-service
getcap "$MONADO"
sudo setcap CAP_SYS_NICE=eip "$MONADO"
```

Without this, `XRT_COMPOSITOR_COMPUTE=1` hitch-steps on RADV.

## Proton must be 9+

Windows VR titles are OpenVR or OpenXR inside Proton.
Proton 9+ is what exposes OpenXR inside the container after xrizer satisfies
the OpenVR check. Proton 8 and older will hunt for SteamVR and fail.

Steam → the game → Properties → Compatibility → force Proton 9.0 / 10 /
Experimental. Same rule on every Windows VR title.

Native Linux OpenXR titles skip Proton; they still need the launch-options
line so pressure-vessel imports Monado.

## Wrong Vulkan ICD

```
AMD_VULKAN_ICD=RADV vulkaninfo --summary | head
```

You want `AMD RADV NAVI23` (RX 6600). If you see AMDVLK, uninstall it:

```
sudo apt purge amdvlk libamdvlk64
```

Do not install amdgpu-pro.

## environment.d did not reach Steam

GNOME on X11 may not import `~/.config/environment.d/` into apps launched from
the dock. That is why the **per-game launch options** in
`docs/steam-launch-options.md` are mandatory even after `install.sh`.

Log out anyway after the first install so udev ACLs apply to the Vive USB
interfaces.

## xrizer vs OpenComposite

Default is xrizer. If an OpenVR title crashes on OpenVR init or controllers
do not bind:

```
./build.sh --opencomposite
```

Point `~/.config/openvr/openvrpaths.vrpath` `runtime` at
`~/.local/opt/vive-monado/lib/opencomposite`.

Keep SteamVR's runtime **out** of that file.

## Chaperone / tracking origin missing

SteamVR stays installed so lighthouse calibration data exists:

- `~/.steam/debian-installation/config/chaperone_info.vrchap`
- `~/.steam/root/config/lighthouse/lighthousedb.json`

If those are missing, run SteamVR **once** for room setup, then
`./kill-steamvr.sh`. Do not leave SteamVR running.

## Base stations

Power the 1.0 base stations **before** `monado-service`. Monado does not
hotplug lighthouse devices reliably. Controllers on, stations on, then
`./launch-monado.sh`.
