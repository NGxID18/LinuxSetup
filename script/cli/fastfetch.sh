#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing Fastfetch ($PKG)..."
case "$PKG" in
    apt)
        sudo DEBIAN_FRONTEND=noninteractive apt install -y fastfetch
        ;;
    dnf)
        sudo dnf install -y fastfetch
        ;;
    zypper)
        sudo zypper --non-interactive install -y fastfetch
        ;;
    pacman)
        sudo pacman -S --needed --noconfirm fastfetch
        ;;
esac

mkdir -p "$HOME/.config/fastfetch"
cp "$ROOT_DIR/config/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
