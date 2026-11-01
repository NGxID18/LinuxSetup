#!/usr/bin/env bash
set -e

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
            cockpit-storaged
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
        sudo chmod 700 /etc/pacman.d/gnupg 2>/dev/null || true
        ;;
esac

if [ ! -d /usr/share/cockpit/btrfs-manager ]; then
    echo "==> Installing Cockpit Btrfs Manager module..."
    sudo mkdir -p /usr/share/cockpit
    sudo git clone https://github.com/NGxID18/btrfs-manager /usr/share/cockpit/btrfs-manager
fi

sudo systemctl enable --now cockpit.socket
