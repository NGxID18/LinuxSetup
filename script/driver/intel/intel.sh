#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing Intel GPU driver ($PKG)..."
case "$PKG" in
    apt)
        sudo DEBIAN_FRONTEND=noninteractive apt install -y \
            mesa-vulkan-drivers \
            i965-va-driver \
            libgl1-mesa-dri
        sudo DEBIAN_FRONTEND=noninteractive apt install -y intel-media-va-driver-non-free \
            || sudo DEBIAN_FRONTEND=noninteractive apt install -y intel-media-va-driver
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
