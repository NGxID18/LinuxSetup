#!/usr/bin/env bash
set -euo pipefail

echo "==> Configuring 5060tune service..."
NVIDIA_SMI_BIN="$(command -v nvidia-smi || echo "/usr/bin/nvidia-smi")"

sudo tee /etc/systemd/system/5060tune.service > /dev/null <<EOF
[Unit]
Description=NVIDIA GPU Power and Clock Limit
After=nvidia-persistenced.service
Wants=nvidia-persistenced.service

[Service]
Type=oneshot
ExecStart=-${NVIDIA_SMI_BIN} -pl 123
ExecStart=-${NVIDIA_SMI_BIN} -lgc 210,2400
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable 5060tune.service

if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
    sudo systemctl start 5060tune.service 2>/dev/null || true
else
    echo "==> Note: 5060tune.service enabled and will take effect after reboot."
fi
