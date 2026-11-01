#!/usr/bin/env bash
set -euo pipefail

case "$PKG" in
    apt)
        echo "==> Configuring APT repositories & updating system..."
        sudo apt update -y
        sudo DEBIAN_FRONTEND=noninteractive apt install -y \
            ca-certificates gnupg curl wget git unzip tar xz-utils flatpak

        if grep -qiE '^ID(_LIKE)?=.*ubuntu' /etc/os-release; then
            sudo DEBIAN_FRONTEND=noninteractive apt install -y software-properties-common
            sudo add-apt-repository -y universe
            sudo add-apt-repository -y multiverse
        else
            if [ -f /etc/apt/sources.list ]; then
                sudo sed -i -E '/^[[:space:]]*deb(-src)?[[:space:]]/ s/\bmain([[:space:]]+(contrib|non-free|non-free-firmware))*\b/main contrib non-free non-free-firmware/g' /etc/apt/sources.list
            fi
            if [ -f /etc/apt/sources.list.d/debian.sources ]; then
                sudo sed -i -E '/^Components:/ s/\bmain([[:space:]]+(contrib|non-free|non-free-firmware))*\b/main contrib non-free non-free-firmware/g' /etc/apt/sources.list.d/debian.sources
            fi
        fi

        sudo apt update -y
        sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y
        ;;

    dnf)
        echo "==> Configuring RPM Fusion & updating system..."
        if [ "$(rpm -E %fedora)" != "%fedora" ]; then
            FEDORA_VER="$(rpm -E %fedora)"
            sudo dnf install -y \
                "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm" \
                "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm"
        elif [ "$(rpm -E %rhel)" != "%rhel" ]; then
            RHEL_VER="$(rpm -E %rhel)"
            sudo dnf install -y epel-release
            sudo dnf config-manager --set-enabled crb 2>/dev/null || true
            sudo dnf install -y --nogpgcheck \
                "https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-${RHEL_VER}.noarch.rpm" \
                "https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-${RHEL_VER}.noarch.rpm"
        fi

        sudo dnf upgrade --refresh -y
        sudo dnf install -y git curl wget unzip tar xz flatpak
        ;;

    pacman)
        echo "==> Updating Arch Linux & installing base-devel..."
        sudo pacman -Syu --noconfirm
        sudo pacman -S --needed --noconfirm base-devel git curl wget unzip tar xz flatpak

        if ! command -v paru >/dev/null 2>&1; then
            echo "==> Building & installing Paru AUR helper (paru-bin)..."
            BUILD_DIR="$(mktemp -d /tmp/paru.XXXXXX)"
            git clone --depth 1 https://aur.archlinux.org/paru-bin.git "$BUILD_DIR"
            (cd "$BUILD_DIR" && makepkg -si --noconfirm)
            rm -rf "$BUILD_DIR"
        fi

        paru -Sua --noconfirm
        ;;
esac

echo "==> Adding Flathub remote..."
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
