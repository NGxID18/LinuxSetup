#!/usr/bin/env bash
set -euo pipefail

echo "==> Enabling Cockpit systemd socket..."
sudo systemctl daemon-reload
sudo systemctl enable --now cockpit.socket

echo "==> Configuring firewall for Cockpit (port 9090)..."
if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld 2>/dev/null; then
    sudo firewall-cmd --add-service=cockpit --permanent 2>/dev/null || sudo firewall-cmd --add-port=9090/tcp --permanent 2>/dev/null || true
    sudo firewall-cmd --reload 2>/dev/null || true
    echo "  -> Firewalld: Port 9090 / cockpit service allowed."
elif command -v ufw >/dev/null 2>&1 && sudo ufw status 2>/dev/null | grep -q "Status: active"; then
    sudo ufw allow 9090/tcp comment 'Cockpit Web Console' 2>/dev/null || true
    echo "  -> UFW: Port 9090/tcp allowed."
fi
