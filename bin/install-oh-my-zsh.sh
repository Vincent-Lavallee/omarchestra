#!/bin/bash
# Install Oh My Zsh plus the zsh-autosuggestions (auto-completion) plugin, and
# enable the plugin in ~/.zshrc. Idempotent. Run in a terminal by the
# omarchestra "Terminal" section.
#
# Both external sources are pinned to full commit hashes so the install is
# reproducible and passes the Omarchy marketplace automated security baseline
# (which forbids `curl | sh` and unpinned remote git execution).
set -euo pipefail

OH_MY_ZSH_COMMIT="9112b53fa8b5ab556c7c893aa8be8a247ac512a0"
OH_MY_ZSH_INSTALLER_SHA256="5b16896b831243ebd2f409ecd99c3d231385cc706fbc564625057929ebee5e6e"
AUTOSUGGESTIONS_COMMIT="85919cd1ffa7d2d5412f6d3fe437ebdbeeec4fc5"

echo "Installing Oh My Zsh…"
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  installer="$(mktemp)"
  trap 'rm -f "$installer"' EXIT
  curl -fsSL \
    "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/${OH_MY_ZSH_COMMIT}/tools/install.sh" \
    -o "$installer"
  echo "${OH_MY_ZSH_INSTALLER_SHA256}  $installer" | sha256sum -c - >/dev/null
  RUNZSH=no KEEP_ZSHRC=yes CHSH=no bash "$installer" </dev/null
fi

custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
echo "Installing zsh-autosuggestions (auto-completion)…"
if [[ ! -d "$custom/plugins/zsh-autosuggestions" ]]; then
  git clone https://github.com/zsh-users/zsh-autosuggestions \
    "$custom/plugins/zsh-autosuggestions"
  git -C "$custom/plugins/zsh-autosuggestions" checkout "$AUTOSUGGESTIONS_COMMIT"
fi

echo "Enabling the plugin in ~/.zshrc…"
if ! grep -q "zsh-autosuggestions" "$HOME/.zshrc"; then
  if grep -q '^plugins=' "$HOME/.zshrc"; then
    sed -i 's/^plugins=(/plugins=(zsh-autosuggestions /' "$HOME/.zshrc"
  else
    printf '\nplugins=(git zsh-autosuggestions)\n' >> "$HOME/.zshrc"
  fi
fi

echo "Done. Start a new shell (or run: source ~/.zshrc) to activate."
