#!/usr/bin/env bash
# Optional: starts Hytale (Aurora loads by itself once install.sh has run; the normal launcher
# or desktop shortcut does the same).
set -euo pipefail
if command -v flatpak >/dev/null && flatpak info com.hypixel.HytaleLauncher >/dev/null 2>&1; then
    exec flatpak run com.hypixel.HytaleLauncher "$@"
fi
[[ -x $HOME/.local/bin/hytale-aurora ]] && exec "$HOME/.local/bin/hytale-aurora" "$@"
echo "Run ./install.sh first, then start Hytale normally." >&2
exit 1
