# Envision

Envision is the installer/orchestrator. It builds Monado + xrizer into a prefix
under `~/.local/share/envision/` and starts `monado-service`. It is **not**
SteamVR.

AppImage (preferred on Pop!_OS 24.04):

- Snapshot: <https://gitlab.com/gabmus/envision/-/jobs/artifacts/main/download?job=appimage>
- Repo: <https://gitlab.com/gabmus/envision>
- Wiki: <https://vronlinux.org/docs/fossvr/envision/>

`install.sh` drops the AppImage at `~/.local/opt/envision/Envision-x86_64.AppImage`
and a desktop entry.

## Profile

**Lighthouse** (UI label: *Lighthouse driver*).

That profile is Vive + base stations. It uses Monado's `steamvr_lh` driver,
which reads the **installed** SteamVR lighthouse driver and chaperone data.
SteamVR must remain installed. SteamVR must **not** be running.

Do **not** pick Survive unless lighthouse-via-SteamVR is broken; tracking
quality is worse. Do **not** pick Simulated. Do **not** pick WiVRn / ALVR —
this repo is wired HDMI only.

## First build

1. Enable **developer mode** if you need logs, then enable **development
   profiles** (Pop does not ship current Monado/xrizer packages).
2. Select **Lighthouse**.
3. Click **Build** / **Download and build**. First build compiles Monado and
   xrizer. That takes several minutes. Let it finish.
4. Envision writes `~/.config/openxr/1/active_runtime.json` to the prefix
   `libopenxr_monado.so`.
5. OpenVR compatibility stays on **xrizer** (Preferences → General). Switch to
   OpenComposite only if a title cannot start under xrizer.

Do **not** start SteamVR from Envision except for **one-time room setup** if
`~/.steam/debian-installation/config/chaperone_info.vrchap` (or
`~/.steam/root/config/chaperone_info.vrchap`) is missing. After chaperone
exists, quit SteamVR and run `./kill-steamvr.sh`.

Envision also has a Quick Calibration. Prefer that over leaving SteamVR up.

## Start the session

Click **Start**, or run `./launch-monado.sh` from this repo.

Monado has no dashboard. After Start, the Vive panels power on and may stay a
**solid color**. That means the compositor holds the DRM lease and is waiting
for a client. Launch any VR title (`./launch-game.sh <appid>`).

If the **desktop preview** shows the game and the **lenses stay black**,
SteamVR's `vrcompositor` stole HDMI. Run `./kill-steamvr.sh` immediately.

## CLI (AppImage)

```
~/.local/opt/envision/Envision-x86_64.AppImage --list-profiles
~/.local/opt/envision/Envision-x86_64.AppImage --profile <UUID> --start
```

`launch-monado.sh` uses those flags when a lighthouse profile UUID is listed.

## CAP_SYS_NICE

AMD reprojection needs:

```
sudo setcap CAP_SYS_NICE=eip /path/to/monado-service
```

Envision usually does this after a successful build. `launch-monado.sh` warns
if `getcap` does not show `cap_sys_nice`.

If the prefix lives on a `nosuid` mount (systemd-homed), setcap is silently
useless — move the prefix off that mount.

## If Envision is down

```
./fallback-build.sh
./launch-monado.sh
```

That clones Monado + xrizer into `~/.local/src/vive-monado-steam-pop` and
installs a prefix at `~/.local/opt/vive-monado`. OpenComposite:
`./fallback-build.sh --opencomposite`.
