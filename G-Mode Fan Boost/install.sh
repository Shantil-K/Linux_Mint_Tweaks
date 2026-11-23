#!/usr/bin/env bash
# Install G-Mode Fan Boost: the g-fan-boost command, the G key shortcut and the Cinnamon applet.
# Needs a Dell G-series laptop whose kernel exposes alienware_wmi fan boost (kernel 6.15+).
#
#   ./install.sh                 install everything (G key = XF86Launch8)
#   ./install.sh --key F12       bind a different key (any Cinnamon key name)
#   ./install.sh --no-key        skip the keyboard shortcut
#   ./install.sh --no-applet     skip the panel applet
set -euo pipefail
cd "$(dirname "$0")"

KEY="XF86Launch8"; DO_KEY=1; DO_APPLET=1
while [ $# -gt 0 ]; do
    case "$1" in
        --key) KEY="$2"; shift ;;
        --no-key) DO_KEY=0 ;;
        --no-applet) DO_APPLET=0 ;;
        *) echo "Unknown option: $1"; exit 2 ;;
    esac
    shift
done

# 1. Check the hardware interface.
H=""
for n in /sys/class/hwmon/hwmon*/name; do
    [ "$(cat "$n")" = alienware_wmi ] && H=$(dirname "$n")
done
if [ -z "$H" ] || [ ! -e "$H/fan1_boost" ]; then
    echo "No alienware_wmi fan boost found (kernel $(uname -r))."
    echo "This needs a Dell G-series/Alienware laptop and kernel 6.15 or newer."
    exit 1
fi
echo "Found fan boost at $H ($(cat "$H/fan1_label" 2>/dev/null), $(cat "$H/fan2_label" 2>/dev/null))"

# 2. Root command and passwordless rule for that one command.
tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
echo "$USER ALL=(root) NOPASSWD: /usr/local/bin/g-fan-boost" > "$tmp"
sudo visudo -cf "$tmp" >/dev/null
sudo install -m 755 -o root -g root g-fan-boost /usr/local/bin/g-fan-boost
sudo install -m 755 -o root -g root g-key /usr/local/bin/g-key
sudo install -m 440 -o root -g root "$tmp" /etc/sudoers.d/g-fan-boost
sudo visudo -c >/dev/null
echo "Installed /usr/local/bin/g-fan-boost, /usr/local/bin/g-key and /etc/sudoers.d/g-fan-boost"

# 3. Default level list (kept if it already exists).
if [ ! -f "$HOME/.config/g-mode.conf" ]; then
    mkdir -p "$HOME/.config"
    cat > "$HOME/.config/g-mode.conf" <<'CFG'
# G key fan boost levels, cycled in this order on each press.
# Fan speed = Dell's automatic curve + level. 0 = automatic only, 100 = maximum.
# Out-of-range values are clamped to 0-100; entries with no number are skipped.
LEVELS="0 33 66 100"
CFG
    echo "Created ~/.config/g-mode.conf"
fi

# 4. Cinnamon keyboard shortcut in the first free custom slot.
if [ "$DO_KEY" = 1 ] && command -v gsettings >/dev/null; then
    base=org.cinnamon.desktop.keybindings
    path=/org/cinnamon/desktop/keybindings/custom-keybindings
    list=$(gsettings get $base custom-list)
    slot=""
    # Reuse an existing G-Mode shortcut, otherwise take the first unused slot.
    for c in $(echo "$list" | grep -oE "custom[0-9]+"); do
        cmd=$(gsettings get $base.custom-keybinding:$path/$c/ command)
        if [ "$cmd" = "'/usr/local/bin/g-key'" ]; then slot=$c; break; fi
    done
    if [ -z "$slot" ]; then
        for i in $(seq 0 99); do
            echo "$list" | grep -q "'custom$i'" || { slot="custom$i"; break; }
        done
    fi
    gsettings set $base.custom-keybinding:$path/$slot/ name 'G-Mode (fan boost)'
    gsettings set $base.custom-keybinding:$path/$slot/ command '/usr/local/bin/g-key'
    gsettings set $base.custom-keybinding:$path/$slot/ binding "['$KEY']"
    if ! echo "$list" | grep -q "'$slot'"; then
        if ! echo "$list" | grep -q "'"; then
            new="['$slot']"                                   # empty list: [] or @as []
        elif echo "$list" | grep -q "'__dummy__'"; then
            new=$(echo "$list" | sed "s/'__dummy__'/'$slot', '__dummy__'/")
        else
            new="${list%]}, '$slot']"
        fi
        gsettings set $base custom-list "$new"
    fi
    echo "Keyboard shortcut $slot: $KEY runs g-key"
fi

# 5. Panel applet.
if [ "$DO_APPLET" = 1 ] && command -v gsettings >/dev/null; then
    dest="$HOME/.local/share/cinnamon/applets/g-mode@shantil"
    mkdir -p "$dest"
    cp -r applet/g-mode@shantil/. "$dest/"
    enabled=$(gsettings get org.cinnamon enabled-applets)
    if echo "$enabled" | grep -q "g-mode@shantil"; then
        dbus-send --session --dest=org.Cinnamon --type=method_call /org/Cinnamon \
            org.Cinnamon.ReloadXlet string:'g-mode@shantil' string:'APPLET' 2>/dev/null || true
        echo "Applet updated"
    else
        id=$(echo "$enabled" | grep -oE ':[0-9]+'"'" | tr -d ":'" | sort -n | tail -1)
        id=$(( ${id:-0} + 1 ))
        gsettings set org.cinnamon enabled-applets "${enabled%]}, 'panel1:right:0:g-mode@shantil:$id']"
        echo "Applet added to panel 1 (right side). Move it with panel edit mode."
    fi
fi

echo
echo "Done. Press the G key, scroll on the fan icon, or run: g-fan-boost status"
