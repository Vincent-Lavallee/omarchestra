#!/bin/bash
# Print the live Hyprland input state as one JSON object, for the Touchpad /
# Mouse controls. Values come straight from `hyprctl getoption` so they reflect
# the real, merged config (Omarchy defaults + the user's input.lua + any toggle
# file) rather than anything this app remembers. Run as the user (no root).
#
# Keys mirror the Lua option paths under `input`: "touchpad.tap_to_click" is
# input.touchpad.tap_to_click, "natural_scroll" is the mouse's input.natural_scroll.
# `hasTouchpad` / `hasMouse` come from udev, because `hyprctl devices` lists a
# touchpad under "mice" and can't tell the two apart.
set -u

# Print one option as a JSON scalar (null if it can't be read).
get() {
  local v
  v=$(hyprctl getoption "input:$1" -j 2>/dev/null | jq -c '
    if has("bool") then .bool
    elif has("float") then .float
    elif has("int") then .int
    else (.str // null) end' 2>/dev/null)
  printf '%s' "${v:-null}"
}

has_touchpad=false
has_mouse=false
for dev in /sys/class/input/event*; do
  [[ -e $dev ]] || continue
  props=$(udevadm info -q property -p "$dev" 2>/dev/null) || continue
  grep -q '^ID_INPUT_TOUCHPAD=1$' <<<"$props" && has_touchpad=true
  grep -q '^ID_INPUT_MOUSE=1$' <<<"$props" && has_mouse=true
done

jq -cn \
  --argjson tap "$(get touchpad:tap_to_click)" \
  --argjson clickfinger "$(get touchpad:clickfinger_behavior)" \
  --argjson tpNatural "$(get touchpad:natural_scroll)" \
  --argjson tpScroll "$(get touchpad:scroll_factor)" \
  --argjson mNatural "$(get natural_scroll)" \
  --argjson mScroll "$(get scroll_factor)" \
  --argjson accel "$(get accel_profile)" \
  --argjson hasTouchpad "$has_touchpad" \
  --argjson hasMouse "$has_mouse" \
  '{
    "touchpad.tap_to_click": $tap,
    "touchpad.clickfinger_behavior": $clickfinger,
    "touchpad.natural_scroll": $tpNatural,
    "touchpad.scroll_factor": $tpScroll,
    "natural_scroll": $mNatural,
    "scroll_factor": $mScroll,
    "accel_profile": (if ($accel // "" | startswith("flat")) then "flat" else "adaptive" end),
    hasTouchpad: $hasTouchpad,
    hasMouse: $hasMouse
  }'
