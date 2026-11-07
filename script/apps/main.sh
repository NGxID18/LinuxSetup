#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing native apps and filesystem utilities ($PKG)..."
case "$PKG" in
    apt)
        if [ ! -f /etc/apt/sources.list.d/vscodium.list ]; then
            sudo mkdir -p /usr/share/keyrings
            curl -fsSL https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
                | gpg --dearmor --yes \
                | sudo tee /usr/share/keyrings/vscodium.gpg > /dev/null
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/vscodium.gpg] https://download.vscodium.com/debs vscodium main" \
                | sudo tee /etc/apt/sources.list.d/vscodium.list > /dev/null
            sudo apt update -y
        fi

        sudo DEBIAN_FRONTEND=noninteractive apt install -y \
            flatseal \
            codium \
            tuned \
            snapper \
            cron \
            util-linux \
            udisks2 \
            udisks2-btrfs \
            udisks2-lvm2 \
            btrfs-progs \
            lvm2 \
            ntfs-3g \
            exfatprogs \
            xfsprogs \
            dosfstools \
            e2fsprogs
        ;;

    dnf)
        if [ ! -f /etc/yum.repos.d/vscodium.repo ]; then
            sudo rpm --import https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/-/raw/master/pub.gpg 2>/dev/null || true
            sudo tee /etc/yum.repos.d/vscodium.repo > /dev/null <<'EOF'
[vscodium]
name=VSCodium
baseurl=https://download.vscodium.com/rpms/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/-/raw/master/pub.gpg
metadata_expire=1h
EOF
        fi

        sudo dnf install -y \
            flatseal \
            codium \
            tuned \
            snapper \
            cronie \
            util-linux \
            udisks2 \
            udisks2-btrfs \
            udisks2-lvm2 \
            btrfs-progs \
            lvm2 \
            ntfs-3g \
            exfatprogs \
            xfsprogs \
            dosfstools \
            e2fsprogs
        ;;

    zypper)
        if [ ! -f /etc/zypp/repos.d/vscodium.repo ]; then
            sudo rpm --import https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/-/raw/master/pub.gpg 2>/dev/null || true
            sudo zypper --non-interactive addrepo -f https://download.vscodium.com/rpms/ vscodium 2>/dev/null || true
        fi

        sudo zypper --non-interactive --gpg-auto-import-keys install -y \
            flatseal \
            codium \
            tuned \
            snapper \
            cronie \
            util-linux \
            udisks2 \
            udisks2-btrfs \
            udisks2-lvm2 \
            btrfs-progs \
            lvm2 \
            ntfs-3g \
            exfatprogs \
            xfsprogs \
            dosfstools \
            e2fsprogs
        ;;

    pacman)
        sudo pacman -S --needed --noconfirm \
            flatseal \
            tuned \
            snapper \
            cronie \
            util-linux \
            udisks2 \
            lvm2 \
            udisks2-lvm2 \
            btrfs-progs \
            udisks2-btrfs \
            ntfs-3g \
            xfsprogs \
            exfatprogs \
            dosfstools \
            e2fsprogs

        if command -v paru >/dev/null 2>&1; then
            paru -S --needed --noconfirm vscodium-bin
        elif command -v yay >/dev/null 2>&1; then
            yay -S --needed --noconfirm vscodium-bin
        fi
        ;;
esac

# Install Tailscale if not present
if ! command -v tailscale >/dev/null 2>&1; then
    echo "==> Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sudo sh
fi

# Enable background services for each distribution
echo "==> Enabling background services (Tailscale, Tuned, Cron)..."
case "$PKG" in
    apt)
        sudo systemctl enable --now tailscaled tuned cron
        ;;
    dnf)
        sudo systemctl enable --now tailscaled tuned crond
        ;;
    zypper)
        sudo systemctl enable --now tailscaled tuned cron
        ;;
    pacman)
        sudo systemctl enable --now tailscaled tuned cronie
        ;;
esac

echo "==> Installing Flatpak apps..."
FLATPAK_APPS=(
    "com.valvesoftware.Steam"
    "com.discordapp.Discord"
    "io.gitlab.librewolf-community"
    "org.prismlauncher.PrismLauncher"
    "com.rtosta.zapzap"
    "com.obsproject.Studio"
)

for app in "${FLATPAK_APPS[@]}"; do
    echo "  -> Installing Flatpak: $app..."
    sudo flatpak install -y --noninteractive flathub "$app" 2>/dev/null || true
done
