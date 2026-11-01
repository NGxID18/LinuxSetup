#!/usr/bin/env bash
set -e

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

cp "$ROOT_DIR/config/shell/.zshrc" "$HOME/.zshrc"
sudo chsh -s "$(command -v zsh)" "$USER"
