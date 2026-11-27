#!/usr/bin/env python3
"""Export or apply the Helium browser settings worth keeping (no history, logins or cookies).

  helium_prefs.py export <profile dir> <out.json>   pick settings + extension list from a profile
  helium_prefs.py apply  <profile dir> <in.json>    merge them into a profile (Helium must be closed)

The profile dir is ~/.config/net.imput.helium/Default.
"""
import json
import os
import sys

# Dotted paths copied from Preferences. Everything else (history, sessions, site data) is left out.
KEYS = [
    "helium.browser", "helium.settings", "helium.completed_onboarding",
    "browser.show_home_button", "browser.theme", "browser.enable_spellchecking",
    "browser.pin_split_tab_button",
    "bookmark_bar.show_on_all_tabs", "bookmark_bar.show_tab_groups",
    "session.restore_on_startup", "homepage", "homepage_is_newtabpage",
    "side_panel", "toolbar.pinned_actions", "vertical_tabs",
    "extensions.commands", "custom_links", "spellcheck", "intl.selected_languages",
    "search.suggest_enabled",
    "ntp.custom_links_visible", "ntp.shortcust_visible", "ntp.personal_shortcuts_visible",
]


def get(d, path):
    for part in path.split("."):
        if not isinstance(d, dict) or part not in d:
            raise KeyError(path)
        d = d[part]
    return d


def put(d, path, value):
    parts = path.split(".")
    for part in parts[:-1]:
        d = d.setdefault(part, {})
    d[parts[-1]] = value


def extensions(profile):
    found = {}
    ext_dir = os.path.join(profile, "Extensions")
    for ext_id in sorted(os.listdir(ext_dir)) if os.path.isdir(ext_dir) else []:
        versions = sorted(os.listdir(os.path.join(ext_dir, ext_id)))
        try:
            with open(os.path.join(ext_dir, ext_id, versions[-1], "manifest.json")) as f:
                m = json.load(f)
        except (OSError, ValueError, IndexError):
            continue
        name = m.get("name", ext_id)
        if name.startswith("__MSG_"):
            name = m.get("short_name", ext_id)
        found[ext_id] = name
    return found


def main():
    if len(sys.argv) != 4 or sys.argv[1] not in ("export", "apply"):
        sys.exit(__doc__)
    mode, profile, path = sys.argv[1:]
    prefs_file = os.path.join(profile, "Preferences")

    if mode == "export":
        with open(prefs_file) as f:
            prefs = json.load(f)
        home = os.path.expanduser("~")
        settings = {}
        for key in KEYS:
            try:
                settings[key] = get(prefs, key)
            except KeyError:
                pass
        data = {"settings": settings, "extensions": extensions(profile)}
        text = json.dumps(data, indent=2, sort_keys=True).replace(home, "@HOME@")
        with open(path, "w") as f:
            f.write(text + "\n")
        print(f"Exported {len(settings)} settings and {len(data['extensions'])} extensions")
        return

    with open(path) as f:
        data = json.loads(f.read().replace("@HOME@", os.path.expanduser("~")))
    prefs = {}
    if os.path.exists(prefs_file):
        with open(prefs_file) as f:
            prefs = json.load(f)
    for key, value in data["settings"].items():
        put(prefs, key, value)
    os.makedirs(profile, exist_ok=True)
    tmp = prefs_file + ".tmp"
    with open(tmp, "w") as f:
        json.dump(prefs, f)
    os.replace(tmp, prefs_file)
    print(f"Applied {len(data['settings'])} Helium settings")
    for ext_id, name in data["extensions"].items():
        print(f"  {name}: https://chromewebstore.google.com/detail/{ext_id}")


if __name__ == "__main__":
    main()
