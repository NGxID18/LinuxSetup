#!/usr/bin/env bash
set -euo pipefail

ZRAM_SIZE="${ZRAM_SIZE:-32768}"

echo "==> Configuring zRAM (${ZRAM_SIZE} MB zstd) on $PKG..."
case "$PKG" in
    apt)    sudo DEBIAN_FRONTEND=noninteractive apt install -y systemd-zram-generator ;;
    dnf)    sudo dnf install -y zram-generator ;;
    zypper) sudo zypper --non-interactive install -y zram-generator ;;
    pacman) sudo pacman -S --needed --noconfirm zram-generator ;;
esac

sudo tee /etc/systemd/zram-generator.conf > /dev/null <<EOF
[zram0]
zram-size = ${ZRAM_SIZE}
compression-algorithm = zstd
swap-priority = 100
EOF

sudo swapoff /dev/zram0 2>/dev/null || true
sudo systemctl daemon-reload
sudo systemctl restart systemd-zram-setup@zram0.service 2>/dev/null || sudo systemctl start systemd-zram-setup@zram0.service 2>/dev/null || true
