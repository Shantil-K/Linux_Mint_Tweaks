# Nemo Empty Folder Icon

Papirus' folder icon has a white sheet of paper inside, so in Nemo every folder looks full. This Nemo extension shows **empty folders without the sheet**, like Windows does.

## How it works

- For each local folder Nemo shows, the extension checks whether it's empty (hidden files count as content).
- Empty folders get a custom icon: a copy of your current `folder` icon with the sheet removed, saved in `~/.cache/nemo-empty-folder-icon/`. It follows your Papirus folder colour (e.g. after `papirus-folders -C yellow`).
- As soon as something is added, the custom icon is removed again.
- Folders you've coloured yourself (right-click → folder colour) are left alone.
- Only works with Papirus-style icon themes; with other themes it does nothing.

## Install

Needs `python-nemo` (installed by default on Linux Mint).

```bash
./install.sh
nemo -q   # restart Nemo; closes open Nemo windows
```

## Uninstall

```bash
./install.sh --uninstall              # also cleans up folders under your home
./install.sh --uninstall /media/disk  # or clean up other places
nemo -q
```

## Notes

- Uses the same `metadata::custom-icon` setting as the folder colour menu, which is stored by GVfs in `~/.local/share/gvfs-metadata/`.
- Network and other non-local folders are skipped.
