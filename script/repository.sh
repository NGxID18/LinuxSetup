#!/usr/bin/env bash
set -e

case "$PKG" in
    apt)
        echo "==> Configuring APT repositories & updating system..."
        sudo apt update -y
        sudo DEBIAN_FRONTEND=noninteractive apt install -y \
            software-properties-common ca-certificates gnupg curl wget git unzip flatpak

        if grep -qi ubuntu /etc/os-release; then
            sudo add-apt-repository -y universe
            sudo add-apt-repository -y multiverse
        else
            sudo sed -i 's/main$/main contrib non-free non-free-firmware/g' /etc/apt/sources.list 2>/dev/null || true
            sudo sed -i 's/Components: main$/Components: main contrib non-free non-free-firmware/g' /etc/apt/sources.list.d/debian.sources 2>/dev/null || true
        fi

        sudo apt update -y
        sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y
        ;;

    dnf)
        echo "==> Configuring RPM Fusion & updating system..."
        sudo dnf install -y \
            "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
            "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

        sudo dnf clean all
        sudo dnf upgrade --refresh -y
        sudo dnf install -y git curl wget unzip flatpak
        ;;

    pacman)
        echo "==> Updating Arch Linux & installing base-devel..."
        sudo pacman -Syu --noconfirm
        sudo pacman -S --needed --noconfirm base-devel git curl wget unzip flatpak

        if ! command -v paru >/dev/null 2>&1; then
            echo "==> Building & installing Paru AUR helper..."
            BUILD_DIR=$(mktemp -d /tmp/paru.XXXXXX)
            git clone https://aur.archlinux.org/paru.git "$BUILD_DIR"
            (cd "$BUILD_DIR" && makepkg -si --noconfirm)
            rm -rf "$BUILD_DIR"
        fi

        paru -Sua --noconfirm
        ;;
esac

echo "==> Adding Flathub remote..."
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
