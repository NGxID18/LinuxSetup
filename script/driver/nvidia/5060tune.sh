#!/usr/bin/env bash
set -e

echo "==> Configuring 5060tune service..."
sudo tee /etc/systemd/system/5060tune.service > /dev/null <<EOF
[Unit]
Description=NVIDIA GPU Power and Clock Limit
After=nvidia-persistenced.service
Wants=nvidia-persistenced.service

[Service]
Type=oneshot
ExecStart=/usr/bin/nvidia-smi -pl 123
ExecStart=/usr/bin/nvidia-smi -lgc 210,2400
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now 5060tune.service
