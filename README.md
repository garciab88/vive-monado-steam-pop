# vive-monado-steam-pop

**AI-built.** Written by Grok (xAI). Not affiliated with Valve, HTC, or
Freedesktop/Monado.

Linux VR stack for **AMD + HTC Vive**: any Steam VR title renders on a Vive-family
headset **without Valve's `vrcompositor`**.

Standalone: **Monado + xrizer**, compiled locally. **No Envision.** SteamVR
may stay installed so lighthouse room-setup data exists. It must not run as
the compositor. Success is **frames in both lenses** while
`pgrep vrcompositor` is empty.

```
Steam VR title (Proton 9+ OpenVR/OpenXR, or native Linux OpenXR)
        │  OpenVR ──► xrizer (OpenComposite only as fallback)
        │  OpenXR ──► (direct)
        ▼
     Monado          ← compositor + runtime, DRM-leases the HMD
        │
   HTC Vive / Pro / Pro Eye / Pro 2
```

Do not write a new Vulkan compositor. Do not debug SteamVR JSON. Do not enable
SteamVR beta. Do not use ALVR or WiVRn.

**Daily: click Vive, then click a game in Steam.** Do not open SteamVR.
Do not open Envision. After play: Stop Vive.

See [docs/how.md](docs/how.md) and [docs/hardware.md](docs/hardware.md).

## Who this is for

| Need | This stack |
|---|---|
| GPU | AMD, **Mesa RADV** (no amdvlk) |
| HMD | Vive 2016, Vive Pro, Vive Pro Eye, Vive Pro 2 |
| Distro | Debian/Ubuntu/Pop, Fedora/Nobara, Arch/CachyOS |
| Session | Xorg proven; AMD KDE/wlroots Wayland possible |
| Games | Any Steam VR title, Proton 9+ |

Reference machine (where `vrcompositor` was proven black-lens): Pop!_OS 24.04
GNOME Xorg, RX 6600, Vive 1st gen HDMI. Other AMD boxes use the same path.

Proven failure: `vrcompositor` starts, desktop preview can show the game, Vive
panels stay black.

```
Vulkan wait-for-present-ID support is present, and will be used
WaitForPendingPresent: failed to wait for present
```

`disableLinuxWaitForPresent` did not light the panels.

## Architecture

1. **Monado** — OpenXR runtime + compositor. Direct mode / DRM lease on the
   Vive HDMI output (`VK_EXT_acquire_xlib_display` on X11). Built into
   `~/.local/opt/vive-monado`.
2. **build.sh** — ultralight Monado + xrizer (Vive + steamvr_lh only,
   stripped). `install.sh` runs it. No Envision.
3. **xrizer** — OpenVR → OpenXR layer for Proton/Steam titles. OpenComposite
   only as fallback (`./build.sh --opencomposite`).
4. **SteamVR** — installed for lighthouse calibration. Scripts kill
   `vrcompositor` / `vrserver` / `vrmonitor` / `vrwebhelper` / `vrdashboard`
   if they wake.
5. **Steam + Proton 9+** — any VR appid launches into Monado.

## First run

```bash
git clone https://github.com/garciab88/vive-monado-steam-pop.git
cd vive-monado-steam-pop
chmod +x *.sh
./install.sh
```

`install.sh` installs packages, udev rules, then **compiles Monado + xrizer**
(several minutes). Then **log out or reboot**. Confirm X11:

```bash
echo $XDG_SESSION_TYPE    # must be x11
```

**Once in Steam:** Settings → Compatibility → enable Steam Play for all titles,
Proton 9 / 10 / Experimental.

**Every day after that:**

```bash
./vive-session.sh
```

Or click **Vive** in the GNOME app menu. Steam opens with Monado already
holding the headset. Click any VR title. Do not start SteamVR.

```bash
./vive-session.sh --stop
```

You do **not** paste per-game launch options if Steam was started this way.
`./launch-game.sh` is optional. Details: [docs/how.md](docs/how.md).

## Scripts

| File | Role |
|---|---|
| `install.sh` | Idempotent Pop 24.04 deps, xr-hardware udev, `environment.d`, first compile |
| `build.sh` | Ultralight Monado + xrizer (`~/.local/opt/vive-monado`) |
| `trim-prefix.sh` | Strip + drop cargo junk without recompiling |
| `vive.env` | RADV, lighthouse, scale 100%, no overlay/HUD/debug logs |
| `kill-steamvr.sh` | Guard: kill Valve compositor if it wakes |
| `vive-session.sh` | **Daily:** start Monado + Steam. `--stop` when done |
| `vive-doctor.sh` | Print GPU, session, Steam path, DRM connectors |
| `launch-monado.sh` | Start compositor only (used by vive-session) |
| `stop-monado.sh` | Stop compositor after the session |
| `launch-game.sh` | `./launch-game.sh <appid\|slug>` — any Steam VR title (`--list`, `--known`) |
| `list-games.sh` | Print installed Steam appid + name |
| `lib/titles.tsv` | Slug catalog (alyx, bonelab, skyrim-vr, …) |

## Docs

- [docs/how.md](docs/how.md) — why Vive was black, what you actually open
- [docs/hardware.md](docs/hardware.md) — AMD + Vive family, distros, GPUs
- [docs/games.md](docs/games.md) — any title, slugs, OpenVR vs OpenXR
- [docs/steam-launch-options.md](docs/steam-launch-options.md) — the one line for every game
- [docs/troubleshooting.md](docs/troubleshooting.md) — X11, HDMI, black lenses
- [docs/test-checklist.md](docs/test-checklist.md) — 15-minute numbered pass

## Definition of done

The VR title is visible in **both Vive lenses** and the SteamVR compositor is
**not running**.

```bash
pgrep -a monado-service    # running
pgrep -a vrcompositor      # empty
pgrep -a vrserver          # empty
```

A desktop preview of the game with black lenses is a **fail** — that is the
old `WaitForPendingPresent` bug. Kill SteamVR and go through Monado.

## License

MIT. This repository is **AI-built** (Grok / xAI). No Valve proprietary
binaries are shipped here. SteamVR, if present on disk, is the copy Steam
already installed. Monado, xrizer, Steam, and the HTC Vive are their owners'
trademarks; this is an independent launcher, not an official product.
