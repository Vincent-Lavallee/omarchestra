#!/bin/bash
# Set the idle lock timeout (seconds) in ~/.config/omarchy/shell.json. Omarchy's
# idle service reads `idle.lock` (seconds since user idle began) and hot-reloads
# shell.json on save — no restart needed. Run as the user (no root).
#
# "never" has no native sentinel in the idle service (an absent idle.lock falls
# back to the 300s default), so we map it to a day: long enough to be "off" in
# practice without overflowing the 32-bit millisecond timer interval.
set -euo pipefail

timeout="${1:-never}"
file="$HOME/.config/omarchy/shell.json"
never_seconds=86400   # 24h — effectively "never" for a lock timeout

[[ "$timeout" == "never" ]] && timeout="$never_seconds"
[[ "$timeout" =~ ^[0-9]+$ ]] || { echo "bad lock timeout: $timeout" >&2; exit 2; }

mkdir -p "$(dirname "$file")"
if [[ -f "$file" ]]; then
  tmp="$(mktemp)"
  jq --argjson v "$timeout" '.idle = (.idle // {}) | .idle.lock = $v' "$file" > "$tmp"
  mv "$tmp" "$file"
else
  printf '{"version":1,"idle":{"lock":%d}}\n' "$timeout" > "$file"
fi
