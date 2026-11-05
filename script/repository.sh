#!/usr/bin/env bash
set -euo pipefail

echo "==> Configuring repositories & prerequisites for Cockpit ($PKG)..."

case "$PKG" in
    apt)
        sudo apt update -y
        if grep -qiE '^ID(_LIKE)?=.*ubuntu' /etc/os-release; then
            if ! command -v add-apt-repository >/dev/null 2>&1; then
                sudo DEBIAN_FRONTEND=noninteractive apt install -y software-properties-common
            fi
            sudo add-apt-repository -y universe
            sudo apt update -y
        fi
        ;;

    dnf)
        # If running on RHEL / Enterprise Linux derivatives
        if [ "$(rpm -E %fedora 2>/dev/null)" = "%fedora" ] && [ "$(rpm -E %rhel 2>/dev/null)" != "%rhel" ]; then
            echo "==> Detected Enterprise Linux. Enabling EPEL repository..."
            sudo dnf install -y epel-release || true
            sudo dnf config-manager --set-enabled crb 2>/dev/null || true
        fi
        ;;

    zypper)
        echo "==> Refreshing openSUSE repositories..."
        sudo zypper --non-interactive refresh
        ;;

    pacman)
        echo "==> Synchronizing Arch Linux repositories..."
        sudo pacman -Sy --noconfirm
        ;;
esac
