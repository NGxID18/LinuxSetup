#!/usr/bin/env bash
set -euo pipefail

echo "==> Configuring repositories & prerequisites for Cockpit ($PKG)..."

case "$PKG" in
    apt)
        sudo apt update -y
        sudo DEBIAN_FRONTEND=noninteractive apt install -y \
            ca-certificates gnupg curl wget git

        if grep -qiE '^ID(_LIKE)?=.*ubuntu' /etc/os-release; then
            if ! command -v add-apt-repository >/dev/null 2>&1; then
                sudo DEBIAN_FRONTEND=noninteractive apt install -y software-properties-common
            fi
            sudo add-apt-repository -y universe
            sudo apt update -y
        fi
        ;;

    dnf)
        sudo dnf install -y git curl wget

        # If running on RHEL / Enterprise Linux derivatives
        if [ "$(rpm -E %fedora 2>/dev/null)" = "%fedora" ] && [ "$(rpm -E %rhel 2>/dev/null)" != "%rhel" ]; then
            echo "==> Detected Enterprise Linux. Enabling EPEL repository..."
            sudo dnf install -y epel-release || true
            sudo dnf config-manager --set-enabled crb 2>/dev/null || true
        fi
        ;;

    pacman)
        sudo pacman -Sy --needed --noconfirm base-devel git curl wget

        if ! command -v paru >/dev/null 2>&1 && ! command -v yay >/dev/null 2>&1; then
            echo "==> Installing Paru (AUR helper) for Cockpit AUR modules..."
            BUILD_DIR="$(mktemp -d /tmp/paru.XXXXXX)"
            git clone --depth 1 https://aur.archlinux.org/paru-bin.git "$BUILD_DIR"
            (cd "$BUILD_DIR" && makepkg -si --noconfirm)
            rm -rf "$BUILD_DIR"
        fi
        ;;
esac
