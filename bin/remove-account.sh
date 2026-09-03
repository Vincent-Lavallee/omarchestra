#!/bin/bash
# Remove a login account (and its home directory) from this machine. Runs in a
# floating terminal so sudo can prompt. Called by omarchestra "Accounts".
set -euo pipefail

# Human accounts only: UID >= 1000 (and below the nobody range) with a home.
mapfile -t users < <(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 && $6 ~ /^\/home\// {print $1}')

if [[ ${#users[@]} -eq 0 ]]; then
  echo "No removable user accounts found."
  exit 0
fi

selected="${1:-}"
if [[ -z "$selected" ]]; then
  selected=$(printf '%s\n' "${users[@]}" | gum choose --header "Remove user account")
fi
[[ -n "$selected" ]] || { echo "Cancelled."; exit 0; }

current="$(id -un)"
if [[ "$selected" == "$current" ]]; then
  echo "Refusing to remove your own account ('$current')." >&2
  exit 1
fi

gum confirm "Remove '$selected' and their home directory?" || { echo "Cancelled."; exit 0; }

sudo userdel -r "$selected"
echo "Removed '$selected'."
