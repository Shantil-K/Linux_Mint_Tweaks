# Windows 10 Theme Tweaks

A small app that fixes up the [Windows-10-Dark](https://github.com/B00merang-Project/Windows-10-Dark) GTK theme on Linux Mint Cinnamon and gives it a Mint green accent.

## What it changes

Each item is a checkbox in the app:

- **Title bar buttons fill the corners**: 32px title bars, and the close/minimize/maximize hover highlight reaches the window's top and right edges. This works both for apps that draw their own title bar and for title bars drawn by Cinnamon.
- **Mint green accent**: replaces Windows blue (`#0078D7`) with Mint green (`#35A854`) in selections, sliders, switches and other widgets.
- **Dark checkboxes with green tick**: dark background, grey border, Mint green tick.
- **Green main buttons**: main action buttons like "Take Screenshot" are Mint green.
- **Flat title bar buttons**: no border box around buttons like the ⋮ menu in title bars.
- **Remove dashed focus outline**: no dotted border after clicking a button. You won't see which item has keyboard focus.
- **Use this theme in every app**: sets `GTK_THEME` in `~/.profile` and `~/.config/environment.d/` so apps that switch to the GNOME look in dark mode (like the screenshot app) still use this theme. Takes effect after logging out and back in.
- **Restart Cinnamon after applying**: needed for title bars drawn by Cinnamon (e.g. Terminal, kitty) to update. Open windows stay open.

## How it works

The first time you press **Apply**, the app saves an untouched copy of the theme in `~/.local/share/win10-theme-tweaks/`. Every Apply restores that copy and then applies the ticked options, so applying again is safe. If the theme is reinstalled or updated, the next Apply saves the new version as the original.

**Restore original** puts the plain theme back and removes the `GTK_THEME` setting.

## Requirements

- Linux Mint (tested on 22.3, Cinnamon 6.6)
- The Windows-10-Dark theme in `~/.themes/Windows-10-Dark`
- `python3-gi` and `python3-pil` (both installed by default on Mint)

## Install

```bash
./install.sh
```

Then open **Windows 10 Theme Tweaks** from the menu.

To apply everything without the window:

```bash
win10-theme-tweaks --apply              # all options
win10-theme-tweaks --apply --no-restart # all options, don't restart Cinnamon
win10-theme-tweaks --restore            # back to the original theme
```

## Notes

- Apps pick up the changes when you reopen them.
- Cinnamon caches the theme for its own title bars, which is why it needs a restart.
