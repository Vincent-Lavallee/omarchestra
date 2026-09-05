#!/bin/bash
# Install and activate Oh My Zsh plus the zsh-autosuggestions (auto-completion)
# plugin, wiring both into ~/.zshrc. Idempotent. Run in a terminal by the
# omarchestra "Terminal" section.
#
# Both external sources are pinned to full commit hashes and fetched via git
# clone (never `curl | sh` or a downloaded-and-executed installer) so the
# install is reproducible and passes the Omarchy marketplace security baseline.
set -euo pipefail

OH_MY_ZSH_COMMIT="9112b53fa8b5ab556c7c893aa8be8a247ac512a0"
AUTOSUGGESTIONS_COMMIT="85919cd1ffa7d2d5412f6d3fe437ebdbeeec4fc5"

echo "Installing Oh My Zsh…"
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  # Shallow clone then pin to the reviewed commit — the same net effect as the
  # upstream installer (which clones, then skips .zshrc/chsh/launch under
  # KEEP_ZSHRC/CHSH/RUNZSH), but without downloading and executing a remote
  # script.
  git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh "$HOME/.oh-my-zsh"
  git -C "$HOME/.oh-my-zsh" fetch --depth 1 origin "$OH_MY_ZSH_COMMIT"
  git -C "$HOME/.oh-my-zsh" checkout --detach "$OH_MY_ZSH_COMMIT"
fi

custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
echo "Installing zsh-autosuggestions (auto-completion)…"
if [[ ! -d "$custom/plugins/zsh-autosuggestions" ]]; then
  git clone https://github.com/zsh-users/zsh-autosuggestions \
    "$custom/plugins/zsh-autosuggestions"
  git -C "$custom/plugins/zsh-autosuggestions" checkout "$AUTOSUGGESTIONS_COMMIT"
fi

if grep -q 'source .*oh-my-zsh' "$HOME/.zshrc" 2>/dev/null; then
  echo "Oh My Zsh already active — adding the plugin…"
  if ! grep -q "zsh-autosuggestions" "$HOME/.zshrc"; then
    if grep -q '^plugins=' "$HOME/.zshrc"; then
      sed -i 's/^plugins=(/plugins=(zsh-autosuggestions /' "$HOME/.zshrc"
    else
      printf 'plugins=(git zsh-autosuggestions)\n' >> "$HOME/.zshrc"
    fi
  fi
else
  echo "Activating Oh My Zsh in ~/.zshrc…"
  touch "$HOME/.zshrc"
  {
    printf 'export ZSH="$HOME/.oh-my-zsh"\n'
    printf 'ZSH_THEME="robbyrussell"\n'
    printf 'plugins=(git zsh-autosuggestions)\n'
    printf 'source "$ZSH/oh-my-zsh.sh"\n\n'
    cat "$HOME/.zshrc"
  } > "$HOME/.zshrc.omz"
  mv "$HOME/.zshrc.omz" "$HOME/.zshrc"
fi

echo "Done. Start a new shell (or run: source ~/.zshrc) to activate."
