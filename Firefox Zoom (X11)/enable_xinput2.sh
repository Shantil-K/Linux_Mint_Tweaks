#!/usr/bin/env bash
# Enables MOZ_USE_XINPUT2=1 systemwide for smooth scrolling and pinch-to-zoom in Firefox-based browsers on X11.

set -e

ENV_FILE="/etc/environment"
VAR_NAME="MOZ_USE_XINPUT2"
VAR_LINE="MOZ_USE_XINPUT2=1"

echo "Configuring $VAR_LINE systemwide..."

if grep -q "^${VAR_NAME}=" "$ENV_FILE" 2>/dev/null; then
    echo "$VAR_NAME is already present in $ENV_FILE:"
    grep "^${VAR_NAME}=" "$ENV_FILE"
    echo "Updating value to $VAR_LINE..."
    sudo sed -i "s/^${VAR_NAME}=.*/${VAR_LINE}/" "$ENV_FILE"
else
    echo "Adding $VAR_LINE to $ENV_FILE..."
    echo "$VAR_LINE" | sudo tee -a "$ENV_FILE" >/dev/null
fi

# Also configure in user environment.d for systemd user session
mkdir -p "$HOME/.config/environment.d"
echo "$VAR_LINE" > "$HOME/.config/environment.d/moz_xinput2.conf"

# Also import into currently active systemd user session
if command -v systemctl >/dev/null 2>&1; then
    systemctl --user set-environment "$VAR_LINE" || true
fi

echo "✅ Done! $VAR_LINE has been configured systemwide in $ENV_FILE."
echo "Note: Log out and log back in (or restart your session) for all systemwide desktop launchers to inherit this variable."
