#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing Cockpit and modules ($PKG)..."

case "$PKG" in
    apt)
        APT_PKGS=(
            cockpit
            cockpit-podman
            cockpit-machines
            cockpit-storaged
            cockpit-packagekit
            cockpit-networkmanager
            udisks2
            udisks2-lvm2
            udisks2-btrfs
            btrfs-progs
            mdadm
            nfs-common
            cifs-utils
            pcp
            packagekit
            podman
        )

        sudo DEBIAN_FRONTEND=noninteractive apt install -y "${APT_PKGS[@]}"

        # Install optional packages if available in current repository
        sudo DEBIAN_FRONTEND=noninteractive apt install -y cockpit-pcp 2>/dev/null || true
        sudo DEBIAN_FRONTEND=noninteractive apt install -y cockpit-files 2>/dev/null || true
        ;;

    dnf)
        DNF_PKGS=(
            cockpit
            cockpit-files
            cockpit-podman
            cockpit-machines
            cockpit-storaged
            cockpit-networkmanager
            cockpit-packagekit
            cockpit-selinux
            udisks2-btrfs
            udisks2-lvm2
            btrfs-progs
            mdadm
            nfs-utils
            cifs-utils
            pcp
            podman
        )

        sudo dnf install -y "${DNF_PKGS[@]}"
        ;;

    pacman)
        PACMAN_PKGS=(
            cockpit
            cockpit-files
            cockpit-podman
            cockpit-machines
            cockpit-storaged
            cockpit-packagekit
            packagekit
            udisks2
            udisks2-btrfs
            udisks2-lvm2
            btrfs-progs
            pcp
            mdadm
            nfs-utils
            cifs-utils
            inetutils
            podman
        )

        sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"

        # Install AUR package for Pacman integration
        if command -v paru >/dev/null 2>&1; then
            paru -S --needed --noconfirm cockpit-pacman
        elif command -v yay >/dev/null 2>&1; then
            yay -S --needed --noconfirm cockpit-pacman
        fi
        ;;
esac

# 1. Install or Update Btrfs Manager module
echo "==> Configuring Cockpit Btrfs Manager module..."
sudo mkdir -p /usr/share/cockpit
if [ ! -d /usr/share/cockpit/btrfs-manager ]; then
    sudo git clone --depth 1 https://github.com/NGxID18/btrfs-manager /usr/share/cockpit/btrfs-manager
else
    echo "  -> btrfs-manager already exists. Updating..."
    sudo git -C /usr/share/cockpit/btrfs-manager pull --ff-only 2>/dev/null || true
fi

# 2. Permissions for VM management (KVM/Libvirt)
TARGET_USER="${SUDO_USER:-$USER}"
for grp in libvirt kvm; do
    if getent group "$grp" >/dev/null 2>&1; then
        sudo usermod -aG "$grp" "$TARGET_USER" 2>/dev/null || true
    fi
done

# 3. Enable and Start Services
echo "==> Enabling Cockpit and related system services..."
sudo systemctl daemon-reload
sudo systemctl enable --now cockpit.socket

# Enable Podman socket for container management in Cockpit
sudo systemctl enable --now podman.socket 2>/dev/null || true

# Enable Performance Co-Pilot (PCP) for metrics graphs in Cockpit
sudo systemctl enable --now pmlogger.service pmproxy.service 2>/dev/null || true

# 4. Firewall configuration (Port 9090)
echo "==> Configuring firewall for Cockpit (port 9090)..."
if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld 2>/dev/null; then
    sudo firewall-cmd --add-service=cockpit --permanent 2>/dev/null || sudo firewall-cmd --add-port=9090/tcp --permanent 2>/dev/null || true
    sudo firewall-cmd --reload 2>/dev/null || true
    echo "  -> Firewalld: Port 9090 / cockpit service allowed."
elif command -v ufw >/dev/null 2>&1 && sudo ufw status 2>/dev/null | grep -q "Status: active"; then
    sudo ufw allow 9090/tcp comment 'Cockpit Web Console' 2>/dev/null || true
    echo "  -> UFW: Port 9090/tcp allowed."
fi
