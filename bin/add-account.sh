#!/bin/bash
# Create a new login account on this machine. Runs in a floating terminal so
# sudo can prompt for a password. Called by the omarchestra "Accounts"
# section.
set -euo pipefail

username="${1:-}"
if [[ -z "$username" ]]; then
  read -rp "Username: " username
fi
[[ -n "$username" ]] || { echo "No username given." >&2; exit 1; }

# Letters, digits, dash, underscore; must not start with a digit.
[[ "$username" =~ ^[a-z_][a-z0-9_-]*$ ]] || { echo "Invalid username '$username'." >&2; exit 1; }

if getent passwd "$username" >/dev/null 2>&1; then
  echo "User '$username' already exists." >&2
  exit 1
fi

sudo useradd -m -G wheel -s /usr/bin/zsh "$username" \
  || { echo "Failed to create user '$username'." >&2; exit 1; }

echo
echo "Set a password for $username:"
sudo passwd "$username"

echo
echo "Account '$username' created — they can now sign in."
