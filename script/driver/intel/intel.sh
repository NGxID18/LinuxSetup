#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing Intel GPU driver ($PKG | ${DISTRO:-$PKG})..."
case "$PKG" in
    apt)
        case "${DISTRO:-debian}" in
            ubuntu|debian|*)
                sudo DEBIAN_FRONTEND=noninteractive apt install -y \
                    mesa-vulkan-drivers \
                    libgl1-mesa-dri
                sudo DEBIAN_FRONTEND=noninteractive apt install -y intel-media-va-driver-non-free 2>/dev/null \
                    || sudo DEBIAN_FRONTEND=noninteractive apt install -y intel-media-va-driver
                sudo DEBIAN_FRONTEND=noninteractive apt install -y i965-va-driver 2>/dev/null || true
                ;;
        esac
        ;;

    dnf)
        sudo dnf install -y \
            mesa-dri-drivers \
            mesa-vulkan-drivers \
            intel-media-driver \
            || sudo dnf install -y mesa-dri-drivers mesa-vulkan-drivers

        case "${DISTRO:-fedora}" in
            fedora|rhel|*)
                sudo dnf install -y libva-intel-driver 2>/dev/null || true
                ;;
        esac
        ;;

    zypper)
        case "${DISTRO:-tumbleweed}" in
            tumbleweed|leap|*)
                sudo zypper --non-interactive --gpg-auto-import-keys install -y \
                    Mesa-dri \
                    libvulkan_intel \
                    intel-media-driver \
                    libva-intel-driver 2>/dev/null \
                    || sudo zypper --non-interactive --gpg-auto-import-keys install -y \
                        Mesa-dri \
                        libvulkan_intel \
                        intel-media-driver 2>/dev/null \
                    || sudo zypper --non-interactive --gpg-auto-import-keys install -y \
                        Mesa-dri \
                        libvulkan_intel
                ;;
        esac
        ;;

    pacman)
        case "${DISTRO:-arch}" in
            cachyos|arch|*)
                sudo pacman -S --needed --noconfirm \
                    mesa \
                    vulkan-intel \
                    intel-media-driver \
                    libva-intel-driver
                ;;
        esac
        ;;
esac
