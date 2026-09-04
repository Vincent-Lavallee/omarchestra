#!/bin/bash
# Lid-close handler installed by omarchestra (replaces Omarchy's
# omarchy-system-lid-close). Reproduces Omarchy's lock-on-close, but skips the
# lock when the active power source's "When lid is closed" action is "Do
# nothing" (ignore). The clamshell display reconcile always runs so a docked
# close keeps driving the external display.
#
# Omarchy locks via a Hyprland switch binding (switch:on:Lid Switch) that is
# independent of systemd-logind, so the logind drop-in alone can't implement
# "Do nothing". This script is bound in its place and reads the per-source
# actions the Settings app wrote to ~/.local/state/omarchy/settings/power.json.
set -uo pipefail

state="$HOME/.local/state/omarchy/settings/power.json"

battery_action=$(jq -r '.lidBatteryAction // "ignore"' "$state" 2>/dev/null)
ac_action=$(jq -r '.lidAcAction // "ignore"' "$state" 2>/dev/null)
[[ -n "$battery_action" ]] || battery_action="ignore"
[[ -n "$ac_action" ]] || ac_action="ignore"

action="$battery_action"
if omarchy-power-present; then
  action="$ac_action"
fi

# Omarchy locks the moment the lid closes (rather than waiting for
# PrepareForSleep) so the lock stays off the critical path before a suspend.
# "Do nothing" opts out of that lock; the clamshell reconcile still runs so a
# docked close keeps driving the external display.
if [[ "$action" != "ignore" ]] && omarchy-hw-laptop-closed && ! omarchy-hw-external-monitors; then
  omarchy-system-lock >/dev/null 2>&1 || true
fi

omarchy-hyprland-monitor-clamshell
