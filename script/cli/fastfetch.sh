#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing Fastfetch ($PKG | ${DISTRO:-$PKG})..."
case "$PKG" in
    apt)
        case "${DISTRO:-debian}" in
            ubuntu|debian|*)
                sudo DEBIAN_FRONTEND=noninteractive apt install -y fastfetch
                ;;
        esac
        ;;
    dnf)
        case "${DISTRO:-fedora}" in
            fedora|rhel|*)
                sudo dnf install -y fastfetch
                ;;
        esac
        ;;
    zypper)
        case "${DISTRO:-tumbleweed}" in
            tumbleweed|leap|*)
                sudo zypper --non-interactive --gpg-auto-import-keys install -y fastfetch
                ;;
        esac
        ;;
    pacman)
        case "${DISTRO:-arch}" in
            cachyos|arch|*)
                sudo pacman -S --needed --noconfirm fastfetch
                ;;
        esac
        ;;
esac

mkdir -p "$HOME/.config/fastfetch"
cp "$ROOT_DIR/config/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
