#!/usr/bin/env bash
# Hack the Theme Directories (Permanent Fix for Small Zoom Levels)
# Overwrites 16x16 monochrome folder assets with colored 32x32 assets
# so colored folders appear at smallest zoom levels (33% or 66%) in Nemo.

set -e

THEME_DIR="/usr/share/icons/Papirus"

if [ ! -d "$THEME_DIR" ]; then
    if [ -d "$HOME/.local/share/icons/Papirus" ]; then
        THEME_DIR="$HOME/.local/share/icons/Papirus"
    elif [ -d "$HOME/.icons/Papirus" ]; then
        THEME_DIR="$HOME/.icons/Papirus"
    else
        echo "Error: Papirus icon theme directory not found."
        exit 1
    fi
fi

if [ "$1" == "--restore" ]; then
    if [ -d "$THEME_DIR/16x16/places.bak" ]; then
        echo "Restoring original 16x16 places assets..."
        sudo rm -rf "$THEME_DIR/16x16/places"
        sudo cp -r "$THEME_DIR/16x16/places.bak" "$THEME_DIR/16x16/places"
        echo "Updating icon cache..."
        sudo gtk-update-icon-cache "$THEME_DIR/" || true
        if command -v nemo >/dev/null 2>&1; then
            nemo -q || true
        fi
        echo "Restored original 16x16 monochrome icons."
        exit 0
    else
        echo "Error: Backup directory $THEME_DIR/16x16/places.bak not found."
        exit 1
    fi
fi

echo "Target directory: $THEME_DIR"

# 1. Backup if not already backed up
if [ ! -d "$THEME_DIR/16x16/places.bak" ]; then
    echo "Creating backup at $THEME_DIR/16x16/places.bak..."
    sudo cp -r "$THEME_DIR/16x16/places" "$THEME_DIR/16x16/places.bak"
fi

# 2. Overwrite 16x16 with colored 32x32 assets
echo "Replacing 16x16 places assets with colored 32x32 assets..."
sudo cp -r "$THEME_DIR/32x32/places/"* "$THEME_DIR/16x16/places/"

# 3. Refresh icon cache
echo "Updating icon cache..."
sudo gtk-update-icon-cache "$THEME_DIR/" || true

# 4. Restart Nemo
if command -v nemo >/dev/null 2>&1; then
    echo "Restarting Nemo..."
    nemo -q || true
fi

echo "Done! Colored folder icons will now display at 33% and 66% zoom levels."
