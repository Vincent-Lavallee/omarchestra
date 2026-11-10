#!/bin/bash
# Set the focused display to exactly SCALE (1–4), for when in-between scales are
# unlocked (bin/set-display-fractional.sh). It is Omarchy's
# omarchy-hyprland-monitor-scaling minus the rounding to a "clean" scale: on a
# panel like 3456x2234 that rounding leaves only 100% and 200%. It saves the
# scale the same way Omarchy does, into monitors.lua, so it survives a reboot.
set -euo pipefail

scale="${1:-}"
if [[ ! $scale =~ ^[0-9]+([.][0-9]+)?$ ]] || ! awk -v s="$scale" 'BEGIN { exit !(s >= 1 && s <= 4) }'; then
  echo "Usage: set-display-scale.sh SCALE   (1 to 4)" >&2
  exit 1
fi
scale=$(awk -v s="$scale" 'BEGIN { printf "%g", s }')
# GTK only honors whole GDK_SCALE values: use the nearest one, as Omarchy does.
gdk_scale=$(awk -v s="$scale" 'BEGIN { printf "%d", int(s + 0.5) }')

info=$(hyprctl monitors -j | jq -e -c '.[] | select(.focused == true)')
name=$(jq -r '.name' <<<"$info")
width=$(jq -r '.width' <<<"$info")
height=$(jq -r '.height' <<<"$info")
refresh=$(jq -r '.refreshRate' <<<"$info")

# The name is written into the Lua that Hyprland evaluates: plain names only.
if [[ ! $name =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "Refusing unsafe monitor name" >&2
  exit 1
fi

out=$(hyprctl eval "hl.monitor({ output = \"$name\", mode = \"${width}x${height}@${refresh}\", position = \"auto\", scale = $scale })" 2>&1)
if [[ $out != ok ]]; then
  echo "$out" >&2
  exit 1
fi

# Persist exactly like omarchy-hyprland-monitor-scaling: only when monitors.lua
# still has Omarchy's catch-all rule, so hand-written per-output rules are kept.
monitor_lua="$HOME/.config/hypr/monitors.lua"
if [[ -f $monitor_lua ]] && grep -q '^local omarchy_monitor_scale = ' "$monitor_lua"; then
  sed -i -E \
    -e "s|^local omarchy_monitor_scale = .*|local omarchy_monitor_scale = ${scale}|" \
    -e "s|^local omarchy_gdk_scale = .*|local omarchy_gdk_scale = ${gdk_scale}|" \
    "$monitor_lua"
elif [[ -f $monitor_lua ]] && grep -Eq '^hl\.monitor\(\{ output = "", mode = "preferred", position = "auto", scale = ("auto"|[0-9.]+) \}\)' "$monitor_lua"; then
  sed -i -E \
    -e "s|^(hl\.monitor\(\{ output = \"\", mode = \"preferred\", position = \"auto\", scale = )([^ ]+)( \}\))|\\1${scale}\\3|" \
    -e 's|^hl\.env\("GDK_SCALE", ".*"\)|hl.env("GDK_SCALE", "'"$gdk_scale"'")|' \
    "$monitor_lua"
fi
