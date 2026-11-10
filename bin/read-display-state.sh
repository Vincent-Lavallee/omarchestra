#!/bin/bash
# Print the display state for the Displays section as one JSON object:
#   monitors   — `hyprctl monitors -j` (the focused one carries the scale)
#   fractional — whether in-between scales are unlocked, i.e. whether this
#                app's toggle file (bin/set-display-fractional.sh) exists
set -u

toggle="$HOME/.local/state/omarchy/toggles/hypr/omarchestra-display.lua"
[[ -f $toggle ]] && fractional=true || fractional=false

monitors=$(hyprctl monitors -j 2>/dev/null)
[[ -n $monitors ]] || monitors="[]"

printf '{"fractional":%s,"monitors":%s}\n' "$fractional" "$monitors"
