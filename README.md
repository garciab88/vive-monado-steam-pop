# vive-monado-steam-pop

**AI-built. MIT. Free.** Written by Grok (xAI). Not affiliated with Valve, HTC,
or Freedesktop.

Download it. Install once. Open Steam. Click a game. Headset on.

This is a magic-bullet stack for **AMD + HTC Vive on Linux**. Valve's
`vrcompositor` blacks the Vive on this hardware (even native OpenXR titles).
Monado owns the headset instead. Steam library, **Home**, overlay, and games
all stay Steam. You do not click Play SteamVR.

Tuned first for one box (Pop!_OS, RX 6600, Vive 1st gen), then generalized to
other AMD RADV machines and Vive / Pro / Pro Eye / Pro 2.

## Use

```bash
git clone https://github.com/garciab88/vive-monado-steam-pop.git
cd vive-monado-steam-pop
chmod +x *.sh wrappers/steam
./install.sh
```

Log out once (udev). Then:

1. Plug in the Vive (HDMI/DP + USB), power the lighthouses.
2. Open **Steam** (the menu entry this install owns).
3. Click any VR game. Put the headset on.

That is the whole daily path. No launch options to paste. No Envision.

First time only, in Steam: Settings → Compatibility → Proton 9+ for all titles.

Do **not** click Play SteamVR. That is the compositor that blacks the lenses.

When you are done: **Stop Vive**, or leave it — the compositor is cheap at idle
compared to SteamVR.

## What you get

- Steam Home, library, friends, overlay — normal Steam
- OpenVR titles via xrizer, OpenXR titles direct — both through Monado
- Ultralight prefix (Vive + lighthouse drivers only, stripped)
- `~/.local/bin/steam` wrapper: if the headset is plugged in, Monado starts
  and `vrcompositor` is kept dead

## License

MIT. No Valve binaries are shipped. SteamVR on disk is only for lighthouse
calibration.
