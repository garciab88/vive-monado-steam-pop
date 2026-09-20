# How this fixes Vive on Linux

SteamVR's compositor (`vrcompositor`) on this box can show a **desktop
preview** while the **Vive panels stay black**:

```
Vulkan wait-for-present-ID support is present, and will be used
WaitForPendingPresent: failed to wait for present
```

`disableLinuxWaitForPresent` does not light the panels. That is a Valve
compositor / present-wait bug on this AMD + X11 stack. This repo does **not**
debug that JSON. It **does not run `vrcompositor`**.

## The path

```
Steam game  →  xrizer (OpenVR→OpenXR)  →  Monado  →  Vive HDMI (DRM lease)
```

- **Monado** is the OpenXR runtime **and** the compositor. It DRM-leases the
  Vive HDMI output itself (`VK_EXT_acquire_xlib_display` on X11).
- **xrizer** is a tiny OpenVR layer so Proton titles think SteamVR is there.
- **SteamVR stays installed** only so Monado's `steamvr_lh` driver can read
  lighthouse calibration / chaperone. Scripts kill `vrcompositor` if it wakes.

Nothing else is in the path. No Envision. No ALVR. No new Vulkan compositor.

## What you open (daily)

**One thing:** `./vive-session.sh` or the **Vive** app in the GNOME menu.

That starts `monado-service` and Steam **with the Monado environment**. Then
click any VR title in the Steam library. Put the headset on.

You do **not** open:

- SteamVR / VR Monitor / SteamVR Home
- Envision
- a second compositor
- Beat Saber-specific scripts (they are leftovers)

When you are done: **Stop Vive** in the menu, or `./vive-session.sh --stop`.

## One-time (not daily)

1. `./install.sh` then log out (udev + environment.d). Stay on **GNOME on Xorg**.
2. Steam → Settings → Compatibility → enable Steam Play for all titles,
   Proton **9** / 10 / Experimental. Once. Not per game.
3. If you never did room setup: run SteamVR **once**, draw chaperone, quit,
   `./kill-steamvr.sh`. After that, never start it again.

If you launch Steam from the normal dock icon, Proton will not see Monado.
Always start Steam from **Vive**.
