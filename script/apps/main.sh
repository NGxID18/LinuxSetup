#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing native apps ($PKG)..."
case "$PKG" in
    apt)
        if [ ! -f /etc/apt/sources.list.d/vscodium.list ]; then
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
            btrfs-progs \
            lvm2 \
            ntfs-3g \
            exfatprogs \
            xfsprogs \
            cron

        if ! command -v tailscale >/dev/null 2>&1; then
            curl -fsSL https://tailscale.com/install.sh | sudo sh
        fi

        sudo systemctl enable --now tailscaled cron tuned
        ;;

    dnf)
        if [ ! -f /etc/yum.repos.d/vscodium.repo ]; then
            sudo rpmkeys --import https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/-/raw/master/pub.gpg
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
            btrfs-progs \
            lvm2 \
            ntfs-3g \
            exfatprogs \
            xfsprogs \
            cronie

        if ! command -v tailscale >/dev/null 2>&1; then
            curl -fsSL https://tailscale.com/install.sh | sudo sh
        fi

        sudo systemctl enable --now tailscaled crond tuned
        ;;

    pacman)
        sudo pacman -S --needed --noconfirm \
            flatseal \
            mission-center \
            tuned \
            snapper \
            tailscale \
            cronie \
            util-linux \
            udisks2 \
            lvm2 \
            udisks2-lvm2 \
            btrfs-progs \
            udisks2-btrfs \
            ntfs-3g \
            xfsprogs \
            exfatprogs

        paru -S --needed --noconfirm vscodium-bin

        sudo systemctl enable --now tailscaled cronie tuned
        ;;
esac

echo "==> Installing Flatpak apps..."
sudo flatpak install -y flathub \
    com.valvesoftware.Steam \
    com.discordapp.Discord \
    io.gitlab.librewolf-community \
    org.prismlauncher.PrismLauncher \
    com.rtosta.zapzap \
    com.obsproject.Studio

echo "==> Installing latest OBSVkCapture Vulkan layer..."
LATEST_VKCAPTURE=$(flatpak remote-ls flathub --columns=ref 2>/dev/null | grep 'org.freedesktop.Platform.VulkanLayer.OBSVkCapture/' | sort -V | tail -n 1 || true)
if [ -n "$LATEST_VKCAPTURE" ]; then
    sudo flatpak install -y flathub "$LATEST_VKCAPTURE"
fi
