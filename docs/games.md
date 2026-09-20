# Any VR title on this stack

One compositor (Monado). One OpenVR layer (xrizer). One launch-options line.
The game does not matter.

```
./launch-monado.sh
./launch-game.sh --list
./launch-game.sh <appid>
```

Beat Saber (`620980`) is only the 15-minute smoke test. `launch-beat-saber.sh`
is an alias for `./launch-game.sh 620980`.

## Launch options (every title)

Steam → the game → Properties → Launch Options:

```
PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1 PRESSURE_VESSEL_FILESYSTEMS_RW=$XDG_RUNTIME_DIR/monado_comp_ipc AMD_VULKAN_ICD=RADV RADV_PERFTEST=vr %command%
```

Do not change the line per game. Details: [steam-launch-options.md](steam-launch-options.md).

## Windows vs native Linux

| Kind | What to set | Path into Monado |
|---|---|---|
| Windows OpenVR (most Steam VR) | Proton **9+** + the line above | game → xrizer → OpenXR → Monado |
| Windows OpenXR | Proton **9+** + the line above | game → OpenXR → Monado |
| Native Linux OpenXR | the line above (imports the runtime into pressure-vessel) | game → OpenXR → Monado |
| Native Linux OpenVR | the line above + xrizer via `openvrpaths.vrpath` | game → xrizer → Monado |

Proton 8 and older hunt for SteamVR and fail. Force Proton 9.0 / 10 /
Experimental on every Windows VR title.

If xrizer cannot start a given OpenVR title, switch Envision → Preferences →
General → OpenVR compatibility → **OpenComposite**, or
`./fallback-build.sh --opencomposite`. Keep that as fallback, not default.

## Find the appid

```bash
./launch-game.sh --list
# or
./list-games.sh
```

That reads `appmanifest_*.acf` under `~/.steam/debian-installation/steamapps/`
(and the usual Steam symlink locations).

Otherwise: Steam store URL `store.steampowered.com/app/<appid>/`.

## Per-title checklist (30 seconds)

1. Monado already up (`./launch-monado.sh` once per session).
2. SteamVR dead (`./kill-steamvr.sh` if a title woke it).
3. Launch options pasted. Proton 9+ if Windows.
4. `./launch-game.sh <appid>`
5. Lenses show the game. `pgrep vrcompositor` empty.

Desktop preview with black lenses = SteamVR stole HDMI. Kill it. Relaunch
Monado. Relaunch the game. Same for every title.

## What this stack will not do

- ALVR / WiVRn / wireless Quest-class streaming
- GNOME Wayland
- amdvlk / amdgpu-pro
- Starting `vrcompositor` “just for this one game”
