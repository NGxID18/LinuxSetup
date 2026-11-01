#!/usr/bin/env bash
set -e

echo "==> Installing AMD GPU driver ($PKG)..."
case "$PKG" in
    apt)
        sudo DEBIAN_FRONTEND=noninteractive apt install -y \
            mesa-vulkan-drivers \
            mesa-va-drivers \
            libgl1-mesa-dri \
            xserver-xorg-video-amdgpu
        ;;

    dnf)
        sudo dnf install -y \
            mesa-dri-drivers \
            mesa-vulkan-drivers \
            mesa-va-drivers \
            mesa-vdpau-drivers
        ;;

    pacman)
        sudo pacman -S --needed --noconfirm \
            mesa \
            vulkan-radeon \
            libva-mesa-driver \
            xf86-video-amdgpu
        ;;
esac
