#!/usr/bin/env python3
"""Prepares the shaderpack from the installed HytaleClient for install.sh (Flatpak override
install): runs tools/prepare_shaders.py, using Pillow when it is installed and the small PNG
reader in tools/pil_fallback otherwise, then notes which game build the shaders came from
(shaderpack/original/source.txt), so the hook falls back to the game's own shaders after a game
update until install.sh runs again."""
import argparse
from pathlib import Path
import sys
import zipfile

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
try:
    import PIL.Image
except ImportError:
    sys.path.insert(0, str(TOOLS / "pil_fallback"))
    import PIL.Image

import prepare_shaders  # noqa: E402


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--exe", type=Path, required=True, help="Installed HytaleClient binary")
    parser.add_argument("--pack", type=Path, default=prepare_shaders.ROOT / "shaderpack")
    parser.add_argument("--assets", type=Path, help="Assets.zip (default: next to Client)")
    args = parser.parse_args()
    exe = args.exe.resolve()
    pack = args.pack.resolve()
    try:
        prepare_shaders.prepare(exe, pack, args.assets)
        info = exe.stat()
        record = pack / "original" / "source.txt"
        record.write_text(f"path {exe}\nsize {info.st_size}\nmtime {int(info.st_mtime)}\n", encoding="utf-8")
    except (OSError, ValueError, KeyError, ImportError, zipfile.BadZipFile) as error:
        parser.exit(1, f"Shader preparation failed: {error}\n")
    if "pil_fallback" in PIL.Image.__file__:
        print("(Pillow is not installed; used the built-in PNG reader for the block textures.)")


if __name__ == "__main__":
    main()
