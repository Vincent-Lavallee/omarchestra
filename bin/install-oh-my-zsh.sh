#!/bin/bash
# Install Oh My Zsh plus the zsh-autosuggestions (auto-completion) plugin, and
# enable the plugin in ~/.zshrc. Idempotent. Run in a terminal by the
# omarchy-settings "Terminal" section.
set -euo pipefail

echo "Installing Oh My Zsh…"
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  RUNZSH=no KEEP_ZSHRC=yes CHSH=no \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" </dev/null
fi

custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
echo "Installing zsh-autosuggestions (auto-completion)…"
if [[ ! -d "$custom/plugins/zsh-autosuggestions" ]]; then
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
    "$custom/plugins/zsh-autosuggestions"
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
