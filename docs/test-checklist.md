# 15-minute test checklist

Hardware already on the desk: Vive HDMI + USB, 3440×1440 DP desktop, RX 6600
RADV, Pop!_OS 24.04 GNOME Xorg. Steam at `~/.steam/debian-installation/`.

Target: a VR title visible in both Vive lenses, and `pgrep vrcompositor` empty.
Any installed VR title is the pass — pick an appid from `./launch-game.sh --list`
or a slug from `./launch-game.sh --known`.

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

## 5:00 — standalone compile (first time; install.sh already did this)

- [ ] `~/.local/opt/vive-monado/bin/monado-service` exists
- [ ] `~/.config/openxr/1/active_runtime.json` points at that prefix
- [ ] `getcap ~/.local/opt/vive-monado/bin/monado-service` shows `cap_sys_nice`
- [ ] If missing: `./build.sh`
- [ ] No Envision. Do not start SteamVR except one-time chaperone if the vrchap is missing.

## 8:00 — compositor

- [ ] `./kill-steamvr.sh` → "SteamVR compositor stack is down"
- [ ] `./launch-monado.sh`
- [ ] Script waits until `$XDG_RUNTIME_DIR/monado_comp_ipc` exists
- [ ] `pgrep -a monado-service` is non-empty
- [ ] `pgrep -a vrcompositor` is empty
- [ ] Vive panels powered (solid color is OK — no dashboard)

## 10:00 — game properties (any VR title)

- [ ] `./launch-game.sh --list` — pick an installed appid
- [ ] or `./launch-game.sh --known` — pick a slug (alyx, bonelab, …)
- [ ] Compatibility: Proton 9.0 or newer if the title is Windows
- [ ] Launch options exactly (same on every title):

```
PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1 PRESSURE_VESSEL_FILESYSTEMS_RW=$XDG_RUNTIME_DIR/monado_comp_ipc AMD_VULKAN_ICD=RADV RADV_PERFTEST=vr %command%
```

## 12:00 — launch

- [ ] `./launch-game.sh <appid>`
- [ ] Game window may appear on the desktop. That is **not** the pass condition.
- [ ] Put the headset on. Both lenses show the game.
- [ ] Look around: tracking tracks. Controllers present.

## 14:00 — prove SteamVR is not the compositor

- [ ] `pgrep -a vrcompositor` empty
- [ ] `pgrep -a vrserver` empty
- [ ] `pgrep -a vrmonitor` empty
- [ ] `pgrep -a monado-service` still running
- [ ] If lenses went black while a desktop preview looked fine: SteamVR stole
      HDMI → `./kill-steamvr.sh`, relaunch Monado, relaunch the game
- [ ] After the session: `./stop-monado.sh` — compositor must not sit idle

## Done

Chosen VR title visible in both Vive lenses with SteamVR compositor not running.

If not done in 15 minutes, do not start editing SteamVR JSON. Follow
`docs/troubleshooting.md` top to bottom. Next title: skip to 10:00.
