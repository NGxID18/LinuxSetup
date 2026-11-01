#!/usr/bin/env bash
set -e

echo "==> Installing Intel GPU driver ($PKG)..."
case "$PKG" in
    apt)
        sudo DEBIAN_FRONTEND=noninteractive apt install -y \
            mesa-vulkan-drivers \
            intel-media-va-driver \
            i965-va-driver \
            libgl1-mesa-dri
        ;;

    dnf)
        sudo dnf install -y \
            mesa-dri-drivers \
            mesa-vulkan-drivers \
            intel-media-driver \
            libva-intel-driver
        ;;

    pacman)
        sudo pacman -S --needed --noconfirm \
            mesa \
            vulkan-intel \
            intel-media-driver \
            libva-intel-driver
        ;;
esac
