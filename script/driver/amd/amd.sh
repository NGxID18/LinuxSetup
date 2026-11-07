#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing AMD GPU driver ($PKG | ${DISTRO:-$PKG})..."
case "$PKG" in
    apt)
        case "${DISTRO:-debian}" in
            ubuntu|debian|*)
                sudo DEBIAN_FRONTEND=noninteractive apt install -y \
                    mesa-vulkan-drivers \
                    mesa-va-drivers \
                    libgl1-mesa-dri \
                    xserver-xorg-video-amdgpu
                ;;
        esac
        ;;

    dnf)
        sudo dnf install -y \
            mesa-dri-drivers \
            mesa-vulkan-drivers

        case "${DISTRO:-fedora}" in
            fedora)
                sudo dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld --allowerasing 2>/dev/null \
                    || sudo dnf install -y mesa-va-drivers
                sudo dnf swap -y mesa-vdpau-drivers mesa-vdpau-drivers-freeworld --allowerasing 2>/dev/null \
                    || sudo dnf install -y mesa-vdpau-drivers 2>/dev/null || true
                ;;
            rhel|*)
                sudo dnf install -y mesa-va-drivers 2>/dev/null || true
                ;;
        esac
        ;;

    zypper)
        case "${DISTRO:-tumbleweed}" in
            tumbleweed|leap|*)
                sudo zypper --non-interactive --gpg-auto-import-keys install -y \
                    Mesa-dri \
                    Mesa-libva \
                    libvulkan_radeon \
                    xf86-video-amdgpu 2>/dev/null \
                    || sudo zypper --non-interactive --gpg-auto-import-keys install -y \
                        Mesa-dri \
                        libvulkan_radeon
                ;;
        esac
        ;;

    pacman)
        case "${DISTRO:-arch}" in
            cachyos|arch|*)
                sudo pacman -S --needed --noconfirm \
                    mesa \
                    vulkan-radeon \
                    libva-mesa-driver \
                    xf86-video-amdgpu
                ;;
        esac
        ;;
esac
