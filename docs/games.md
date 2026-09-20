# Any VR title on this stack

One compositor (Monado). One OpenVR layer (xrizer). One launch-options line.
The game does not matter. This box is Vive 1st gen + RADV + X11; the title is
just a Steam appid.

```
./launch-monado.sh
./launch-game.sh --list          # what Steam has installed
./launch-game.sh --known         # catalog slugs
./launch-game.sh <appid|slug>
```

Examples:

```
./launch-game.sh alyx
./launch-game.sh 546560
./launch-game.sh bonelab
./launch-game.sh skyrim-vr
```

Add a row to `lib/titles.tsv` for a slug you use often.

## Launch options (every title)

Steam → the game → Properties → Launch Options — **same line, every title**:

```
PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1 PRESSURE_VESSEL_FILESYSTEMS_RW=$XDG_RUNTIME_DIR/monado_comp_ipc AMD_VULKAN_ICD=RADV RADV_PERFTEST=vr %command%
```

Details: [steam-launch-options.md](steam-launch-options.md).

## Windows vs native Linux

| Kind | What to set | Path into Monado |
|---|---|---|
| Windows OpenVR (most Steam VR) | Proton **9+** + the line above | game → xrizer → OpenXR → Monado |
| Windows OpenXR | Proton **9+** + the line above | game → OpenXR → Monado |
| Native Linux OpenXR | the line above (imports the runtime into pressure-vessel) | game → OpenXR → Monado |
| Native Linux OpenVR | the line above + xrizer via `openvrpaths.vrpath` | game → xrizer → Monado |

Proton 8 and older hunt for SteamVR and fail. Force Proton 9.0 / 10 /
Experimental on every Windows VR title.

If xrizer cannot start a given OpenVR title:
`./build.sh --opencomposite` and point `openvrpaths.vrpath` at
`~/.local/opt/vive-monado/lib/opencomposite`. Keep that as fallback, not default.

## Catalog slugs (`lib/titles.tsv`)

Not an installed-games list. These are names this repo will resolve so you do
not have to memorize appids. Vive wands work on most; some titles default to
Index/Knuckles bindings.

| slug | appid | name |
|---|---|---|
| earth-vr | 348250 | Google Earth VR |
| arizona-sunshine | 342180 | Arizona Sunshine |
| elite | 359320 | Elite Dangerous |
| vrchat | 438100 | VRChat |
| job-simulator | 448280 | Job Simulator |
| the-lab | 450390 | The Lab |
| h3vr | 450540 | H3VR |
| rec-room | 471710 | Rec Room |
| alyx | 546560 | Half-Life: Alyx |
| pavlov | 555160 | Pavlov VR |
| gorn | 578620 | GORN |
| fallout4-vr | 611660 | Fallout 4 VR |
| skyrim-vr | 611670 | Skyrim VR |
| superhot-vr | 617830 | SUPERHOT VR |
| beat-saber | 620980 | Beat Saber |
| blade-sorcery | 629730 | Blade & Sorcery |
| vtol-vr | 667970 | VTOL VR |
| walkabout | 680380 | Walkabout Mini Golf |
| neos | 740250 | Neos VR |
| boneworks | 823500 | BONEWORKS |
| moss | 846470 | Moss |
| synth-riders | 885000 | Synth Riders |
| saints-sinners | 916840 | Saints & Sinners |
| until-you-fall | 965160 | Until You Fall |
| into-the-radius | 1012790 | Into the Radius |
| pistol-whip | 1079800 | Pistol Whip |
| bonelab | 1592190 | BONELAB |
| into-the-radius-2 | 1966720 | Into the Radius 2 |
| resonite | 2519830 | Resonite |
| nms | 275850 | No Man's Sky |

`launch-beat-saber.sh` is only a leftover alias for `./launch-game.sh beat-saber`.

## Find an installed appid

```bash
./launch-game.sh --list
# or
./list-games.sh
```

Reads `appmanifest_*.acf` under `~/.steam/debian-installation/steamapps/`
(and the usual Steam symlink locations). Otherwise: Steam store URL
`store.steampowered.com/app/<appid>/`.

## Per-title checklist (30 seconds)

1. Monado already up (`./launch-monado.sh` once per session).
2. SteamVR dead (`./kill-steamvr.sh` if a title woke it).
3. Launch options pasted. Proton 9+ if Windows.
4. `./launch-game.sh <appid|slug>`
5. Lenses show the game. `pgrep vrcompositor` empty.

Desktop preview with black lenses = SteamVR stole HDMI. Kill it. Relaunch
Monado. Relaunch the game. Same for every title.

## What this stack will not do

- ALVR / WiVRn / wireless Quest-class streaming
- GNOME Wayland
- amdvlk / amdgpu-pro
- Starting `vrcompositor` “just for this one game”
