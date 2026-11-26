# Linux Mint Shortcuts

Keyboard shortcut helpers for Cinnamon.

## super_switch.sh: show the panel in fullscreen apps

In a fullscreen window (a game, a video, a browser in F11 mode), pressing Super doesn't bring up the
panel or the menu. `super_switch.sh` checks whether the active window is fullscreen and presses a
different key combination for each case:

| Active window | Keys sent | Meant for |
|---|---|---|
| Fullscreen | `Super+S` | showing the panel / desklets over the fullscreen window |
| Not fullscreen | `Shift+Super+Home` | opening the menu as usual |

### Requirements

```bash
sudo apt install xdotool x11-utils    # xdotool and xprop; X11 session only
```

### Setup

1. Copy the script somewhere permanent and make it executable:
   ```bash
   chmod +x super_switch.sh
   ```
2. In **Keyboard → Shortcuts → Custom Shortcuts**, add a shortcut named "Super Left" with the command
   `/path/to/super_switch.sh` and bind it to the key you want (for example Super).
3. Bind the two key combinations the script sends to what you want them to do:
   - `Super+S`: the action that shows the panel/desklets.
   - `Shift+Super+Home`: the menu applet's hotkey (right-click the menu → *Configure* → keyboard shortcut).

The script only sends keys. If `Super+S` or `Shift+Super+Home` aren't bound to anything, pressing
the shortcut does nothing.
