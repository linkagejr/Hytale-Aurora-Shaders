#!/usr/bin/env python3
"""Carries what was customised in an earlier Aurora folder into this one, for install.sh when
the game used another folder before: the settings that were changed from what that version
shipped (the others take this version's defaults, so old defaults never undo new ones), custom
profiles (presets/preset-NN.glsl) and custom foliage masks (sss/)."""
import argparse
from pathlib import Path
import re
import shutil

DEFINE = re.compile(r"(#define[ \t]+(AU_\w+)[ \t]+)([-+]?\d+(?:\.\d+)?)(?=\s|$)")
# Windows-only (DLSS, its render scale) or set by the Linux hook (denoiser): never carried.
NEVER = re.compile(r"AU_DLSS\w*|AU_RENDER_SCALE|AU_GI_DENOISER")

# include/AU_Settings.glsl as the Linux packages before 1.4 shipped it (they have no
# presets/default.glsl): NAME=value, or several values where packages differed.
SHIPPED_BEFORE_1_4 = """
    AU_PRESET=2 AU_SUN_MAX_ELEVATION=0.92 AU_SCREEN_BRIGHTNESS=1.00 AU_TWILIGHT_SHIFT=0.10
    AU_SUNSET_SHIFT=0.0 AU_ALBEDO_MULT=0.78 AU_ALBEDO_SATURATION=0.86|0.92 AU_SIDE_SHADOWING=1
    AU_DIRECTIONAL_SHADING=1 AU_BLOCKLIGHT_STRENGTH=1.0 AU_BLOCKLIGHT_RANGE=1.75
    AU_BLOCKLIGHT_HYTALE_HUE=0.65|1.0 AU_EMISSION_STRENGTH=3.00 AU_SSAO_STRENGTH=1.25
    AU_CAVE_LIGHTING=250.0 AU_SUBSURFACE=1 AU_SUBSURFACE_GLOW=0.35 AU_GENERATED_NORMALS=1
    AU_GENERATED_NORMAL_MULT=100.0 AU_GENERATED_NORMAL_RES=128.0 AU_LIGHT_HIGHLIGHT=1
    AU_SHADOW_SAMPLES=24|12 AU_SHADOW_SOFTNESS=1.0 AU_SHADOW_CASCADES=4 AU_PCSS=1|0
    AU_PCSS_SEARCH=9.0 AU_PCSS_SCALE=900.0 AU_CONTACT_SHADOWS=1 AU_CONTACT_SHADOW_LENGTH=1.6
    AU_CONTACT_SHADOW_STEPS=18 AU_CONTACT_SHADOW_DISTANCE=480.0 AU_FAR_SHADOWS=1
    AU_FAR_SHADOW_STEPS=32 AU_NEAR_IGNORE=1.2 AU_STARS=2 AU_STARS_BRIGHTNESS=1.0|2.0
    AU_STARS_SCALE=1.0 AU_NIGHT_SKY_SATURATION=1.8|3.0 AU_ATMOSPHERIC_FOG=1 AU_ATM_FOG_MULT=0.95
    AU_ATM_FOG_DISTANCE=1.0 AU_BORDER_FOG=1 AU_CAVE_ALTITUDE=95.0 AU_RAINBOWS=1
    AU_RAINBOW_DIAMETER=1.0 AU_HYTALE_SKY_TINT=0.15 AU_CLOUDS=1 AU_CLOUD_ALT1=300.0
    AU_CLOUD_ALT2=340.0 AU_CLOUD_LAYERS=2 AU_CLOUD_AMOUNT=1.0 AU_CLOUD_SPEED=1.00
    AU_CLOUD_STEP=14.0|32.0 AU_CLOUD_DISTANCE=2400.0 AU_CLOUD_SHADOWS=1 AU_CLOUD_SHADOW_STRENGTH=1.0
    AU_LIGHTSHAFTS=1 AU_LIGHTSHAFT_SAMPLES=28|12 AU_LIGHTSHAFT_STRENGTH=1.0
    AU_LIGHTSHAFT_DISTANCE=192.0 AU_LIGHTSHAFT_SCENE_AWARE=1.00 AU_LIGHTSHAFT_NOON_I=1.0
    AU_LIGHTSHAFT_SUNSET_I=1.0|0.5 AU_LIGHTSHAFT_NIGHT_I=0.35 AU_LIGHTSHAFT_SCENE_BOOST=1.0
    AU_WATER=1 AU_WATER_FOG_MULT=1.0 AU_WATER_SSR_STEPS=48 AU_WATER_REFRACTION=2.00
    AU_WATER_FOAM=0.5 AU_WATER_CAUSTICS=1 AU_CAUSTICS_STRENGTH=1.4 AU_DEBUG_WATER=0
    AU_RAIN_PUDDLES=1 AU_RAIN_PUDDLE_STRENGTH=1.0 AU_RTX_GI_RAYS=8 AU_RTX_GI_RADIUS=8.0
    AU_RTX_GI_STRENGTH=1.0 AU_RTX_GI_EMISSIVE=1.0 AU_RTX_AO_RADIUS=2.5 AU_RTX_GI_AO=0.55
    AU_RTX_SSR_STEPS=32 AU_RTX_SMOOTHNESS=0.0 AU_TM_EXPOSURE=1.00 AU_TM_CONTRAST=1.05|1.10
    AU_TM_WHITE_PATH=1.00 AU_TM_DARK_DESATURATION=0.25 AU_SATURATION=1.00 AU_VIBRANCE=1.00
    AU_BLOOM=1 AU_BLOOM_STRENGTH=0.12 AU_BLOOM_FOG=1 AU_KEEP_HYTALE_GRADING=0.6 AU_VIGNETTE=1
    AU_LENSFLARE=1 AU_LENSFLARE_I=2.50 AU_SUN_GLARE=1.0 AU_TAA=1 AU_TAA_BLEND=0.93 AU_TAA_CLIP=1.25
    AU_SHARPENING=2 AU_DEBUG_CLASS=0 AU_DEBUG_TAA=0 AU_DEBUG=0 AU_EMISSIVE_MAX=1.6
    AU_EMISSIVE_BLOOM=4.0 AU_ORE_GLOW=1 AU_ORE_GLOW_STRENGTH=2.0 AU_ORE_BLOOM=10.0 AU_ORE_LIGHT=8.0
    AU_ORE_SHINE=1.0 AU_MATERIALS=1 AU_MATERIAL_GLOSS=1.0 AU_RAIN_WETNESS=1.0 AU_ORE_GLOSS=1.0
    AU_CLOTH_TRANSMIT=0.5 AU_MOON_GLOW=1.0 AU_LIGHTSHAFT_HAZE=0.4 AU_GLASS=1 AU_GLASS_TINT=0.7
    AU_GLASS_ABSORB=0.35 AU_GLASS_REFLECT=0.8 AU_PATH_TRACING=1 AU_PT_GI_STRENGTH=1.5 AU_PT_RAYS=3
    AU_PT_REACH=24.0 AU_PT_HISTORY=24.0 AU_PT_SKY_LIGHT=0.8 AU_PT_LIGHTS=0 AU_PT_LIGHT_STRENGTH=1.50
    AU_PT_LIGHT_RANGE=14.0 AU_PT_AMBIENT_BOUNCE=1.0 AU_VOXEL_DEBUG=0 AU_DLSS=0 AU_DLSS_RR=0
    AU_RENDER_SCALE=0 AU_DLSS_PRESET=0 AU_DLSS_JITTER=1 AU_DLSS_JITTER_SX=1 AU_DLSS_JITTER_SY=1
    AU_DLSS_MOTION_SX=1 AU_DLSS_MOTION_SY=1 AU_DLSS_DEBUG=0 AU_DLSS_DEPTH_HW=0
    AU_LIGHTSHAFT_SOFTNESS=1.0 AU_LIGHTSHAFT_BEAM_WIDTH=3.0
"""


def read(path):
    return path.read_text(encoding="utf-8-sig", errors="replace")


def top_level(text):
    """(line index, match) of the #defines outside #if blocks (inside the include guard)."""
    depth = 0
    for index, line in enumerate(text.split("\n")):
        stripped = line.strip()
        if stripped.startswith("#if"):
            depth += 1
        elif stripped.startswith("#endif"):
            depth -= 1
        elif depth <= 1:
            match = DEFINE.match(stripped)
            if match:
                yield index, match


def settings(text):
    values = {}
    for _, match in top_level(text):
        values.setdefault(match[2], match[3])
    return values


def options(path):
    """NAME -> (kind, default) from an options.txt."""
    result = {}
    if path.is_file():
        for line in read(path).splitlines():
            parts = [part.strip() for part in line.split("|")]
            if len(parts) >= 3 and parts[0].startswith("AU_"):
                result[parts[0]] = (parts[2], parts[3] if len(parts) > 3 else "")
    return result


def number(text):
    try:
        return float(text)
    except ValueError:
        return None


def shipped(pack):
    """NAME -> the values the earlier version shipped (a value among them was not changed)."""
    default = pack / "presets" / "default.glsl"
    if not default.is_file():
        return {name: {float(v) for v in values.split("|")}
                for name, values in (item.split("=") for item in SHIPPED_BEFORE_1_4.split())}
    base = {name: {float(value)} for name, value in settings(read(default)).items()}
    # Options newer than the frozen Default profile ship with their options.txt default.
    for name, (_, value) in options(pack / "options.txt").items():
        if name not in base and number(value) is not None:
            base[name] = {float(value)}
    return base


def fit(text, kind, like):
    """The old value as this version's option takes it (None: it does not fit any more)."""
    value = float(text)
    words = kind.split()
    if words and words[0] == "internal":
        return None
    if words and words[0] == "bool" and value not in (0.0, 1.0):
        return None
    if words and words[0] == "range" and len(words) >= 3 and None not in (number(words[1]), number(words[2])):
        if value < float(words[1]):
            text, value = words[1], float(words[1])
        elif value > float(words[2]):
            text, value = words[2], float(words[2])
    if words and words[0] == "enum" and not any(
            number(entry.split(":", 1)[0]) == value for entry in words[1:]):
        return None
    # Same kind of literal as this version's default: integer settings are used in #if.
    if "." in like and "." not in text:
        text += ".0"
    elif "." not in like and "." in text:
        if value != int(value):
            return None
        text = str(int(value))
    return text


def carry_settings(old_pack, new_pack):
    old_file, new_file = old_pack / "include/AU_Settings.glsl", new_pack / "include/AU_Settings.glsl"
    if not old_file.is_file() or not new_file.is_file():
        return [], []
    old, base = settings(read(old_file)), shipped(old_pack)
    kinds = options(new_pack / "options.txt")
    text = read(new_file)
    lines = text.split("\n")
    carried, dropped = {}, []
    for index, match in list(top_level(text)):
        name, default = match[2], match[3]
        if name not in carried:
            value = old.get(name)
            if value is None or NEVER.fullmatch(name) or name not in base or name in dropped:
                continue
            if any(abs(float(value) - shipped_value) <= 1e-6 * max(1.0, abs(shipped_value))
                   for shipped_value in base[name]):
                continue   # not changed in the earlier folder
            new_value = fit(value, kinds.get(name, ("", ""))[0], default)
            if new_value is None:
                dropped.append(name)
                continue
            carried[name] = new_value
        if float(carried[name]) != float(default):
            line = lines[index]
            start = line.index(match[0]) + len(match[1])
            lines[index] = line[:start] + carried[name] + line[start + len(match[3]):]
    if carried:
        pending = new_file.with_suffix(".tmp")
        pending.write_text("\n".join(lines), encoding="utf-8")
        pending.replace(new_file)
    return carried, dropped


def carry_files(old_dir, new_dir, pattern):
    copied = []
    if not old_dir.is_dir() or old_dir.is_symlink():
        return copied
    for source in sorted(old_dir.rglob(pattern)):
        if not source.is_file() or source.is_symlink():
            continue
        target = new_dir / source.relative_to(old_dir)
        if not target.exists():
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
            copied.append(target)
    return copied


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--from", dest="old", type=Path, required=True, help="the earlier shaderpack folder")
    parser.add_argument("--to", dest="new", type=Path, required=True, help="this folder's shaderpack")
    args = parser.parse_args()
    old, new = args.old.resolve(), args.new.resolve()
    if old == new or not (old / "include/AU_Settings.glsl").is_file():
        return
    try:
        carried, dropped = carry_settings(old, new)
        profiles = carry_files(old / "presets", new / "presets", "preset-*.glsl")
        masks = carry_files(old / "sss", new / "sss", "*.png")
    except (OSError, ValueError) as error:
        parser.exit(1, f"Could not carry the settings over from {old}: {error}\n")
    print(f"Settings from {old.parent}: " + (f"kept {len(carried)} you had changed ({', '.join(carried)})"
                                              if carried else "none changed from that version's defaults")
          + (f"; {len(profiles)} custom profile(s)" if profiles else "")
          + (f"; {len(masks)} custom foliage mask(s)" if masks else "") + ".")
    if dropped:
        print("Not carried over (no longer valid in this version): " + ", ".join(dropped))


if __name__ == "__main__":
    main()
