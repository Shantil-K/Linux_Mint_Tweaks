#!/usr/bin/env bash
# Run on the OLD system before reinstalling. Two outputs:
#
#  1. config/ in this folder: desktop settings, applet configs, kitty, zsh, Helium settings, /etc tweaks.
#     Nothing secret. Review with `git diff`, then commit and push.
#  2. A PRIVATE archive (default ~/mint-private-backup-<date>.tar): SSH and GPG keys, Helium profile
#     (logins, passwords, bookmarks), keyrings, Wi-Fi passwords, tokens, themes, fonts.
#     Never commit it. Copy it to a USB drive or a Windows partition before you wipe Linux.
#
#   ./backup.sh                  both
#   ./backup.sh --config-only    only refresh config/
#   ./backup.sh --encrypt        encrypt the private archive with a passphrase (gpg)
#   ./backup.sh --out <file>     where to write the private archive
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
CFG="$DIR/config"
DO_PRIVATE=1; ENCRYPT=0; OUT="$HOME/mint-private-backup-$(date +%F).tar"
while [ $# -gt 0 ]; do
    case "$1" in
        --config-only) DO_PRIVATE=0 ;;
        --encrypt) ENCRYPT=1 ;;
        --out) OUT="$2"; shift ;;
        *) echo "Unknown option: $1"; exit 2 ;;
    esac
    shift
done

say() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }

# Copy a file under $HOME into config/home, replacing the home path with @HOME@.
put_home() {
    local rel="$1" src="$HOME/$1" dst="$CFG/home/$1"
    [ -e "$src" ] || return 0
    mkdir -p "$(dirname "$dst")"
    if grep -Iq . "$src" 2>/dev/null; then
        sed "s|$HOME|@HOME@|g" "$src" > "$dst"
    else
        cp "$src" "$dst"
    fi
}

# ---------------------------------------------------------------- 1. public config
say "Exporting settings to $CFG"
rm -rf "$CFG/home" "$CFG/system" "$CFG/etc" "$CFG/dconf.ini" "$CFG/helium.json"
mkdir -p "$CFG/home" "$CFG/system"

# Desktop settings (Cinnamon, Nemo, keyboard shortcuts, panels, theme...).
dconf dump / | python3 -I "$DIR/lib/dconf_filter.py" > "$CFG/dconf.ini"

# Applet and desklet settings (the instance IDs match enabled-applets in dconf.ini).
find "$HOME/.config/cinnamon/spices" -name '*.json' -printf '%P\n' | while read -r f; do
    put_home ".config/cinnamon/spices/$f"
done

for f in \
    .zshrc .zshenv .p10k.zsh .xsessionrc \
    .config/kitty/kitty.conf \
    .config/copyq/copyq.conf .config/copyq/copyq-commands.ini \
    .config/touchegg/touchegg.conf \
    .config/taskscope/settings.json \
    .config/mimeapps.list \
    .config/gtk-3.0/bookmarks \
    .config/g-mode.conf \
    .config/cinnamon-monitors.xml \
    .config/hdmi-res/position .config/hdmi-res/scale
do put_home "$f"; done
for d in .config/environment.d .config/autostart .local/share/nemo/actions .config/copyq/themes; do
    [ -d "$HOME/$d" ] || continue
    find "$HOME/$d" -maxdepth 1 -type f ! -name '*.bak*' ! -name '*~' -printf '%P\n' | while read -r f; do
        put_home "$d/$f"
    done
done

# Helium: chosen settings and the extension list (no history, logins or cookies).
if [ -f "$HOME/.config/net.imput.helium/Default/Preferences" ]; then
    python3 -I "$DIR/lib/helium_prefs.py" export "$HOME/.config/net.imput.helium/Default" "$CFG/helium.json"
fi

# System tweaks (copied as they are; restore.sh puts them back with root).
put_etc() { [ -r "$1" ] || return 0; mkdir -p "$CFG/system$(dirname "$1")"; cp "$1" "$CFG/system$1"; }
for f in \
    /etc/profile.d/use-xinput2.sh \
    /etc/X11/xorg.conf.d/90-touchpad-libinput.conf \
    /etc/modprobe.d/nvidia-graphics-drivers-kms.conf \
    /etc/modprobe.d/disable-algif_aead.conf \
    /etc/systemd/logind.conf.d/99-no-sleep.conf \
    /etc/systemd/system/disable-turbo.service \
    /etc/sysctl.d/99-sysctl.conf \
    /etc/default/zramswap
do put_etc "$f"; done
# Only the lines added to /etc/environment (not PATH).
grep -vE '^\s*(#|$|PATH=)' /etc/environment > "$CFG/system/environment.add" || true
# GRUB settings that matter, as a drop-in.
{
    echo "# Restored by Clean Install/restore.sh from the old /etc/default/grub."
    grep -E '^GRUB_(TIMEOUT_STYLE|TIMEOUT|CMDLINE_LINUX_DEFAULT|SAVEDEFAULT)=' /etc/default/grub || true
    t=$(sed -n 's/^GRUB_THEME=//p' /etc/default/grub | tr -d '"')
    [ -n "$t" ] && echo "#THEME_DIR=$(basename "$(dirname "$t")")"
} > "$CFG/system/grub-defaults.cfg"

say "Config exported. Review it: git -C \"$DIR\" diff --stat"

[ "$DO_PRIVATE" = 1 ] || exit 0

# ---------------------------------------------------------------- 2. private archive
say "Building the private archive (secrets, never commit this)"
STAGE=$(mktemp -d); trap 'rm -rf "$STAGE"' EXIT
LIST="$STAGE/home-files.txt"
: > "$LIST"
add() { for p in "$@"; do [ -e "$HOME/$p" ] && echo "$p" >> "$LIST"; done; return 0; }

add .ssh .gnupg .gitconfig .git-credentials .npmrc .config/gh .config/rclone .cloudflared duckdns
add .local/share/keyrings                       # saved passwords; same login password needed
add KeePassXC .config/keepassxc
add .themes .icons .local/share/fonts .local/share/icons
add .local/share/cinnamon                       # applet/desklet code incl. third-party ones
add .local/share/applications                   # custom launchers and web apps
add .config/copyq .config/remmina .local/share/remmina .config/kdeconnect
add .local/share/nemo-python
add .face Pictures/Wallpapers Pictures/Logos
# Helium profile without caches (bookmarks, passwords, cookies, extensions and their data).
add .config/net.imput.helium

tar -C "$HOME" -czf "$STAGE/home.tar.gz" \
    --exclude='net.imput.helium/*/Cache' --exclude='net.imput.helium/*/Code Cache' \
    --exclude='net.imput.helium/*/GPUCache' --exclude='net.imput.helium/*/Service Worker/CacheStorage' \
    --exclude='net.imput.helium/*/DawnGraphiteCache' --exclude='net.imput.helium/*/DawnWebGPUCache' \
    --exclude='net.imput.helium/component_crx_cache' --exclude='net.imput.helium/extensions_crx_cache' \
    --exclude='net.imput.helium/BrowserMetrics*' --exclude='net.imput.helium/Crash Reports' \
    --exclude='net.imput.helium/GPUPersistentCache' --exclude='net.imput.helium/Singleton*' \
    --exclude='copyq.lock' --exclude='.copyq_s' --exclude='.themes/*backup*.tar.gz' \
    -T "$LIST"

# Root-only files: one pkexec prompt.
say "Copying root-only files (Wi-Fi passwords, service tokens, GRUB theme) - authorise with pkexec"
theme_dir=$(sed -n 's/^GRUB_THEME=//p' /etc/default/grub | tr -d '"'); theme_dir=${theme_dir%/*}
pkexec /bin/sh -c '
    out="$1"; user="$2"; shift 2
    list=""
    for p in "$@"; do [ -e "$p" ] && list="$list ${p#/}"; done
    # Wi-Fi networks as NetworkManager keyfiles. Mint 22 makes them from netplan (in /run), LMDE keeps
    # them in /etc; keyfiles work on both.
    wifi=$(mktemp -d); mkdir -p "$wifi/etc/NetworkManager/system-connections"
    for f in /etc/NetworkManager/system-connections/*.nmconnection /run/NetworkManager/system-connections/*.nmconnection; do
        [ -f "$f" ] && grep -q "^type=wifi" "$f" && cp "$f" "$wifi/etc/NetworkManager/system-connections/"
    done
    tar -czf "$out" -C / $list -C "$wifi" etc/NetworkManager
    rm -rf "$wifi"
    chown "$user" "$out"
' sh "$STAGE/system.tar.gz" "$USER" \
    /etc/systemd/system/cloudflared.service \
    /var/lib/tailscale \
    /etc/ssh/ssh_host_ecdsa_key /etc/ssh/ssh_host_ecdsa_key.pub \
    /etc/ssh/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key.pub \
    /etc/ssh/ssh_host_rsa_key /etc/ssh/ssh_host_rsa_key.pub \
    ${theme_dir:+"$theme_dir"}

crontab -l > "$STAGE/crontab.txt" 2>/dev/null || true
{
    echo "Private backup from $(hostname), $(date)"
    . /etc/os-release; echo "System: $PRETTY_NAME, kernel $(uname -r)"
    echo; echo "Home files:"; sed 's/^/  ~\//' "$LIST"
} > "$STAGE/MANIFEST.txt"

rm -f "$OUT"
tar -C "$STAGE" -cf "$OUT" MANIFEST.txt home.tar.gz system.tar.gz crontab.txt
chmod 600 "$OUT"
if [ "$ENCRYPT" = 1 ]; then
    gpg --symmetric --cipher-algo AES256 -o "$OUT.gpg" "$OUT" && rm -f "$OUT" && OUT="$OUT.gpg"
fi
say "Private archive: $OUT ($(du -h "$OUT" | cut -f1))"
echo "    Copy it OFF the Linux partition (USB drive, or a Windows partition) before reinstalling."
