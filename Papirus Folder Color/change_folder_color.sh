#!/usr/bin/env bash
# Script to change Papirus folder color systemwide in Linux Mint
# Requires papirus-folders: https://github.com/PapirusDevelopmentTeam/papirus-folders

set -e

COLOR="${1:-yellow}"

if ! command -v papirus-folders >/dev/null 2>&1; then
    echo "Error: papirus-folders is not installed."
    echo "Install it with:"
    echo "  sudo add-apt-repository ppa:papirus/papirus"
    echo "  sudo apt update && sudo apt install papirus-folders"
    exit 1
fi

echo "Applying '$COLOR' folder color to Papirus icon themes..."

THEMES=()
for theme in Papirus Papirus-Dark Papirus-Light; do
    if [ -d "/usr/share/icons/$theme" ] || [ -d "$HOME/.local/share/icons/$theme" ] || [ -d "$HOME/.icons/$theme" ]; then
        THEMES+=("$theme")
    fi
done

if [ ${#THEMES[@]} -eq 0 ]; then
    echo "Error: No Papirus themes found."
    exit 1
fi

for theme in "${THEMES[@]}"; do
    echo "Updating $theme..."
    sudo papirus-folders -C "$COLOR" --theme "$theme"
done

echo "Restarting Nemo to reload icon cache..."
if command -v nemo >/dev/null 2>&1; then
    nemo -q || true
fi

echo "Done! Folder color changed to '$COLOR'."
