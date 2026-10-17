# Changelog

## 1.4.3 - Linux package

- Light shafts: soft beam edges instead of boxy, stair-stepped ones (new **Beam edge softness** option), and the beam boost only lifts beams through gaps a few blocks wide, so no wall of haze shows up at the edge of the shade.
- Linux install through a Flatpak override (or a launcher for native installs) with a prebuilt library: no game files changed, no build tools needed. An earlier install is replaced and the settings changed there are kept.
- Linux hook: works next to other preloaded layers (MangoHud, gamemode), compiles on Mesa, runs on glibc 2.34 and newer, loads cairo at run time, and uses the game's own shaders after a game update until install.sh runs again.

## 1.4.3

- Fixed DLSS black screens affecting some RTX GPUs, including Super Resolution and Ray Reconstruction.
- Fixed DLSS frame capture and presentation with flipped texture coordinates or offset viewports.
- Improved shared-image synchronization and resizing; added one-shot DLSS diagnostics.

## 1.4.2

- Added press-to-bind menu hotkeys under General. Bindings save across restarts and stay unchanged by profiles.
- Fixed Linux menu size, clipping and click alignment with display scaling.
- Added Ctrl+mouse editing on Linux, with normal input restored when releasing Ctrl, closing the menu or switching windows.

## 1.4.1

- Fixed native glowing blocks, including Cracked Volcanic Rock, turning black while preserving their coloured light.

## 1.4.0

- Added outdoor sunlight controls: directional sky fill, sun colour balance, highlight protection and improved backlit foliage.
- Added sun-sized soft shadows, angular diameter and contact-shadow strength controls.
- Added texture definition, material roughness detail, specular antialiasing and matte foliage controls.
- Added optional biome/weather fog, sky and cloud colours; Off by default.
- Added custom-profile export and confirmed deletion.
- Fixed moving cloud-shadow bands at dawn and sunset.
- Fixed Sandy Gravel incorrectly glowing and emitting light.
- Enabled Outdoor sunlight from Medium upward in both profile families; moved the TAA warning to the top of General.
- Reduced unnecessary shadow filtering in fully shadowed areas.

## 1.3.0

- Added RTX and Non-RTX quality profiles, from Lowest to Ultra, plus a saved Default profile.
- Coloured area lights now enable only in Ultra quality profiles; manual controls remain available.
- Fixed Non-RTX area-light denoising and reduced Original denoiser grain.
- Improved light-cache turnover and culling so new cave lights load reliably with less overhead.
- Added per-pixel foliage transmission masks and optional shadow dithering.
- Added more quality controls and preserved custom foliage masks during Windows/Linux updates.

## 1.2.0

- RTX is now default; Standard is marked deprecated.
- Added Default, DLSS Preset and Path Tracing profiles, plus named custom presets.
- Restored configurable Original denoising; added DLSS Ray Reconstruction and fixed lighting-history trails.
- Improved DLSS HDR/motion handling, live resolution, Quality+/Quality++ and sharpness; fixed black speckles on bright lights.
- Added texture-coloured emissive lighting, stable bulb/potion colours, shorter light caching and torch-relative ore lighting.
- Added foliage/ice depth-based transmission and reduced lighting overhead.
- Redesigned the menu with tabs, reset controls and a native-TAA warning.
- Improved clean install/update/uninstall and added native x86_64 Linux installation.
- Included experimental Windows Frame Generation; off by default, with in-game validation still pending.
