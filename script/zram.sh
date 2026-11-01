#!/usr/bin/env bash
set -e

echo "==> Installing zRAM ($PKG)..."
case "$PKG" in
    apt)    sudo DEBIAN_FRONTEND=noninteractive apt install -y systemd-zram-generator ;;
    dnf)    sudo dnf install -y zram-generator ;;
    pacman) sudo pacman -S --needed --noconfirm zram-generator ;;
esac

sudo tee /etc/systemd/zram-generator.conf > /dev/null <<EOF
[zram0]
zram-size = 32768
compression-algorithm = zstd
swap-priority = 100
EOF

sudo systemctl daemon-reload
sudo systemctl restart systemd-zram-setup@zram0.service
