#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing Fastfetch ($PKG)..."
case "$PKG" in
    apt)
        if ! sudo DEBIAN_FRONTEND=noninteractive apt install -y fastfetch 2>/dev/null; then
            ARCH="$(dpkg --print-architecture)"
            [ "$ARCH" = "arm64" ] && ARCH="aarch64"
            TMP_DEB="$(mktemp /tmp/fastfetch.XXXXXX.deb)"
            curl -fsSL "https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-${ARCH}.deb" -o "$TMP_DEB"
            sudo DEBIAN_FRONTEND=noninteractive apt install -y "$TMP_DEB"
            rm -f "$TMP_DEB"
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
