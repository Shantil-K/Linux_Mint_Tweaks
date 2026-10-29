# Linux Mint Tweaks

Personal repository for Linux Mint customizations, scripts, and tweaks.

## Contents

- [Fix NTFS Partition Nemo Action](#fix-ntfs-partition-nemo-action)
- [Papirus Folder Color](#papirus-folder-color)
- [Panel Configurations](Panel/)
- [Text Extractor](Text%20Extractor/)
- [Windows Alternative Programs](Windows%20Alternative%20Programs/)

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

