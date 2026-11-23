#!/usr/bin/env bash
# Make Grub Customizer's custom "Linux Mint" boot entry always boot the newest kernel.
#
# A custom entry copied in Grub Customizer has the kernel version hard-coded, e.g.
#   linux  /boot/vmlinuz-6.14.0-33-generic ...
#   initrd /boot/initrd.img-6.14.0-33-generic
# so kernel updates install but are never booted. This replaces those paths with the
# /boot/vmlinuz and /boot/initrd.img symlinks, which apt moves to the newest kernel.
set -euo pipefail

FILE="${1:-/etc/grub.d/proxifiedScripts/custom}"

if [ ! -f "$FILE" ]; then
    echo "Not found: $FILE (pass the custom entries file as the first argument)"
    exit 1
fi
if ! grep -qE '/boot/(vmlinuz|initrd\.img)-[0-9]' "$FILE"; then
    echo "No hard-coded kernel versions in $FILE. Nothing to do."
    exit 0
fi
for link in /boot/vmlinuz /boot/initrd.img; do
    [ -e "$link" ] || { echo "Missing $link symlink. Aborting."; exit 1; }
done

echo "Newest kernel: $(readlink /boot/vmlinuz)"
echo "Changes to $FILE:"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
sed -E -e 's#/boot/vmlinuz-[^ ]+#/boot/vmlinuz#' \
       -e 's#/boot/initrd\.img-[^ ]+#/boot/initrd.img#' "$FILE" > "$tmp"
diff "$FILE" "$tmp" || true

read -r -p "Apply? [y/N] " ans
[ "$ans" = "y" ] || [ "$ans" = "Y" ] || { echo "Cancelled."; exit 0; }

backup="$FILE.bak-$(date +%Y%m%d-%H%M%S)"
sudo cp -a "$FILE" "$backup"
sudo install -m 755 -o root -g root "$tmp" "$FILE"
sudo update-grub
echo
echo "Done. Backup: $backup"
echo "Reboot, then check with: uname -r"
