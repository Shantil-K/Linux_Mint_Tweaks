# Papirus Folder Color Tweak

Change Papirus folder colors systemwide (e.g. to yellow) using [papirus-folders](https://github.com/PapirusDevelopmentTeam/papirus-folders).

## Prerequisites

If `papirus-folders` is not installed, install it via the official PPA:

```bash
sudo add-apt-repository ppa:papirus/papirus
sudo apt update
sudo apt install papirus-folders
```

## Quick Start (Automated Script)

Run the included script to apply the yellow folder color across all installed Papirus themes (`Papirus`, `Papirus-Dark`, `Papirus-Light`) and reload Nemo:

```bash
./change_folder_color.sh
```

You can also pass any supported color name (e.g., `green`, `bluegrey`, `nordic`):

```bash
./change_folder_color.sh nordic
```

## Manual Usage

### 1. Apply Yellow to Active Theme
```bash
sudo papirus-folders -C yellow
```

### 2. Apply Yellow Systemwide to All Variants
```bash
for theme in Papirus Papirus-Dark Papirus-Light; do
    sudo papirus-folders -C yellow --theme "$theme"
done
```

### 3. Reload File Manager
Restart Nemo to immediately see the changes:
```bash
nemo -q
```
*(Or press `Alt + F2`, enter `r`, and press Enter to restart Cinnamon).*

### 4. Restore Default Color (Blue)
```bash
sudo papirus-folders -D
```

### 5. List Available Colors
```bash
papirus-folders -l
```

---

## Hack the Theme Directories (Permanent Fix for Small Zoom Levels)

If you want to use the smallest zoom level (66% or 33%) in Nemo and insist on colored icons instead of Papirus's default monochrome 16x16 assets:

### Automated Script
Run the helper script (creates a backup automatically):
```bash
./fix_small_zoom_colored_folders.sh
```
*(To restore original monochrome 16x16 icons later, run `./fix_small_zoom_colored_folders.sh --restore`)*

### Manual Steps
1. **(Recommended) Back up original 16x16 places assets:**
   ```bash
   sudo cp -r /usr/share/icons/Papirus/16x16/places /usr/share/icons/Papirus/16x16/places.bak
   ```
2. **Replace 16x16 places assets with colored 32x32 ones:**
   *(adjust path if installed in `~/.local/share/icons/`)*
   ```bash
   sudo cp -r /usr/share/icons/Papirus/32x32/places/* /usr/share/icons/Papirus/16x16/places/
   ```
3. **Refresh icon cache and reload Nemo:**
   ```bash
   sudo gtk-update-icon-cache /usr/share/icons/Papirus/
   nemo -q
   ```

