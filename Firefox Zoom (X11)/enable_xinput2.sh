#!/usr/bin/env bash
# Enables pinch-to-zoom and smooth scrolling in Firefox-based browsers on X11:
#   1. Sets MOZ_USE_XINPUT2=1 systemwide.
#   2. Installs the libinput X driver (if missing) and makes touchpads use it
#      instead of synaptics, which cannot send pinch gestures to apps.

set -e

ENV_FILE="/etc/environment"
VAR_NAME="MOZ_USE_XINPUT2"
VAR_LINE="MOZ_USE_XINPUT2=1"
LIBINPUT_DRV="/usr/lib/xorg/modules/input/libinput_drv.so"
XORG_CONF="/etc/X11/xorg.conf.d/90-touchpad-libinput.conf"

# --- 1. Environment variable -------------------------------------------------
echo "Configuring $VAR_LINE systemwide..."

if grep -q "^${VAR_NAME}=" "$ENV_FILE" 2>/dev/null; then
    echo "$VAR_NAME is already present in $ENV_FILE, setting it to 1..."
    sudo sed -i "s/^${VAR_NAME}=.*/${VAR_LINE}/" "$ENV_FILE"
else
    echo "Adding $VAR_LINE to $ENV_FILE..."
    echo "$VAR_LINE" | sudo tee -a "$ENV_FILE" >/dev/null
fi

# Also configure in user environment.d for systemd user session
mkdir -p "$HOME/.config/environment.d"
echo "$VAR_LINE" > "$HOME/.config/environment.d/moz_xinput2.conf"

if command -v systemctl >/dev/null 2>&1; then
    systemctl --user set-environment "$VAR_LINE" || true
fi

# --- 2. libinput touchpad driver ---------------------------------------------
if [ -f "$LIBINPUT_DRV" ]; then
    echo "libinput X driver already installed."
else
    echo "Installing libinput X driver..."
    sudo apt update
    sudo apt install -y xserver-xorg-input-libinput
fi

echo "Making touchpads use libinput instead of synaptics ($XORG_CONF)..."
sudo mkdir -p /etc/X11/xorg.conf.d
sudo tee "$XORG_CONF" >/dev/null <<'EOF'
# Use libinput (not synaptics) for touchpads so apps get pinch/swipe gestures.
Section "InputClass"
    Identifier "touchpad libinput override"
    MatchIsTouchpad "on"
    MatchDevicePath "/dev/input/event*"
    Driver "libinput"
    Option "Tapping" "on"
EndSection
EOF

echo "✅ Done! Log out and log back in (or reboot) for the changes to take effect."
