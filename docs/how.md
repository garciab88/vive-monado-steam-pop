# How this fixes Vive on Linux

SteamVR's compositor (`vrcompositor`) on AMD + Mesa can show a **desktop
preview** while the **headset panels stay black**:

```
Vulkan wait-for-present-ID support is present, and will be used
WaitForPendingPresent: failed to wait for present
```

`disableLinuxWaitForPresent` does not light the panels. That is a Valve
compositor / present-wait bug. This repo does **not** debug that JSON. It
**does not run `vrcompositor`**.

## The path

```
Steam game  →  xrizer (OpenVR→OpenXR)  →  Monado  →  Vive HDMI or DP (DRM lease)
```

Works on **AMD RADV** with Vive (2016), Vive Pro, Vive Pro Eye, Vive Pro 2.
Same session on Pop, Ubuntu, Fedora, Arch.

- **Monado** is the OpenXR runtime **and** the compositor. It DRM-leases the
  HMD itself.
- **xrizer** is a tiny OpenVR layer so Proton titles think SteamVR is there.
- **SteamVR stays installed** only so Monado's `steamvr_lh` driver can read
  lighthouse calibration / chaperone. Scripts kill `vrcompositor` if it wakes.

Nothing else is in the path. No Envision. No ALVR. No new Vulkan compositor.

## What you open (daily)

**Steam.** The install replaces your user Steam menu entry with a wrapper.
If the Vive is plugged in, Monado starts and Valve's compositor is kept dead.
Library, Home, overlay, friends — normal Steam. Click a game.

Do not click **Play SteamVR**. That button is `vrcompositor` (black lenses).
Valve's 3D SteamVR apartment is that compositor. Steam's own Home tab is not.

## One-time (not daily)

1. `./install.sh` then log out (udev + environment.d). Prefer **Xorg**.
2. Steam → Settings → Compatibility → enable Steam Play for all titles,
   Proton **9** / 10 / Experimental. Once.
3. If you never did room setup: run SteamVR **once**, draw chaperone, quit,
   `./kill-steamvr.sh`. After that, never start it again.

If you launch Steam from the normal dock icon, Proton will not see Monado.
Always start Steam from **Vive**.
