#!/usr/bin/env python3
"""Filter a `dconf dump /` into only the desktop settings worth carrying to a new install.

Reads the dump on stdin, writes the filtered dump on stdout.
Keeps an allowlist of sections and drops window sizes, history, location and machine IDs.
The home directory is replaced with @HOME@ so the file works for any user name.
"""
import os
import re
import sys

KEEP_SECTIONS = (
    "org/cinnamon", "org/nemo", "org/gtk/settings/file-chooser",
    "org/gnome/desktop/interface", "org/gnome/desktop/wm/preferences",
    "org/gnome/desktop/peripherals", "org/gnome/desktop/sound", "org/gnome/desktop/privacy",
    "org/gnome/desktop/input-sources", "org/gnome/desktop/a11y",
    "org/x/editor/plugins", "org/x/editor/preferences", "org/x/apps/portal",
    "org/x/warpinator/preferences", "org/x/viewer/preferences", "org/x/reader/default",
    "org/gnome/gnome-screenshot", "org/onboard", "com/linuxmint/updates",
)
DROP_SECTIONS = (
    "org/nemo/window-state", "org/x/editor/state", "org/x/editor/plugins/filebrowser",
)
# Keys dropped wherever they appear (regex on the key name).
DROP_KEYS = re.compile(
    r"^(command-history|night-light-last-coordinates|connect-id|geometry|"
    r"window-.*|.*-size|size|state|maximized|history-.*|last-.*|.*-last-run|"
    r"selected-color|custom-colors|sidebar-width|current|installed-apps)$"
)


def keep_section(sec):
    if any(sec == d or sec.startswith(d + "/") for d in DROP_SECTIONS):
        return False
    return any(sec == k or sec.startswith(k + "/") for k in KEEP_SECTIONS)


def main():
    home = os.path.expanduser("~")
    out, sec, body = [], None, []

    def flush():
        if sec is not None and body and keep_section(sec):
            out.append(f"[{sec}]")
            out.extend(body)
            out.append("")

    for line in sys.stdin.read().splitlines():
        m = re.match(r"^\[(.*)\]$", line)
        if m:
            flush()
            sec, body = m.group(1), []
            continue
        if not line.strip() or "=" not in line:
            continue
        key = line.split("=", 1)[0]
        if DROP_KEYS.match(key):
            continue
        body.append(line.replace(home, "@HOME@"))
    flush()
    sys.stdout.write("\n".join(out))


if __name__ == "__main__":
    main()
