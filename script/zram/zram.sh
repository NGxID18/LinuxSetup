#!/usr/bin/env bash
set -euo pipefail

ZRAM_SIZE="${ZRAM_SIZE:-32768}"

echo "==> Configuring zRAM (${ZRAM_SIZE} MB zstd) on $PKG (${DISTRO:-$PKG})..."
case "$PKG" in
    apt)
        case "${DISTRO:-debian}" in
            ubuntu|debian|*)
                sudo DEBIAN_FRONTEND=noninteractive apt install -y systemd-zram-generator
                ;;
        esac
        ;;
    dnf)
        case "${DISTRO:-fedora}" in
            fedora|rhel|*)
                sudo dnf install -y zram-generator
                ;;
        esac
        ;;
    zypper)
        case "${DISTRO:-tumbleweed}" in
            tumbleweed|leap|*)
                sudo zypper --non-interactive --gpg-auto-import-keys install -y zram-generator
                ;;
        esac
        ;;
    pacman)
        case "${DISTRO:-arch}" in
            cachyos|arch|*)
                sudo pacman -S --needed --noconfirm zram-generator
                ;;
        esac
        ;;
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
