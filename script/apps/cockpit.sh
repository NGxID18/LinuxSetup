#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing Cockpit and modules ($PKG)..."
case "$PKG" in
    apt)
        sudo DEBIAN_FRONTEND=noninteractive apt install -y \
            cockpit \
            cockpit-podman \
            cockpit-machines \
            cockpit-storaged \
            cockpit-packagekit \
            cockpit-networkmanager \
            udisks2 \
            udisks2-lvm2 \
            udisks2-btrfs \
            pcp \
            packagekit
        ;;

    dnf)
        sudo dnf install -y \
            cockpit \
            cockpit-files \
            cockpit-podman \
            cockpit-machines \
            cockpit-storaged \
            udisks2-btrfs \
            udisks2-lvm2 \
            pcp
        ;;

    pacman)
        sudo pacman -S --needed --noconfirm \
            cockpit \
            cockpit-files \
            cockpit-podman \
            cockpit-machines \
            cockpit-storaged \
            cockpit-packagekit \
            packagekit \
            udisks2 \
            udisks2-btrfs \
            udisks2-lvm2 \
            pcp \
            mdadm \
            nfs-utils \
            inetutils

        paru -S --needed --noconfirm cockpit-pacman
        ;;
esac

if [ ! -d /usr/share/cockpit/btrfs-manager ]; then
    echo "==> Installing Cockpit Btrfs Manager module..."
    sudo mkdir -p /usr/share/cockpit
    sudo git clone --depth 1 https://github.com/NGxID18/btrfs-manager /usr/share/cockpit/btrfs-manager
fi

sudo systemctl enable --now cockpit.socket
