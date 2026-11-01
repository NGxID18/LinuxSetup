#!/usr/bin/env bash
set -e

echo "==> Installing Kitty & JetBrainsMono Nerd Font ($PKG)..."
case "$PKG" in
    apt)
        sudo DEBIAN_FRONTEND=noninteractive apt install -y kitty fontconfig xz-utils
        ;;
    dnf)
        sudo dnf install -y kitty fontconfig xz
        ;;
    pacman)
        sudo pacman -S --needed --noconfirm kitty fontconfig ttf-jetbrains-mono-nerd
        ;;
esac

if ! fc-list | grep -qi "JetBrainsMono Nerd Font"; then
    FONT_DIR="/usr/local/share/fonts/JetBrainsMonoNerd"
    sudo mkdir -p "$FONT_DIR"
    curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz" \
        | sudo tar -xJ -C "$FONT_DIR"
    sudo fc-cache -f
fi

mkdir -p "$HOME/.config/kitty"
cp -r "$ROOT_DIR/config/kitty/." "$HOME/.config/kitty/"
