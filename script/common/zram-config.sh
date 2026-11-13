#!/usr/bin/env bash
set -euo pipefail

ZRAM_SIZE="${ZRAM_SIZE:-32768}"

echo "==> Configuring zRAM (${ZRAM_SIZE} MB zstd)..."
sudo tee /etc/systemd/zram-generator.conf > /dev/null <<EOF
[zram0]
zram-size = ${ZRAM_SIZE}
compression-algorithm = zstd
swap-priority = 150
EOF

sudo swapoff /dev/zram0 2>/dev/null || true
sudo systemctl daemon-reload
sudo systemctl restart systemd-zram-setup@zram0.service 2>/dev/null || sudo systemctl start systemd-zram-setup@zram0.service 2>/dev/null || true
