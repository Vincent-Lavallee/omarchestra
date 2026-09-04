#!/bin/bash
# Print the current power state as tab-separated values so omarchestra can
# initialize its dropdowns from the *real* system state instead of hardcoded
# defaults. Fields: lid-battery, lid-ac, idle-action, idle-action-sec, lock-seconds.
#
# Reads systemd-logind's drop-in (lid + sleep) and Omarchy's shell.json
# (idle.lock). Falls back to the logind defaults when the drop-in is absent.
set -uo pipefail

dropin="/etc/systemd/logind.conf.d/90-omarchy-power.conf"
lb="suspend"; la="suspend"; ia="ignore"; isec=""

if [[ -f "$dropin" ]]; then
  lb=$(grep -m1 '^HandleLidSwitch=' "$dropin" | cut -d= -f2-)
  la=$(grep -m1 '^HandleLidSwitchExternalPower=' "$dropin" | cut -d= -f2-)
  ia=$(grep -m1 '^IdleAction=' "$dropin" | cut -d= -f2-)
  isec=$(grep -m1 '^IdleActionSec=' "$dropin" | cut -d= -f2- | grep -o '[0-9]*' | head -1)
fi

[[ -n "$lb" ]] || lb="suspend"
[[ -n "$la" ]] || la="suspend"
[[ -n "$ia" ]] || ia="ignore"

lock=$(jq -r '.idle.lock // empty' "$HOME/.config/omarchy/shell.json" 2>/dev/null)

printf "%s\t%s\t%s\t%s\t%s\n" "$lb" "$la" "$ia" "$isec" "$lock"
