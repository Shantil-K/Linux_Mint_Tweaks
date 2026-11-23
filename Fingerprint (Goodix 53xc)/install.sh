#!/usr/bin/env bash
# Install Dell's Goodix 53xc fingerprint driver (libfprint TOD plugin) on Linux Mint
# and enable fingerprint authentication for login, lock screen and sudo.
# Supported sensors (USB IDs): 27c6:530c, 27c6:533c, 27c6:538c, 27c6:5840
set -euo pipefail

DEB_URL="http://dell.archive.canonical.com/updates/pool/public/libf/libfprint-2-tod1-goodix/libfprint-2-tod1-goodix_0.0.6-0ubuntu1~somerville1_amd64.deb"
SUPPORTED="27c6:530c 27c6:533c 27c6:538c 27c6:5840"

sensor=""
for id in $SUPPORTED; do
    if lsusb -d "$id" >/dev/null 2>&1; then sensor="$id"; break; fi
done
if [ -z "$sensor" ]; then
    echo "No supported Goodix 53xc sensor found. Your fingerprint devices:"
    lsusb | grep -i -E 'fingerprint|goodix|27c6' || echo "  (none)"
    exit 1
fi
echo "Found Goodix sensor $sensor"

echo "Installing fprintd and PAM module..."
sudo apt-get update
sudo apt-get install -y fprintd libpam-fprintd libfprint-2-tod1

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
echo "Downloading Dell Goodix driver..."
curl -fL -o "$tmp/goodix.deb" "$DEB_URL"
sudo apt-get install -y "$tmp/goodix.deb"

sudo udevadm control --reload-rules
sudo udevadm trigger
sudo systemctl restart fprintd 2>/dev/null || true

echo "Enabling fingerprint authentication (password still works as fallback)..."
sudo pam-auth-update --enable fprintd

echo
fprintd-list "$USER" || true
echo
echo "Done. Enroll a finger with:  fprintd-enroll -f right-index-finger"
echo "Test it with:                fprintd-verify"
