#!/usr/bin/env bash
# Switch the laptop battery charge mode to protect battery health.
#
#   ./battery_charge_mode.sh                 Show the current mode and limits
#   ./battery_charge_mode.sh custom          Charge only between 50% and 90% (default limits)
#   ./battery_charge_mode.sh custom 60 80    Charge only between 60% and 80%
#   ./battery_charge_mode.sh standard        Charge to 100% (e.g. before a trip)
#   ./battery_charge_mode.sh fast            Fast charging to 100% (Dell default)
#
# Works on laptops whose kernel driver exposes charge_types and/or
# charge_control_*_threshold in /sys/class/power_supply/BAT* (e.g. Dell via
# dell-laptop, ThinkPad, ASUS, and others).

set -e

BAT=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1)
if [ -z "$BAT" ]; then
    echo "❌ No battery found in /sys/class/power_supply."
    exit 1
fi

TYPES="$BAT/charge_types"
START="$BAT/charge_control_start_threshold"
END="$BAT/charge_control_end_threshold"

# Write a value to a sysfs file as root (pkexec shows a GUI password prompt).
write_root() {
    if [ "$(id -u)" -eq 0 ]; then
        echo "$1" > "$2"
    elif command -v pkexec >/dev/null 2>&1 && [ -n "$DISPLAY$WAYLAND_DISPLAY" ]; then
        echo "$1" | pkexec tee "$2" >/dev/null
    else
        echo "$1" | sudo tee "$2" >/dev/null
    fi
}

# Pick a mode name from charge_types (case-insensitive), e.g. "custom" -> "Custom".
mode_name() {
    tr ' ' '\n' < "$TYPES" | tr -d '[]' | grep -ix "$1" | head -1
}

show_status() {
    echo "Battery:    $(basename "$BAT") ($(cat "$BAT/capacity")%, $(cat "$BAT/status"))"
    [ -r "$TYPES" ] && echo "Modes:      $(cat "$TYPES")   (current in [brackets])"
    [ -r "$START" ] && echo "Start at:   below $(cat "$START")%"
    [ -r "$END" ]   && echo "Stop at:    $(cat "$END")%"
    return 0
}

MODE="${1:-status}"

case "${MODE,,}" in
    status)
        show_status
        exit 0
        ;;
    custom)
        LOW="${2:-50}"
        HIGH="${3:-90}"
        if ! [[ "$LOW" =~ ^[0-9]+$ && "$HIGH" =~ ^[0-9]+$ ]] || [ "$LOW" -ge "$HIGH" ] || [ "$HIGH" -gt 100 ]; then
            echo "❌ Limits must be numbers with start < stop <= 100 (got $LOW and $HIGH)."
            exit 1
        fi
        if [ ! -e "$END" ]; then
            echo "❌ This laptop does not support charge limits (no $END)."
            exit 1
        fi
        echo "Setting charge limits: start below $LOW%, stop at $HIGH%..."
        # Order matters: the start limit must always stay below the stop limit.
        if [ -e "$START" ] && [ "$LOW" -ge "$(cat "$END")" ]; then
            write_root "$HIGH" "$END"
            write_root "$LOW" "$START"
        else
            [ -e "$START" ] && write_root "$LOW" "$START"
            write_root "$HIGH" "$END"
        fi
        # Dell (and some others) only apply the limits in "Custom" mode.
        if [ -e "$TYPES" ] && [ -n "$(mode_name custom)" ]; then
            write_root "$(mode_name custom)" "$TYPES"
        fi
        ;;
    standard|fast|adaptive|trickle)
        if [ ! -e "$TYPES" ] || [ -z "$(mode_name "$MODE")" ]; then
            echo "❌ Mode '$MODE' is not supported on this laptop."
            [ -r "$TYPES" ] && echo "   Available: $(cat "$TYPES")"
            exit 1
        fi
        echo "Setting charge mode to $(mode_name "$MODE")..."
        write_root "$(mode_name "$MODE")" "$TYPES"
        ;;
    *)
        sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
        exit 1
        ;;
esac

echo
show_status
echo "✅ Done!"
