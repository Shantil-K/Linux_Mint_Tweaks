# Windows 10 Theme Tweaks

A small app that fixes up the [Windows-10-Dark](https://github.com/B00merang-Project/Windows-10-Dark) GTK theme on Linux Mint Cinnamon and gives it an accent colour of your choice.

The app has three tabs: **Tweaks**, **Accent** and **Preview**.

## Tweaks

Each item is a checkbox:

- **Title bar buttons fill the corners**: 32px title bars, and the close/minimize/maximize hover highlight reaches the window's top and right edges, with sharp (unstretched) icons. This works both for apps that draw their own title bar and for title bars drawn by Cinnamon.
- **Accent colour instead of Windows blue**: selections, sliders, switches, progress bars and links use the colour from the Accent tab.
- **Dark checkboxes, radio buttons and switches**: no white controls. Checkboxes and radio buttons get a dark background, grey border and an accent tick/dot; switches are grey when off; the selection-mode bar uses the accent instead of light grey.
- **Grey buttons**: plain buttons get a lighter grey so they stand out from the window.
- **Flat title bar icon buttons**: no border box around icon buttons like the ⋮ menu in title bars.
- **Accent-coloured main buttons**: main action buttons like "Take Screenshot".
- **Remove dashed focus outline**: no dotted border after clicking a button. You won't see which item has keyboard focus.
- **Use this theme in every app**: sets `GTK_THEME` in `~/.profile` and `~/.config/environment.d/` so apps that switch to the GNOME look in dark mode (like the screenshot app) still use this theme. Takes effect after logging out and back in.
- **Restart Cinnamon after applying**: needed for title bars drawn by Cinnamon (e.g. Terminal, kitty) to update. Open windows stay open.

## Accent

Pick one of Linux Mint's accent colours (Green, Aqua, Blue, Teal, Purple, Pink, Red, Orange, Sand, Grey) or any custom colour, then press **Apply**. Green (`#35A854`) is the default. Your choice and options are saved in `~/.local/share/win10-theme-tweaks/settings.json`.

## Preview

Opens a window with every kind of button and control (buttons, checkboxes, radio buttons, switches, entries, dropdowns, sliders, progress bars, lists, tabs, info bars, the selection-mode bar and the window buttons), drawn with the theme. Linux Mint has three kinds of apps, each styled a little differently, so there's one preview for each:

- **Classic GTK3 apps**: most Mint apps (Files, Settings, Xed)
- **GTK3 + libhandy apps**: e.g. Screenshot
- **GTK4 + libadwaita apps**: newer GNOME apps, e.g. Text Editor. Needs `sudo apt install gir1.2-gtk-4.0 gir1.2-adw-1`.

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

From the command line:

```bash
win10-theme-tweaks --apply                  # saved options and accent
win10-theme-tweaks --apply --accent orange  # a Mint accent by name, or e.g. --accent '#FF7139'
win10-theme-tweaks --apply --no-restart     # don't restart Cinnamon
win10-theme-tweaks --restore                # back to the original theme
win10-theme-tweaks --preview gtk3           # or: handy, gtk4
```

## Notes

- Apps pick up the changes when you reopen them.
- Cinnamon caches the theme for its own title bars, which is why it needs a restart.
