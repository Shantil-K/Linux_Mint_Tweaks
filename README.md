# Linux Mint Tweaks

Personal repository for Linux Mint customizations, scripts, and tweaks.

## Contents

- [Fix NTFS Partition Nemo Action](#fix-ntfs-partition-nemo-action)
- [Papirus Folder Color](#papirus-folder-color)
- [H.264 Video Playback Codecs](#h264-video-playback-codecs)
- [Package Dependencies Report](#package-dependencies-report)
- [Firefox Touchpad Zoom & Smooth Scrolling (X11)](#firefox-touchpad-zoom--smooth-scrolling-x11)
- [Panel Configurations](Panel/)
- [Text Extractor](Text%20Extractor/)
- [Windows Alternative Programs](Windows%20Alternative%20Programs/)
- [Windows 10 Theme Tweaks](#windows-10-theme-tweaks)

---

# Fix NTFS Partition Nemo Action

This Nemo action allows you to run `ntfsfix` on an NTFS partition directly from the Nemo file manager.

## Installation

1.  Copy the `fix-ntfs.nemo_action` file to `~/.local/share/nemo/actions/`.
2.  Restart Nemo.

## Usage

1.  Open Nemo and navigate to the directory where your NTFS partition is mounted.
2.  Right-click on the directory.
3.  Select "Fix NTFS Partition" from the context menu.

This will execute the `fix_ntfs_gui.sh` script, which in turn runs `ntfsfix` on the selected partition.

---

# Papirus Folder Color

Customize Papirus folder icon colors systemwide (e.g. to yellow) using `papirus-folders`.

See the [Papirus Folder Color guide and script](Papirus%20Folder%20Color/) for full details and automation.

### Quick Command (Set to Yellow)
```bash
for theme in Papirus Papirus-Dark Papirus-Light; do
    sudo papirus-folders -C yellow --theme "$theme"
done
nemo -q
```

### Colored Icons at Smallest Zoom Level (66% or 33%) — Permanent Fix
By default, Papirus falls back to monochrome 16x16 folder assets at small zoom levels. To keep colored folders at 33% and 66% zoom:
```bash
# 1. Replace 16x16 places with colored 32x32 assets
sudo cp -r /usr/share/icons/Papirus/32x32/places/* /usr/share/icons/Papirus/16x16/places/

# 2. Refresh icon cache and Nemo
sudo gtk-update-icon-cache /usr/share/icons/Papirus/
nemo -q
```
*(See [Papirus Folder Color](Papirus%20Folder%20Color/) for the automated script with backup/restore options)*


---

# H.264 Video Playback Codecs

If you want H.264 video playback support (or experience playback issues with MP4/H.264 videos in media players or browsers), run:

```bash
sudo apt update && sudo apt install libavcodec-extra60 ffmpeg
```

See [Media Codecs](Media%20Codecs/) for more info or the helper script.

---

# Package Dependencies Report

Export forward and reverse dependency trees for all manually installed packages on your system.

See [Package Dependencies](Package%20Dependencies/) for prerequisites and the complete script.

### Quick Start
```bash
sudo apt update && sudo apt install -y apt-rdepends
./"Package Dependencies"/export_dependencies.sh
```

---

# Windows 10 Theme Tweaks

A small app that fixes the Windows-10-Dark GTK theme's title bar buttons (so the close button's red highlight fills the corner) and gives the theme an accent colour of your choice (any Mint accent or a custom colour), dark checkboxes, radio buttons and switches, grey buttons, and accent-coloured main buttons. It also has preview windows showing every control for each kind of Mint app (GTK3, libhandy, GTK4/libadwaita).

See [Windows 10 Theme Tweaks](Windows%2010%20Theme%20Tweaks/) for details.

### Quick Start
```bash
cd "Windows 10 Theme Tweaks" && ./install.sh
```

---

# Firefox Touchpad Zoom & Smooth Scrolling (X11)

Enables pinch-to-zoom gestures, smooth kinetic scrolling, and touchscreen gestures in Firefox, Waterfox, and other Gecko browsers on X11 by setting `MOZ_USE_XINPUT2=1` systemwide.

See [Firefox Zoom (X11)](Firefox%20Zoom%20(X11)/) for the helper script and verification instructions.

### Quick Command (Systemwide)
```bash
grep -qxF 'MOZ_USE_XINPUT2=1' /etc/environment || echo 'MOZ_USE_XINPUT2=1' | sudo tee -a /etc/environment
```
*(Log out and log back in for changes to take effect across all application menus and launchers).*


