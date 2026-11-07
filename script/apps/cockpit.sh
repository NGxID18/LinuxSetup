#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing Cockpit core and default extensions ($PKG | ${DISTRO:-$PKG})..."

case "$PKG" in
    apt)
        case "${DISTRO:-debian}" in
            ubuntu|debian|*)
                sudo DEBIAN_FRONTEND=noninteractive apt install -y \
                    cockpit \
                    cockpit-storaged \
                    cockpit-networkmanager \
                    udisks2
                ;;
        esac
        ;;

    dnf)
        case "${DISTRO:-fedora}" in
            fedora|rhel|*)
                sudo dnf install -y \
                    cockpit \
                    cockpit-storaged \
                    cockpit-networkmanager \
                    cockpit-selinux \
                    udisks2
                ;;
        esac
        ;;

    zypper)
        case "${DISTRO:-tumbleweed}" in
            tumbleweed|leap|*)
                sudo zypper --non-interactive --gpg-auto-import-keys install -y \
                    cockpit \
                    cockpit-storaged \
                    cockpit-networkmanager \
                    udisks2
                ;;
        esac
        ;;

    pacman)
        case "${DISTRO:-arch}" in
            cachyos|arch|*)
                sudo pacman -S --needed --noconfirm \
                    cockpit \
                    cockpit-storaged \
                    udisks2 \
                    networkmanager
                ;;
        esac
        ;;
esac

# Enable and Start Cockpit Socket
echo "==> Enabling Cockpit systemd socket..."
sudo systemctl daemon-reload
sudo systemctl enable --now cockpit.socket

# Firewall Configuration (Port 9090)
echo "==> Configuring firewall for Cockpit (port 9090)..."
if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld 2>/dev/null; then
    sudo firewall-cmd --add-service=cockpit --permanent 2>/dev/null || sudo firewall-cmd --add-port=9090/tcp --permanent 2>/dev/null || true
    sudo firewall-cmd --reload 2>/dev/null || true
    echo "  -> Firewalld: Port 9090 / cockpit service allowed."
elif command -v ufw >/dev/null 2>&1 && sudo ufw status 2>/dev/null | grep -q "Status: active"; then
    sudo ufw allow 9090/tcp comment 'Cockpit Web Console' 2>/dev/null || true
    echo "  -> UFW: Port 9090/tcp allowed."
fi
