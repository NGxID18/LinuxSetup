#!/usr/bin/env bash
set -euo pipefail

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
            mesa-vulkan-drivers
        sudo dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld --allowerasing 2>/dev/null \
            || sudo dnf install -y mesa-va-drivers
        sudo dnf swap -y mesa-vdpau-drivers mesa-vdpau-drivers-freeworld --allowerasing 2>/dev/null \
            || sudo dnf install -y mesa-vdpau-drivers
        ;;

    zypper)
        sudo zypper --non-interactive install -y \
            Mesa-dri \
            libvulkan_radeon \
            libva-vdpau-driver \
            xf86-video-amdgpu 2>/dev/null || sudo zypper --non-interactive install -y Mesa-dri libvulkan_radeon
        ;;

    pacman)
        sudo pacman -S --needed --noconfirm \
            mesa \
            vulkan-radeon \
            libva-mesa-driver \
            xf86-video-amdgpu
        ;;
esac
