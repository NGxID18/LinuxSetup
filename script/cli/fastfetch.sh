#!/usr/bin/env bash
set -e

echo "==> Installing Fastfetch ($PKG)..."
case "$PKG" in
    apt)
        if ! sudo DEBIAN_FRONTEND=noninteractive apt install -y fastfetch 2>/dev/null; then
            ARCH=$(dpkg --print-architecture)
            curl -fsSL "https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-${ARCH}.deb" -o /tmp/fastfetch.deb
            sudo DEBIAN_FRONTEND=noninteractive apt install -y /tmp/fastfetch.deb
            rm -f /tmp/fastfetch.deb
        fi
        ;;
    dnf)
        sudo dnf install -y fastfetch
        ;;
    pacman)
        sudo pacman -S --needed --noconfirm fastfetch
        ;;
esac

mkdir -p "$HOME/.config/fastfetch"
cp "$ROOT_DIR/config/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
