# vive-monado-steam-pop

Linux VR stack for **one** Pop!_OS box: **any Steam VR title** renders on an
HTC Vive **without Valve's `vrcompositor`**.

This is **not SteamVR**. SteamVR may stay installed so lighthouse room-setup
data exists. It must not run as the compositor. Success is **frames in both
Vive lenses** while `pgrep vrcompositor` is empty.

```
Steam VR title (Proton 9+ OpenVR/OpenXR, or native Linux OpenXR)
        │  OpenVR ──► xrizer (OpenComposite only as fallback)
        │  OpenXR ──► (direct)
        ▼
     Monado          ← compositor + runtime, DRM-leases Vive HDMI
        │
   HTC Vive 1st gen
```

Do not write a new Vulkan compositor. Do not debug SteamVR JSON. Do not enable
SteamVR beta. Do not use ALVR or WiVRn. Extra hardware is not required.

Beat Saber (`620980`) is the **smoke-test** title on this box, not a special
path. Every other VR game uses the same compositor, the same env, and the
same launch options.

## Hardware (this machine)

| Piece | Value |
|---|---|
| Distro | Pop!_OS 24.04, **GNOME on Xorg** (must stay X11) |
| Kernel | 7.0.11-76070011-generic |
| Board | MSI MAG B550 Tomahawk Max WiFi |
| CPU | Ryzen 5 5500 |
| GPU | ASRock RX 6600 8GB, **Mesa RADV only** (no amdvlk, no amdgpu-pro) |
| HMD | HTC Vive 1st gen, HDMI + USB |
| Desktop | 3440×1440 on DisplayPort |
| Steam | `~/.steam/debian-installation/` |

Proven failure: `vrcompositor` starts, desktop preview can show the game, Vive
panels stay black.

```
Vulkan wait-for-present-ID support is present, and will be used
WaitForPendingPresent: failed to wait for present
```

`disableLinuxWaitForPresent` did not light the panels.

## Architecture

1. **Monado** — OpenXR runtime + compositor. Direct mode / DRM lease on the
   Vive HDMI output (`VK_EXT_acquire_xlib_display` on X11).
2. **Envision** — preferred installer/orchestrator on Pop 24.04 (AppImage).
   Fallback: `./fallback-build.sh` if GitLab artifacts are down.
3. **xrizer** — OpenVR → OpenXR layer for Proton/Steam titles. OpenComposite
   only as fallback.
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

Then **log out or reboot** (udev + `environment.d`). Confirm X11:

```bash
echo $XDG_SESSION_TYPE    # must be x11
```

Open Envision. Profile = **Lighthouse** (Vive + base stations). First build
compiles Monado + xrizer. Do not start SteamVR from Envision except one-time
room setup if chaperone is missing.

```bash
./launch-monado.sh
./launch-game.sh --list          # installed Steam appids
./launch-game.sh <appid>
```

Paste this on **every** VR title — Steam → Properties → Launch Options.
Windows titles: Proton 9+. Native Linux OpenXR titles: same line.

```
PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1 PRESSURE_VESSEL_FILESYSTEMS_RW=$XDG_RUNTIME_DIR/monado_comp_ipc AMD_VULKAN_ICD=RADV RADV_PERFTEST=vr %command%
```

Smoke test: `./launch-game.sh 620980` (Beat Saber) or `./launch-beat-saber.sh`.

## Scripts

| File | Role |
|---|---|
| `install.sh` | Idempotent Pop 24.04 deps, Envision AppImage, xr-hardware udev, `environment.d` |
| `fallback-build.sh` | Manual Monado + xrizer prefix if Envision is down |
| `vive.env` | RADV, lighthouse, compute compositor, pressure-vessel IPC |
| `kill-steamvr.sh` | Guard: kill Valve compositor processes |
| `launch-monado.sh` | Source env, kill SteamVR, start Envision profile or `monado-service`, wait for IPC |
| `launch-game.sh` | `./launch-game.sh <appid>` — any Steam VR title |
| `list-games.sh` | Print installed Steam appid + name (`launch-game.sh --list`) |
| `launch-beat-saber.sh` | Alias for `./launch-game.sh 620980` |

## Docs

- [docs/games.md](docs/games.md) — any title, OpenVR vs OpenXR, finding appids
- [docs/envision.md](docs/envision.md) — Lighthouse profile, first build, CLI
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

MIT. No Valve proprietary binaries are shipped in this repository. SteamVR,
if present on disk, is the copy Steam already installed.
