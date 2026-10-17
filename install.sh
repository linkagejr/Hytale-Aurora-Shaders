#!/usr/bin/env bash
# Installs Aurora Shaders into Hytale on Linux without changing any game file:
#   - finds the game (the Flatpak's data folder, a native install, or asks)
#   - pulls the game's own shaders out of HytaleClient (tools/linux_prepare.py)
#   - Hytale Flatpak (com.hypixel.HytaleLauncher): `flatpak override --user` loads the shader
#     library into the game (LD_PRELOAD) and lets it read this folder.
#   - Hytale installed without Flatpak: adds a "Hytale (Aurora Shaders)" launcher that starts it
#     with the shader library.
# Replaces an earlier Aurora install (this method, or the SDL3 proxy of tools/linux_install.py).
#
#   ./install.sh                     install (prebuilt bin/libaurora.so, or builds it)
#   ./install.sh --build             build the library from source first (./build.sh)
#   ./install.sh --uninstall         remove it again (uninstall.sh does the same)
#   ./install.sh --client-dir DIR    the folder that contains HytaleClient
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
APP=com.hypixel.HytaleLauncher
CONFIG=$ROOT/install.config
LIBNAME=libaurora.so
OLD_LIBNAMES=(libaurora_shaders.so)   # earlier Linux packages
DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
FLATPAK_DATA=$HOME/.var/app/$APP
NATIVE_LIB_DIR=$DATA_HOME/aurora-shaders
NATIVE_LAUNCHER=$HOME/.local/bin/hytale-aurora
NATIVE_DESKTOP=$DATA_HOME/applications/hytale-aurora.desktop

client_dir=
build=0
uninstall=0
while [[ $# -gt 0 ]]; do
    case $1 in
        --build) build=1 ;;
        --uninstall) uninstall=1 ;;
        --client-dir) client_dir=${2:-}; shift ;;
        -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

say() { printf '%s\n' "$*"; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------------------
# Finding the game

find_client_bin() {   # $1 = folder; prints the HytaleClient executable in it
    local d=$1 f
    for f in "$d/HytaleClient" "$d"/HytaleClient.*; do
        [[ -f $f && -x $f && $f != *.dll && $f != *.so && $f != *.pdb && $f != *.dbg ]] && { printf '%s\n' "$f"; return 0; }
    done
    return 1
}

is_client_dir() { [[ -n ${1:-} ]] && find_client_bin "$1" >/dev/null; }

find_client() {
    local pid exe d
    for pid in $(pgrep -x HytaleClient 2>/dev/null || true); do
        exe=$(readlink "/proc/$pid/exe" 2>/dev/null || true)
        [[ -n $exe ]] && is_client_dir "$(dirname "$exe")" && { dirname "$exe"; return; }
    done
    if [[ -f $CONFIG ]]; then
        d=$(<"$CONFIG")
        is_client_dir "$d" && { printf '%s\n' "$d"; return; }
    fi
    for d in "$FLATPAK_DATA/data/Hytale/install/release/package/game/latest/Client" \
             "$DATA_HOME/Hytale/install/release/package/game/latest/Client"; do
        is_client_dir "$d" && { printf '%s\n' "$d"; return; }
    done
    # Anywhere under the usual places (another channel, a changed layout): the newest one.
    local found
    found=$(find "$FLATPAK_DATA" "$DATA_HOME/Hytale" -maxdepth 12 -type f -name 'HytaleClient*' -perm -u+x \
                 ! -name '*.dll' ! -name '*.so' -printf '%T@ %h\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
    [[ -n $found ]] && is_client_dir "$found" && { printf '%s\n' "$found"; return; }

    say "Hytale was not found in its usual folders." >&2
    if [[ -t 0 ]]; then
        read -rp "Folder that contains HytaleClient (or Hytale's own folder): " d
    elif command -v zenity >/dev/null; then
        d=$(zenity --file-selection --directory --title="Select your Hytale folder" 2>/dev/null || true)
    fi
    d=${d/#\~/$HOME}
    [[ -n ${d:-} ]] || die "No folder given."
    is_client_dir "$d" && { printf '%s\n' "$d"; return; }
    found=$(find "$d" -type f -name 'HytaleClient*' -perm -u+x ! -name '*.dll' ! -name '*.so' -printf '%T@ %h\n' 2>/dev/null \
                | sort -rn | head -1 | cut -d' ' -f2-)
    [[ -n $found ]] && is_client_dir "$found" || die "HytaleClient not found under $d."
    printf '%s\n' "$found"
}

wait_for_game_closed() {
    while pgrep -x HytaleClient >/dev/null 2>&1; do
        [[ -t 0 ]] || die "Hytale is running. Close the game and run this again."
        read -rp "Hytale is running. Close the game, then press Enter " _
    done
}

have_flatpak_app() {
    command -v flatpak >/dev/null && flatpak info "$APP" >/dev/null 2>&1
}

# The SDL3 proxy that tools/linux_install.py (the other Linux install method) puts in the game
# folder: undone so the two never load together.
remove_sdl_proxy() {
    local client=$1
    [[ -f $client/libSDL3.so ]] && grep -qa AURORA_SDL_PROXY_V1 "$client/libSDL3.so" || return 0
    say "Removing the Aurora SDL3 proxy from the game folder (the other install method)..."
    PYTHONPATH="$ROOT/tools" python3 -c 'import sys; from pathlib import Path; import linux_hook; linux_hook.uninstall(Path(sys.argv[1]))' "$client" \
        || die "Could not restore the game's SDL3 library; run: ./tools/linux_install.py --uninstall (or repair the game in the launcher)"
}

# ---------------------------------------------------------------------------------------
# Flatpak: the user override file holds LD_PRELOAD, AURORA_* and the folder permission.

flatpak_override_file() { printf '%s\n' "$DATA_HOME/flatpak/overrides/$APP"; }

# Current LD_PRELOAD in the user override, without Aurora's libraries.
flatpak_other_preloads() {
    local f; f=$(flatpak_override_file)
    [[ -f $f ]] || return 0
    python3 - "$f" "$LIBNAME" "${OLD_LIBNAMES[@]}" <<'EOF'
import re, sys
text = open(sys.argv[1], encoding='utf-8', errors='replace').read()
libs = sys.argv[2:]
group = None
for line in text.splitlines():
    s = line.strip()
    if s.startswith('['):
        group = s
    elif group == '[Environment]' and s.startswith('LD_PRELOAD='):
        keep = [p for p in re.split(r'[ :]+', s[len('LD_PRELOAD='):]) if p and not any(p.endswith('/' + l) for l in libs)]
        print(':'.join(keep))
EOF
}

# Removes what install added: Aurora's LD_PRELOAD entries, AURORA_* variables, the folder
# permission (for this folder and for the one recorded at install time - an older package).
flatpak_remove_override() {
    local f; f=$(flatpak_override_file)
    [[ -f $f ]] || return 0
    local recorded=
    [[ -f $FLATPAK_DATA/aurora-shaders/installed-from ]] && recorded=$(<"$FLATPAK_DATA/aurora-shaders/installed-from")
    python3 - "$f" "$HOME" "$ROOT" ${recorded:+"$recorded"} -- "$LIBNAME" "${OLD_LIBNAMES[@]}" <<'EOF'
import re, sys
args = sys.argv[1:]
split = args.index('--')
path, home, roots, libs = args[0], args[1], args[2:split], args[split + 1:]
mine = set()
for r in roots:
    forms = [r]
    if r.startswith(home + '/'):
        forms.append('~/' + r[len(home) + 1:])
    for f in forms:
        mine.update([f, f + ':rw', f + ':ro', f + ':create'])
lines = open(path, encoding='utf-8', errors='replace').read().split('\n')
out, group = [], None
for line in lines:
    s = line.strip()
    if s.startswith('['):
        group = s
    elif group == '[Environment]' and s.startswith('AURORA_'):
        continue
    elif group == '[Environment]' and s.startswith('LD_PRELOAD='):
        keep = [p for p in re.split(r'[ :]+', s[len('LD_PRELOAD='):]) if p and not any(p.endswith('/' + l) for l in libs)]
        if not keep:
            continue
        line = 'LD_PRELOAD=' + ':'.join(keep)
    elif group == '[Context]' and s.startswith('filesystems='):
        items = [i for i in s[len('filesystems='):].split(';') if i and i not in mine]
        if not items:
            continue
        line = 'filesystems=' + ';'.join(items) + ';'
    out.append(line)
# Drop groups left without keys.
tidy = []
for i, line in enumerate(out):
    if line.strip().startswith('['):
        rest = []
        for nxt in out[i + 1:]:
            if nxt.strip().startswith('['):
                break
            rest.append(nxt)
        if not any(r.strip() and not r.strip().startswith('#') for r in rest):
            continue
    tidy.append(line)
text = '\n'.join(tidy).strip('\n')
open(path, 'w', encoding='utf-8').write(text + '\n' if text else '')
EOF
}

install_flatpak() {
    local lib=$1 client=$2 exe_name=$3
    local dest=$FLATPAK_DATA/aurora-shaders
    mkdir -p "$dest"
    cp -f "$lib" "$dest/$LIBNAME"
    local old; for old in "${OLD_LIBNAMES[@]}"; do rm -f "$dest/$old"; done
    [[ $dest/$LIBNAME != *[[:space:]:]* ]] || die "Your home folder path contains a space or ':', which LD_PRELOAD cannot handle."
    local preload=$dest/$LIBNAME others
    others=$(flatpak_other_preloads)
    [[ -n $others ]] && preload=$preload:$others
    flatpak_remove_override
    local args=(--user --env=LD_PRELOAD="$preload" --env=AURORA_SHADERPACK="$ROOT/shaderpack" --env=AURORA_PROCESS="$exe_name")
    # The game reads and writes this folder (settings from the in-game menu, the log).
    case $ROOT/ in "$FLATPAK_DATA"/*) ;; *) args+=(--filesystem="$ROOT") ;; esac
    flatpak override "${args[@]}" "$APP"
    printf '%s\n' "$ROOT" > "$dest/installed-from"
    say "Flatpak override set for $APP (see: flatpak override --user --show $APP)"
}

uninstall_flatpak() {
    flatpak_remove_override
    rm -rf "$FLATPAK_DATA/aurora-shaders"
}

# ---------------------------------------------------------------------------------------
# Native (non-Flatpak) launcher: a script and a menu entry that start it with the library.

find_native_launcher() {
    local c
    for c in hytale-launcher HytaleLauncher hytale; do
        command -v "$c" >/dev/null && { command -v "$c"; return; }
    done
    for c in /opt/hytale-launcher-bin/hytale-launcher "$DATA_HOME/hytale-launcher/bin/hytale-launcher"; do
        [[ -x $c ]] && { printf '%s\n' "$c"; return; }
    done
    return 1
}

install_native() {
    local lib=$1 exe_name=$2
    mkdir -p "$NATIVE_LIB_DIR" "$(dirname "$NATIVE_LAUNCHER")" "$(dirname "$NATIVE_DESKTOP")"
    cp -f "$lib" "$NATIVE_LIB_DIR/$LIBNAME"
    local old; for old in "${OLD_LIBNAMES[@]}"; do rm -f "$NATIVE_LIB_DIR/$old"; done
    local launcher; launcher=$(find_native_launcher || true)
    {
        printf '#!/bin/sh\n# Starts Hytale with Aurora Shaders (written by install.sh in %s).\n' "$ROOT"
        printf 'export LD_PRELOAD=%q"${LD_PRELOAD:+:$LD_PRELOAD}"\n' "$NATIVE_LIB_DIR/$LIBNAME"
        printf 'export AURORA_SHADERPACK=%q\n' "$ROOT/shaderpack"
        printf 'export AURORA_PROCESS=%q\n' "$exe_name"
        printf 'exec %q "$@"\n' "${launcher:-hytale-launcher}"
    } > "$NATIVE_LAUNCHER"
    chmod +x "$NATIVE_LAUNCHER"
    cat > "$NATIVE_DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Name=Hytale (Aurora Shaders)
Comment=Hytale with the Aurora shader pack
Exec=$NATIVE_LAUNCHER
Icon=com.hypixel.HytaleLauncher
Terminal=false
Categories=Game;
EOF
    say "Start Hytale with: $NATIVE_LAUNCHER (or \"Hytale (Aurora Shaders)\" in your app menu)."
    [[ -n $launcher ]] || say "Note: no Hytale launcher was found in PATH; edit the last line of $NATIVE_LAUNCHER to point at it."
}

uninstall_native() {
    rm -f "$NATIVE_LAUNCHER" "$NATIVE_DESKTOP"
    rm -rf "$NATIVE_LIB_DIR"
}

# ---------------------------------------------------------------------------------------

command -v python3 >/dev/null || die "python3 is needed (it reads the game's shaders)."

if [[ $uninstall == 1 ]]; then
    wait_for_game_closed
    uninstall_flatpak
    uninstall_native
    say "Aurora Shaders removed. Hytale is back to its own shaders."
    exit 0
fi

is_client_dir "$client_dir" || client_dir=$(find_client)
client_dir=$(cd "$client_dir" && pwd)
exe=$(find_client_bin "$client_dir")
printf '%s\n' "$client_dir" > "$CONFIG"
say "Hytale: $client_dir"
wait_for_game_closed

# The library: built from source on request, else the prebuilt one, else a local build.
prebuilt=$ROOT/bin/$LIBNAME
local_build=$ROOT/build/$LIBNAME
if [[ $build == 1 ]] || [[ ! -f $prebuilt && ! -f $local_build ]]; then
    bash "$ROOT/build.sh"
    lib=$local_build
elif [[ -f $prebuilt ]]; then
    lib=$prebuilt
else
    lib=$local_build
fi

python3 "$ROOT/tools/linux_prepare.py" --exe "$exe"
remove_sdl_proxy "$client_dir"

case $client_dir/ in
    "$FLATPAK_DATA"/*) flatpak=1 ;;
    *) if have_flatpak_app && [[ ! -d $DATA_HOME/Hytale ]]; then flatpak=1; else flatpak=0; fi ;;
esac
if [[ $flatpak == 1 ]]; then
    command -v flatpak >/dev/null || die "Hytale is a Flatpak here, but the flatpak command was not found."
    install_flatpak "$lib" "$client_dir" "$(basename "$exe")"
else
    install_native "$lib" "$(basename "$exe")"
fi

say ''
say 'Aurora Shaders installed. Start Hytale; in game, Home opens the options and Pause'
say 'switches the shaders off and on. Keep this folder: the game loads the pack from here.'
say 'After a Hytale update, run bash install.sh again.'
