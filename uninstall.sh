#!/usr/bin/env bash
# Removes Aurora Shaders from Hytale on Linux: the game is back to vanilla.
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/install.sh" --uninstall "$@"
