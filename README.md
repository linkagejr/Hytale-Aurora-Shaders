
<a href="https://buymeacoffee.com/kristijan1001" target="_blank"> <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" width="160" alt="Buy Me a Coffee"> </a>

https://youtu.be/DMA2joELGH0

https://github.com/user-attachments/assets/9c0842a6-0442-40e9-8760-67f695989e0c

https://github.com/user-attachments/assets/55316aae-4729-4537-8840-b3e5d5a30a6e

<img width="3840" height="2160" alt="HytaleClient_mA5cWvFjpR" src="https://github.com/user-attachments/assets/a9f44805-9e51-40f8-b493-9174b37dedc8" />

<img width="3840" height="2160" alt="HytaleClient_jA8qtVqNoz" src="https://github.com/user-attachments/assets/3a8d26e4-41b2-4e28-87d4-f94f4158ffc4" />

<img width="2956" height="1663" alt="HytaleClient_xQDaUhgztt" src="https://github.com/user-attachments/assets/098cc4b4-380c-488e-90d5-f2a9a69fa49f" />

<img width="3840" height="2160" alt="HytaleClient_ARPBNL3it1" src="https://github.com/user-attachments/assets/b79537e3-1a60-4631-a084-619f9bd18946" />

<img width="3840" height="2160" alt="HytaleClient_XLE7vjtrBp" src="https://github.com/user-attachments/assets/1cf4d1f9-71e0-4597-a119-d9321ea4f554" />

<img width="3840" height="2160" alt="image" src="https://github.com/user-attachments/assets/bba36eb8-ee54-4599-a0a7-34b65995309c" />

<img width="3840" height="2160" alt="HytaleClient_iXEQJUArUL" src="https://github.com/user-attachments/assets/ae779dc9-944d-4ca4-a88d-f1c164e0393e" />

<img width="3840" height="2160" alt="HytaleClient_jK6PYPZ5mO" src="https://github.com/user-attachments/assets/b16a91c7-6f33-4242-9e1a-ab10f8d40eb3" />

<img width="3840" height="2160" alt="HytaleClient_iPaT8SGzRg" src="https://github.com/user-attachments/assets/b8ce33f3-78bc-4877-977a-638c4319377b" />

<img width="3840" height="2160" alt="HytaleClient_1Ct0iumhDG" src="https://github.com/user-attachments/assets/605dfb67-8cc8-475a-9dc9-0d5d6c546140" />

<img width="3840" height="2160" alt="HytaleClient_yiDS4pwOJz" src="https://github.com/user-attachments/assets/3d899ec1-089d-4af7-8fac-14bec9981215" />

<img width="3840" height="2160" alt="HytaleClient_9uBVvnw0u2" src="https://github.com/user-attachments/assets/fa8cc289-cdb0-4e77-b53e-8d5332a578e1" />

<img width="3840" height="2160" alt="image" src="https://github.com/user-attachments/assets/e35d3088-7386-4fbb-8ac3-0dd1624d1a57" />

<img width="3840" height="2160" alt="HytaleClient_nKmVvN2vCb" src="https://github.com/user-attachments/assets/287daae9-44d0-4441-810f-5fac7b174c9a" />

<img width="3840" height="2160" alt="image" src="https://github.com/user-attachments/assets/6c50f4f3-098d-4eac-86d0-67ac4d0e60f9" />

<img width="3840" height="2160" alt="HytaleClient_pmXZrodYOq" src="https://github.com/user-attachments/assets/d1f9550a-67e7-4a15-9620-515b5e6832af" />

# Aurora Shaders for Hytale

[Download 1.4.1](../../releases/tag/v1.4.1) · [Changelog](CHANGELOG.md)

A shader pack for Hytale: soft sun shadows, volumetric clouds, light shafts through trees and
caves, reflective water, ray-traced bounce light and ambient occlusion, rain puddles, rainbows,
a rotating star sky, lens flare and a filmic tonemap - with an in-game options menu.

> **Not tested online, use at your own discretion.**

## Install

### Linux

For the Linux Hytale client (x86_64), from the official Flatpak or a native launcher install.
The download includes a prebuilt library, so no compiler or extra packages are needed; only
`python3`, which reads the game's own shaders.

Close Hytale, then from this folder:

```bash
bash install.sh
```

Then **start Hytale normally** (launcher or desktop shortcut; if the launcher was open, close it
and start it again). Home opens the options, Pause switches the shaders off and on.

The installer changes no game file. For the Flatpak it sets a user override
(`flatpak override --user com.hypixel.HytaleLauncher`) that preloads `libaurora.so` into the
game and lets it read this folder; for a native install it adds a "Hytale (Aurora Shaders)"
launcher. **Keep this folder**: the game loads the shaders and saves the menu settings here
(`shaderpack/include/AU_Settings.glsl`). An earlier Aurora install (an older folder, or the
SDL3 proxy below) is replaced; the settings you changed there come along (the others start at
this version's defaults), as do custom profiles and foliage masks.

- **After a game update:** close Hytale and run `bash install.sh` again. Until then the hook
  keeps the game's own shaders.
- **Custom game location:** `bash install.sh --client-dir "/path/to/Client"`.
- **Rebuild from source:** `bash install.sh --build` (needs a C compiler, e.g. `build-essential`).
- **Uninstall:** `bash uninstall.sh`; the game is back to vanilla.
- **Another preloader** (MangoHud, gamemode) in the same override keeps working.

Alternatively, `python3 tools/linux_install.py` installs the SDL3 proxy instead: it replaces the
game's `Client/libSDL3.so` (keeping the original as `libSDL3.aurora-original.so`) and copies the
pack into `Client/.aurora/shaderpack`; `python3 tools/linux_install.py --uninstall` restores the
original. Use one method or the other: `install.sh` removes the proxy, and while the proxy is
in the game folder the preloaded library stays inactive.

**DLSS and its render-scale integration are Windows-only** and are hidden in the Linux menu.
Linux uses the pack's temporal anti-aliasing.

### Windows

1. Download the latest release zip from the [Releases](../../releases) page and extract it
   somewhere permanent (the game loads the pack from this folder, so don't delete it).
2. Close Hytale and double-click **`Install.bat`**.
3. Start Hytale.

The installer offers the detected game, an executable picker that supports any drive,
or a pasted installation/executable path. It reads the game's shaders from your own `HytaleClient.exe`, and puts a small
`opengl32.dll` next to the game. Nothing in the game itself is modified.

Install and Update both remove the previous Aurora files and links before installing the new build.
Changed DLL hashes or stale receipts do not block cleanup. Recovery files are stored under the
Aurora package's `backups/` folder, outside the game directory. If the destination
drive cannot create a junction, the installer copies the pack instead. Copied installs preserve
existing setting values on upgrade; edit that installed copy for hot reload. Installation failures
restore the previous client files, and the installed DLL is checksum-verified.

- **After a Hytale update**, run `Update.bat`, or choose **Update shaders for a new game version** in the installer. It clean-installs and regenerates shaders from the new client.
- **To remove it**, double-click `Uninstall.bat`: Aurora's DLL, shaderpack link/copy, receipt, and old Aurora install debris are removed from the game folder. Junction targets are preserved; recovery files stay outside the game.

Requires Windows 10 or 11 and a GPU that runs Hytale. The pack is heavier than vanilla,
especially the RTX preset; see [Performance](#performance).

## In game

| Key | |
|---|---|
| **Home** | Opens / closes the options menu. |
| **Hold Alt** | Edit the small left-side panel; release to move and look normally. |
| **Up / Down** | Select an option, without Alt. |
| **Left / Right** | Change it (hold to slide numbers), without Alt. |
| **PgUp / PgDn** | Switch category tabs, without Alt. |
| **Alt + Mouse** | Click tabs and switches; drag sliders; scroll the current category. |
| **Escape** | Close the menu. |
| **Pause** | Shaders off / on, for quick comparisons. |

Changes apply instantly; default values and slider markers are yellow, including On/Off switches.
Click the search box while holding Alt to search by setting label or define; Backspace edits
the search text only. Tab, Enter and Space do not navigate or change settings.
Enter only confirms text entry when naming a saved preset.
Changed values are mint, and the selected option's default is always shown in the footer. Settings are saved in
`shaderpack/include/AU_Settings.glsl`, which you can also edit by hand while the game runs (saving
the file reloads the shaders). On Linux, edit `shaderpack/include/AU_Settings.glsl` in the
folder you installed from.

The compact left-side menu leaves the centre of the game visible and does not capture movement
or camera input unless Alt is held. Keyboard shortcuts remain available without Alt;
typing in search captures keys until Enter or an arrow key leaves the search field.
The vertically centred panel has category tabs, global search, per-category scrolling, and help for
the selected setting. **Reset selected** resets only that option, never the entire pack.
The ore sweep uses a continuous world-space band with a feathered highlight instead of
triangle-by-triangle screen-space brightening. Its strength, speed and band width are in
**Ores & materials**, separate from the ore's base glow and surrounding light.
Ore blink strength and speed control a coloured glow pulse; zero strength restores steady glow.
**Ore animation** selects blinking plus the soft glint, the original Hytale glint without
blinking, or entirely steady glow. None of these choices disables the base coloured glow.

Linux currently uses the keyboard controls; Alt-mouse editing and input capture are Windows features.

### Profiles

Open **Profiles** and click an entry, or highlight it with the arrow keys and press Right.
**Default** restores the saved original defaults, kept separately from the quality presets.
**RTX** and **Non-RTX** each offer **Lowest, Low, Medium, High, Highest and Ultra**.
Higher levels increase shadow, cloud, reflection and lighting quality. The old Preset selector
is replaced by this list; the shipped configuration still uses the RTX feature set.

RTX profiles include bounce GI and material reflections, using NVIDIA Ray Reconstruction
with **77% Quality+ DLSS** where supported. Non-RTX profiles use native resolution, the lighter
lighting path and Original denoising, with DLSS off. Neither family enables Frame
Generation or path tracing. Those remain available as manual settings. Builds without
NVIDIA support use Original as the fallback for RTX profiles.
Coloured area lights are enabled only by **Ultra** in either quality list; you can still toggle them manually.

**Save current settings as...** lets you name and save up to 16 custom presets. Hold Alt to type
a name, then press Enter or click **Save name**. Presets are stored in `shaderpack/presets/`
and retained during updates. On Linux, use the keyboard to enter the name. Applying a built-in profile resets other
shader-menu settings to their defaults; saving a custom preset keeps your current settings.

To manage a custom preset, apply it, then choose **Export saved profile** or **Delete saved profile**.
Exports are named `.glsl` files in `shaderpack/presets/exports/`; repeated exports create new copies.
Deletion requires a second confirmation within five seconds, keeps your current shader settings and
never deletes Default, quality presets or exported copies. To import a shared export, copy it into an
unused `shaderpack/presets/preset-00.glsl` through `preset-15.glsl` slot, then reopen the menu. Do not
overwrite an existing slot. On Linux this is `shaderpack/presets/` in the folder you installed from
(`Client/.aurora/shaderpack/presets/` with the SDL3 proxy).

## Menu options

### Surface detail and atmosphere

The TAA reminder is the first entry in **General**.

**Ores & materials → Surface detail & shading** adds adjustable texture definition and roughness,
specular antialiasing, directional ambient depth, matte foliage and outdoor sunlight. It defaults to On in all
profiles. Individual controls are under Lighting, Ores & materials and Shadows. [Details](docs/visual-polish.md).

**Sky & atmosphere → Biome & weather atmosphere** keeps Hytale's fog, sky and cloud colours, including special worlds,
without replacing Aurora's sunlight, ambient lighting or colour grading. Switch it off to restore the previous
atmosphere. It defaults to Off in all profiles and reloads immediately. [Details and research](docs/biome-atmosphere.md).

| Option | What it does |
|---|---|
| **Shaders** | Turns the whole pack on or off (same as the Pause key). |
| **Brightness** | Overall brightness of shaded areas and nights, like Minecraft's brightness slider: low is moody, high is bright. |
| **Cave lighting %** | The minimum light in places the sun and sky can't reach - caves, deep interiors. Lower makes caves darker. |

### Lighting

**Outdoor sunlight** balances direct sun against directional sky fill, protects bright diffuse textures
and refines backlit foliage. It defaults to On from Medium through Ultra in both profile families,
and Off in Lowest and Low. Each effect has its own slider. Sunlight bounce reuses the existing GI rays
in the RTX family and path tracing; it does not enable GI in Non-RTX profiles. **Shadows → Sun-sized soft
shadows** controls distance-dependent penumbrae and contact strength. These controls require Surface
detail & shading, add no passes or history buffers, and leave biome atmosphere independent. [Details](docs/outdoor-sunlight.md).

| Option | What it does |
|---|---|
| **Ambient occlusion** | How dark corners, crevices and the spots under objects get. |
| **Torch light** | Brightness of light from torches, lanterns, lava and other light blocks. |
| **Torch colour (warm to Hytale)** | 0 gives every light a classic warm orange glow; 1 uses Hytale's own colour for each light (blue crystals, green lights...). |
| **Emissive glow** | How strongly glowing blocks themselves shine - lava, flames, crystals. |
| **Block relief** | Gives block textures a slight 3D surface, so stone, bricks and wood catch the light per pixel. |
| **Relief strength** | How deep that relief looks. |
| **Foliage translucency** | Sunlight shining through leaves and grass when the sun is behind them. |
| **Scattering method** | Surface approximation, voxel depth + accumulation, or foliage shadow dithering. [Foliage masks and controls](shaderpack/sss/README.md). |
| **Sun highlights** | Soft sun reflections on surfaces and a sheen on leaves. |

### Shadows

| Option | What it does |
|---|---|
| **Shadow softness** | How blurry shadow edges are. |
| **Contact shadows** | Small shadows for grass, plants and props, which Hytale leaves out of its shadow map. |
| **Distant shadows** | Shadows for trees and hills beyond the range of the normal shadows, so the landscape doesn't go flat in the distance. |

### RTX

These only apply with the **RTX** preset.

| Option | What it does |
|---|---|
| **Bounce light** | Sunlight bouncing off surfaces: shade under a tree picks up green from the sunlit grass, a room fills with warm light from a sunlit floor, torch flames light the walls around them. |
| **Bounce rays** | How many rays per pixel the bounce light uses. More is smoother but slower; this is the biggest performance setting in the pack. |
| **Bounce reach** | How far (in blocks) bounced light travels. |
| **Ray-traced AO** | How much those rays also darken enclosed corners and the shade under overhangs. |

### Sky & atmosphere

| Option | What it does |
|---|---|
| **Stars** | **Off**, **Procedural** (sparse generated stars), or **Hytale** (Hytale's own star texture with the milky way, turning across the sky through the night). |
| **Star brightness** | Brightness of the stars. |
| **Star density** | Size of the star field on the sky: lower gives bigger, fewer stars. |
| **Night sky blue** | How deep blue the night sky stays down to the horizon; 1 is a grey-blue. |
| **Rainbows** | A rainbow opposite the sun after rain, in the morning or evening. |
| **Atmospheric fog** | Haze that softens the distance. |
| **Fog density** | How thick that haze is. |

### Clouds

| Option | What it does |
|---|---|
| **Volumetric clouds** | Replaces Hytale's flat cloud layers with 3D clouds that the sun lights from inside. |
| **Cloud amount** | How much of the sky is covered. |
| **Cloud speed** | How fast they drift. |
| **Cloud layers** | One or two cloud layers. |
| **Cloud shadows** | Clouds cast moving shadows on the ground. |

### Light shafts

| Option | What it does |
|---|---|
| **Light shafts** | Volumetric rays of sun and moon light in the air. |
| **Strength** | Overall strength of the rays. |
| **Forest / cave beams** | How much the beams falling through gaps - between leaves, through roofs and cave openings - stand out from the general haze. 0 makes them plain haze. |
| **Beam boost** | Extra brightness for those beams: light through gaps up to a few blocks wide. Wider sunlit areas seen from the shade only get the open-air haze. |
| **Beam edge softness** | Softens the edges of the beams. Without it they show the shadow map's pixels as boxy, stair-stepped edges, most when the beams are far away. 0 gives the old hard edges. |
| **Moonlight haze** | Strength of the moonlit haze at night. |

### Water

| Option | What it does |
|---|---|
| **Shader water** | The pack's water: moving waves, reflections of the sky and the world, depth colour, sun glints. Off gives Hytale's own water. |
| **Refraction** | How much the water surface bends the view of the riverbed. |
| **Shore foam** | Foam along shorelines. |
| **Underwater caustics** | Rippling light patterns on surfaces while you are under water. |
| **Rain puddles** | Reflective puddles on open ground while it rains, drying up after. |
| **Puddle strength** | How many puddles form and how reflective they are. |

### Post-processing

| Option | What it does |
|---|---|
| **Exposure** | Overall image brightness. |
| **Contrast** | Difference between dark and bright. |
| **Saturation** | Colour intensity. |
| **Vibrance** | Boosts dull colours more than already strong ones. |
| **Bloom** | Glow around bright light: the sun, lava, torches. |
| **Bloom strength** | How strong that glow is. |
| **Lens flare** | Camera lens flares from the sun and moon. |
| **Lens flare strength** | How strong the flares are. |
| **Sun glare** | A soft glow around the visible sun. |
| **Vignette** | Slightly darker screen edges. |
| **Temporal anti-aliasing** | Smooths edges and cleans up the fine grain in shadows, light shafts and bounce light by combining frames. Turning it off makes those grainy. |
| **Sharpening** | Sharpens the image (0 is off). |

## Performance

The biggest costs, roughly in order: the **RTX** preset (try fewer **Bounce rays** first),
**Volumetric clouds**, **Light shafts**, and **Shader water** reflections. Non-RTX profiles
use the lighter lighting path; lower quality levels reduce the other costs.

## Build it yourself

On Linux, `./build.sh` builds `build/libaurora.so` (preloaded, what `install.sh` uses) and
`build/libaurora-sdl.so` (the SDL3 proxy of `tools/linux_install.py`) with the system C compiler
(`build-essential`). cairo, for the menu text, is loaded at run time. Shader preparation uses
`python3`, and Pillow (`python3-pil`) when it is installed.

On Windows:

The release includes a prebuilt `opengl32.dll`. If you would rather not run a DLL you did not
build, double-click **`Build From Source.bat`** instead of `Install.bat`: it compiles the DLL
from the C source in `hook/` and installs that. The compiler (Zig) is downloaded once from
ziglang.org and checked against the checksum ziglang.org publishes; no Visual Studio needed.

From PowerShell: `.\build.ps1` builds `build\opengl32.dll`, `.\install.ps1 -Build` builds and
installs.

## How it works

Aurora replaces selected Hytale shaders as the game loads them, using an OpenGL proxy on
Windows, and on Linux a preloaded library (or the SDL3 proxy). The installer extracts the
original shader code from your game; the executable stays untouched.

The shaders use the game's colour, depth, normals and lighting to render the scene. Changes
made through the menu or shader files reload while you play.

## Troubleshooting

- **Linux looks like vanilla:** press Pause once, and restart the launcher if it was open while
  you installed. Then check `shaderpack/hook.log` (in the folder you installed from): "hook
  loaded (preload)" means Aurora is running; a note that HytaleClient changed (the menu then says
  "Game updated: run install.sh again") means the game updated - close it and run
  `bash install.sh` again. No hook.log at all: run `bash install.sh` again and check
  `flatpak override --user --show com.hypixel.HytaleLauncher`.
- **No menu on Linux:** the menu draws its text with cairo; `hook.log` says so if the game's
  runtime has no libcairo. The shaders still work.
- **Looks like vanilla:** press Pause once (the shaders may be toggled off), and check that
  `opengl32.dll` sits next to `HytaleClient.exe`. After a game update, run `Install.bat` again.
- **Something renders wrong after a game update:** a shader that fails to compile falls back to
  the game's own; the compiler log is in `shaderpack/errors/`, and `shaderpack/hook.log` records
  what the hook did. On Linux these are in the folder you installed from.
  Please open an issue with those files.
- **Antivirus warning:** some antivirus tools flag DLLs that load next to a game. Use
  `Build From Source.bat` to build the DLL from the source yourself.

## Known Issues

- **Disable native TAA in Hytale's Graphics settings to avoid shaking and double temporal filtering.**


## Credits and license

Aurora Shaders is a modified pack based on Complementary Shaders by Complementary Development
(https://www.complementary.dev/). It is distributed under the Complementary License Agreement,
included unchanged in [LICENSE.txt](LICENSE.txt).
