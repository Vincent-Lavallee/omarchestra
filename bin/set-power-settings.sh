#!/bin/bash
# Write the systemd-logind power drop-in: lid action on battery, lid action on
# AC, and the idle sleep timeout. Run as root (via pkexec) by omarchestra.
# Overrides Omarchy's shipped "ignore lid / never sleep" defaults.
set -euo pipefail

lid_battery="${1:-ignore}"
lid_ac="${2:-ignore}"
sleep_timeout="${3:-never}"   # "never" or a number of minutes

for a in "$lid_battery" "$lid_ac"; do
  case "$a" in ignore|lock|suspend|hibernate|poweroff) ;; *) echo "bad lid action: $a" >&2; exit 2 ;; esac
done
if [[ "$sleep_timeout" != "never" ]] && ! [[ "$sleep_timeout" =~ ^[0-9]+$ ]]; then
  echo "bad sleep timeout: $sleep_timeout" >&2; exit 2
fi

mkdir -p /etc/systemd/logind.conf.d
{
  echo "[Login]"
  echo "HandleLidSwitch=$lid_battery"
  echo "HandleLidSwitchExternalPower=$lid_ac"
  echo "HandleLidSwitchDocked=$lid_battery"
  if [[ "$sleep_timeout" == "never" ]]; then
    echo "IdleAction=ignore"
  else
    echo "IdleAction=suspend"
    echo "IdleActionSec=${sleep_timeout}min"
  fi
} > /etc/systemd/logind.conf.d/90-omarchy-power.conf

# Reload, don't restart: restarting systemd-logind tears down the user session
# (kills the compositor and every app). logind re-reads the drop-in on reload.
systemctl reload systemd-logind >/dev/null 2>&1 || true
