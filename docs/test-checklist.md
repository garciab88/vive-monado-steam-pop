# 15-minute test checklist

Hardware already on the desk: Vive HDMI + USB, 3440×1440 DP desktop, RX 6600
RADV, Pop!_OS 24.04 GNOME Xorg. Steam at `~/.steam/debian-installation/`.
Beat Saber (620980) installed.

Target: both Vive lenses show Beat Saber, and `pgrep vrcompositor` is empty.

## 0:00 — session

- [ ] `echo $XDG_SESSION_TYPE` → `x11`
- [ ] If `wayland`: **stop**, log into GNOME on Xorg, restart the clock

## 1:00 — cables

- [ ] `cat /sys/class/drm/card*-HDMI-A-*/status` → at least one `connected`
- [ ] `lsusb | grep -iE 'HTC|28de|0bb4'` shows the Vive / lighthouse dongles
- [ ] Base stations powered (solid or slow-blink, not sleeping)

## 2:00 — install (first time only)

- [ ] `chmod +x *.sh`
- [ ] `./install.sh`
- [ ] Printed `log out or reboot after udev/environment.d`
- [ ] Log out or reboot, come back on X11
- [ ] Skip this block on later runs

## 5:00 — Envision profile (first time only)

- [ ] Open Envision AppImage (`~/.local/opt/envision/Envision-x86_64.AppImage`)
- [ ] Profile = **Lighthouse** (Vive + base stations)
- [ ] Development profile / first **Build** compiles Monado + xrizer
- [ ] OpenVR compatibility = **xrizer**
- [ ] Do **not** click Start SteamVR except one-time chaperone
- [ ] If Envision cannot download: `./fallback-build.sh`

## 8:00 — compositor

- [ ] `./kill-steamvr.sh` → "SteamVR compositor stack is down"
- [ ] `./launch-monado.sh`
- [ ] Script waits until `$XDG_RUNTIME_DIR/monado_comp_ipc` exists
- [ ] `pgrep -a monado-service` is non-empty
- [ ] `pgrep -a vrcompositor` is empty
- [ ] Vive panels powered (solid color is OK — no dashboard)

## 10:00 — Beat Saber properties

- [ ] Compatibility: Proton 9.0 or newer
- [ ] Launch options exactly:

```
PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1 PRESSURE_VESSEL_FILESYSTEMS_RW=$XDG_RUNTIME_DIR/monado_comp_ipc AMD_VULKAN_ICD=RADV RADV_PERFTEST=vr %command%
```

## 12:00 — launch

- [ ] `./launch-beat-saber.sh`
- [ ] Game window may appear on the desktop. That is **not** the pass condition.
- [ ] Put the headset on. Both lenses show the Beat Saber sabers / menu.
- [ ] Look around: tracking tracks. Controllers present.

## 14:00 — prove SteamVR is not the compositor

- [ ] `pgrep -a vrcompositor` empty
- [ ] `pgrep -a vrserver` empty
- [ ] `pgrep -a vrmonitor` empty
- [ ] `pgrep -a monado-service` still running
- [ ] If lenses went black while a desktop preview looked fine: SteamVR stole
      HDMI → `./kill-steamvr.sh`, relaunch Monado, relaunch the game

## Done

Beat Saber visible in both Vive lenses with SteamVR compositor not running.

If not done in 15 minutes, do not start editing SteamVR JSON. Follow
`docs/troubleshooting.md` top to bottom.
