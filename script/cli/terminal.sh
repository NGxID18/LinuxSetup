#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing Kitty & JetBrainsMono Nerd Font ($PKG)..."
case "$PKG" in
    apt)
        sudo DEBIAN_FRONTEND=noninteractive apt install -y kitty fontconfig
        ;;
    dnf)
        sudo dnf install -y kitty fontconfig
        ;;
    zypper)
        sudo zypper --non-interactive install -y kitty fontconfig
        ;;
    pacman)
        sudo pacman -S --needed --noconfirm kitty fontconfig ttf-jetbrains-mono-nerd
        ;;
esac

# Ensure JetBrainsMono Nerd Font is installed across all distributions
if ! fc-list 2>/dev/null | grep -i "JetBrainsMono Nerd Font" >/dev/null 2>&1; then
    echo "==> Downloading and installing JetBrainsMono Nerd Font..."
    FONT_DIR="/usr/local/share/fonts/JetBrainsMonoNerd"
    TMP_FONT="$(mktemp /tmp/jetbrainsmono.XXXXXX.tar.xz)"
    sudo mkdir -p "$FONT_DIR"
    curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz" -o "$TMP_FONT"
    sudo tar -xJf "$TMP_FONT" -C "$FONT_DIR"
    rm -f "$TMP_FONT"
    sudo fc-cache -f
fi

mkdir -p "$HOME/.config/kitty"
cp -r "$ROOT_DIR/config/kitty/." "$HOME/.config/kitty/"
