#!/bin/sh
# Install (or with --uninstall, remove) the Nemo empty folder icon extension.
set -e
cd "$(dirname "$0")"
EXT_DIR="$HOME/.local/share/nemo-python/extensions"
EXT="nemo-empty-folder-icon.py"

if [ "$1" = "--uninstall" ]; then
    rm -f "$EXT_DIR/$EXT"
    rm -rf "$HOME/.cache/nemo-empty-folder-icon"
    # Remove the empty-folder icons the extension set (folders under $HOME,
    # or the folders given after --uninstall).
    shift
    python3 - "${@:-$HOME}" <<'PY'
import os, sys
from gi.repository import Gio
n = 0
for top in sys.argv[1:]:
    for root, dirs, _ in os.walk(top):
        for d in dirs + ([] if root != top else ["."]):
            f = Gio.File.new_for_path(os.path.join(root, d))
            try:
                i = f.query_info("metadata::custom-icon,metadata::empty-folder-icon", 0, None)
            except Exception:
                continue
            ours = i.get_attribute_string("metadata::empty-folder-icon")
            if not ours:
                continue
            if i.get_attribute_string("metadata::custom-icon") == ours:
                f.set_attribute("metadata::custom-icon", Gio.FileAttributeType.INVALID, 0, 0, None)
                n += 1
            f.set_attribute("metadata::empty-folder-icon", Gio.FileAttributeType.INVALID, 0, 0, None)
print(f"Removed the empty folder icon from {n} folders.")
PY
    echo "Uninstalled. Restart Nemo (nemo -q) to finish."
    exit 0
fi

if ! dpkg -s python-nemo >/dev/null 2>&1; then
    echo "Needs python-nemo: sudo apt install python-nemo"
    exit 1
fi
mkdir -p "$EXT_DIR"
install -m 644 "$EXT" "$EXT_DIR/$EXT"
echo "Installed. Restart Nemo to use it: nemo -q (this closes open Nemo windows)."
