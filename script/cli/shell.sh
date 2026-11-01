#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing Zsh & plugins ($PKG)..."
case "$PKG" in
    apt)
        sudo DEBIAN_FRONTEND=noninteractive apt install -y \
            zsh \
            zsh-autosuggestions \
            zsh-syntax-highlighting
        ;;
    dnf)
        sudo dnf install -y \
            zsh \
            zsh-autosuggestions \
            zsh-syntax-highlighting
        ;;
    pacman)
        sudo pacman -S --needed --noconfirm \
            zsh \
            zsh-autosuggestions \
            zsh-syntax-highlighting
        ;;
esac

if [ -f "$HOME/.zshrc" ] && ! cmp -s "$ROOT_DIR/config/shell/.zshrc" "$HOME/.zshrc"; then
    cp "$HOME/.zshrc" "$HOME/.zshrc.bak"
fi

cp "$ROOT_DIR/config/shell/.zshrc" "$HOME/.zshrc"

TARGET_USER="${USER:-$(id -un)}"
ZSH_BIN="$(command -v zsh)"
sudo usermod -s "$ZSH_BIN" "$TARGET_USER"
