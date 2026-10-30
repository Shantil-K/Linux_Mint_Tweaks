#!/bin/sh
# Install Windows 10 Theme Tweaks for the current user and add it to the menu.
set -e
cd "$(dirname "$0")"
mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications"
install -m 755 win10-theme-tweaks "$HOME/.local/bin/win10-theme-tweaks"
cat > "$HOME/.local/share/applications/win10-theme-tweaks.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Windows 10 Theme Tweaks
Comment=Apply title bar, green accent and button tweaks to the Windows-10-Dark theme
Exec=$HOME/.local/bin/win10-theme-tweaks
Icon=preferences-desktop-theme
Categories=Settings;DesktopSettings;
Terminal=false
DESKTOP
echo "Installed. Open \"Windows 10 Theme Tweaks\" from the menu."
