# Nemo extension: empty folders get a folder icon with no white sheet inside.
#
# Papirus' normal folder icon has a sheet of paper in it, so every folder
# looks full. This makes a copy of the current folder icon without the
# sheet and sets it as the custom icon of empty folders (the same way the
# folder-colour menu sets icons). When something is added, the custom icon
# is removed again. Folders you've given your own icon are left alone.

import hashlib
import os
import re

import gi
gi.require_version("Gtk", "3.0")
gi.require_version("Nemo", "3.0")
from gi.repository import GLib, GObject, Gio, Gtk, Nemo

CUSTOM_ICON = "metadata::custom-icon"
# Remembers which custom icon we set, so we never touch one the user chose.
OURS = "metadata::empty-folder-icon"
CACHE_DIR = os.path.join(GLib.get_user_cache_dir(), "nemo-empty-folder-icon")
# The white sheet inside Papirus folder icons.
SHEET = re.compile(r'<rect style="fill:#e4e4e4"[^>]*/>\s*')


def is_empty(path):
    try:
        with os.scandir(path) as it:
            return next(it, None) is None
    except OSError:
        return None


def refresh(path):
    # Change the folder's ctime (keeping its times) so Nemo redraws its icon.
    try:
        st = os.stat(path)
        os.utime(path, ns=(st.st_atime_ns, st.st_mtime_ns))
    except OSError:
        pass


class EmptyFolderIcon(GObject.GObject, Nemo.InfoProvider, Nemo.NameAndDescProvider):
    def __init__(self):
        self._source = None
        self._uri = None

    def empty_icon_uri(self):
        """file:// URI of the current folder icon without its sheet, or None."""
        info = Gtk.IconTheme.get_default().lookup_icon("folder", 64, 0)
        source = info.get_filename() if info else None
        if source == self._source:
            return self._uri
        self._source, self._uri = source, None
        if not source or not source.endswith(".svg"):
            return None
        try:
            svg = open(source, encoding="utf-8").read()
        except OSError:
            return None
        empty = SHEET.sub("", svg)
        if empty == svg:
            return None  # not a Papirus-style icon
        name = "folder-empty-%s.svg" % hashlib.sha1(svg.encode()).hexdigest()[:12]
        target = os.path.join(CACHE_DIR, name)
        if not os.path.exists(target):
            os.makedirs(CACHE_DIR, exist_ok=True)
            with open(target + ".tmp", "w", encoding="utf-8") as f:
                f.write(empty)
            os.replace(target + ".tmp", target)
        self._uri = GLib.filename_to_uri(target, None)
        return self._uri

    def update_file_info(self, file):
        if file.get_uri_scheme() != "file" or not file.is_directory():
            return
        location = file.get_location()
        path = location.get_path()
        empty = is_empty(path) if path else None
        if empty is None:
            return
        try:
            info = location.query_info(CUSTOM_ICON + "," + OURS, 0, None)
        except GLib.Error:
            return
        custom = info.get_attribute_string(CUSTOM_ICON)
        ours = info.get_attribute_string(OURS)
        if custom and custom != ours:
            return  # the user's own icon

        want = self.empty_icon_uri() if empty else None
        if want == custom:
            return
        try:
            if want:
                location.set_attribute_string(CUSTOM_ICON, want, 0, None)
                location.set_attribute_string(OURS, want, 0, None)
            else:
                location.set_attribute(CUSTOM_ICON, Gio.FileAttributeType.INVALID, 0, 0, None)
                location.set_attribute(OURS, Gio.FileAttributeType.INVALID, 0, 0, None)
        except GLib.Error:
            return
        refresh(path)

    def get_name_and_desc(self):
        return ["Empty Folder Icon:::Show empty folders with a folder icon that has no sheet inside"]
