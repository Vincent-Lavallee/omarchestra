#!/usr/bin/python3
"""Read or change the primary keyboard layout through Omarchy's own code.

Omarchy keeps more than ~/.config/omarchy/keyboard-layouts in step when the
layout changes (the Hyprland reload, the Fcitx input group, rollback on
failure), so this calls its `save_keyboard` instead of writing the file here.
Run as the user (no root).

  keyboard-layout.py get          -> {"selection": ["us:intl"], "catalog": [{"value","label"}, ...]}
  keyboard-layout.py set <layout> -> make <layout> (e.g. "us:intl") the primary layout,
                                     keeping any other layouts already configured
"""
import json
import os
import sys

omarchy = os.environ.get("OMARCHY_PATH") or "/usr/share/omarchy"
sys.path.insert(0, os.path.join(omarchy, "default", "input-methods"))

import typing_setup  # noqa: E402  (path is set up just above)


def describe(value):
  """Human name for a layout outside Omarchy's catalog, from the system XKB list.

  `value` is "layout" or "layout:variant". evdev.lst has `  us   English (US)` rows
  under "! layout" and `  intl   us: English (US, intl., with dead keys)` rows under
  "! variant". Falls back to the raw code if the list is missing or has no match.
  """
  layout, _, variant = value.partition(":")
  section = None
  try:
    with open("/usr/share/X11/xkb/rules/evdev.lst", encoding="utf-8", errors="replace") as f:
      for line in f:
        if line.startswith("!"):
          section = line[1:].strip()
          continue
        parts = line.split(None, 1)
        if len(parts) != 2:
          continue
        code, text = parts[0], parts[1].strip()
        if variant and section == "variant":
          owner, _, name = text.partition(": ")
          if code == variant and owner == layout:
            return name
        elif not variant and section == "layout" and code == layout:
          return text
  except OSError:
    pass
  return value


def main():
  action = sys.argv[1] if len(sys.argv) > 1 else ""
  selection = typing_setup.keyboard_selection()
  catalog = typing_setup.keyboard_catalog()

  if action == "get":
    labels = dict(catalog)
    options = [{"value": v, "label": l} for v, l in labels.items()]
    # A layout set outside Omarchy's catalog (this machine's "us:intl", say)
    # still needs an entry, or the dropdown would show nothing for it.
    for value in selection[:1]:
      if value not in labels:
        options.insert(0, {"value": value, "label": describe(value)})
    print(json.dumps({"selection": selection, "catalog": options}))
    return

  if action == "set" and len(sys.argv) == 3:
    primary = sys.argv[2]
    # Only ever write a layout Omarchy offers (or one already configured), so
    # an odd argument can't end up in the layouts file.
    if primary not in dict(catalog) and primary not in selection:
      raise SystemExit("Unknown keyboard layout: " + primary)
    typing_setup.save_keyboard([primary] + [v for v in selection if v != primary])
    return

  raise SystemExit("usage: keyboard-layout.py get | set <layout>")


if __name__ == "__main__":
  main()
