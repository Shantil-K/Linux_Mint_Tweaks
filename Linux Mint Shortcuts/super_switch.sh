#!/bin/bash

# Get active window ID
win=$(xdotool getactivewindow)

# Check if active window is fullscreen
if xprop -id "$win" | grep -q "_NET_WM_STATE_FULLSCREEN"; then
    # Press Super+S = show desklets
    xdotool key Super+s
else
    # Press Right Super = menu
    xdotool key Shift+Super+Home
fi
