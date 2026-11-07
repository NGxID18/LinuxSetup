#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing native apps and filesystem utilities ($PKG | ${DISTRO:-$PKG})..."
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

        case "${DISTRO:-debian}" in
            ubuntu|debian|*)
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
        esac
        ;;

    dnf)
        if [ ! -f /etc/yum.repos.d/vscodium.repo ]; then
            TMP_KEY="$(mktemp /tmp/vscodium.XXXXXX.gpg)"
            if curl -fsSL https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg -o "$TMP_KEY"; then
                sudo rpm --import "$TMP_KEY" 2>/dev/null || true
            fi
            rm -f "$TMP_KEY"
            sudo tee /etc/yum.repos.d/vscodium.repo > /dev/null <<'EOF'
[vscodium]
name=VSCodium
baseurl=https://download.vscodium.com/rpms/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg
metadata_expire=1h
EOF
        fi

        case "${DISTRO:-fedora}" in
            fedora)
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
                    e2fsprogs \
                    tailscale
                ;;

            rhel|*)
                sudo dnf install -y \
                    codium \
                    tuned \
                    cronie \
                    util-linux \
                    udisks2 \
                    udisks2-lvm2 \
                    lvm2 \
                    ntfs-3g \
                    exfatprogs \
                    xfsprogs \
                    dosfstools \
                    e2fsprogs
                sudo dnf install -y flatseal snapper btrfs-progs udisks2-btrfs 2>/dev/null || true
                ;;
        esac
        ;;

    zypper)
        if [ ! -f /etc/zypp/repos.d/vscodium.repo ]; then
            TMP_KEY="$(mktemp /tmp/vscodium.XXXXXX.gpg)"
            if curl -fsSL https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg -o "$TMP_KEY"; then
                sudo rpm --import "$TMP_KEY" 2>/dev/null || true
            fi
            rm -f "$TMP_KEY"
            sudo tee /etc/zypp/repos.d/vscodium.repo > /dev/null <<'EOF'
[vscodium]
name=VSCodium
enabled=1
autorefresh=1
baseurl=https://download.vscodium.com/rpms/
type=rpm-md
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg
EOF
            sudo zypper --non-interactive --gpg-auto-import-keys refresh vscodium 2>/dev/null || true
        fi

        case "${DISTRO:-tumbleweed}" in
            tumbleweed)
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
                    e2fsprogs \
                    tailscale
                ;;

            leap|*)
                sudo zypper --non-interactive --gpg-auto-import-keys install -y \
                    codium \
                    tuned \
                    snapper \
                    cronie \
                    util-linux \
                    udisks2 \
                    btrfs-progs \
                    lvm2 \
                    ntfs-3g \
                    exfatprogs \
                    xfsprogs \
                    dosfstools \
                    e2fsprogs
                sudo zypper --non-interactive --gpg-auto-import-keys install -y \
                    flatseal udisks2-btrfs udisks2-lvm2 tailscale 2>/dev/null || true
                ;;
        esac
        ;;

    pacman)
        case "${DISTRO:-arch}" in
            cachyos|arch|*)
                sudo pacman -S --needed --noconfirm \
                    flatseal \
                    tuned \
                    snapper \
                    cronie \
                    tailscale \
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

                if [ -n "${AUR_HELPER:-}" ] && command -v "$AUR_HELPER" >/dev/null 2>&1; then
                    "$AUR_HELPER" -S --needed --noconfirm vscodium-bin
                elif command -v paru >/dev/null 2>&1; then
                    paru -S --needed --noconfirm vscodium-bin
                elif command -v yay >/dev/null 2>&1; then
                    yay -S --needed --noconfirm vscodium-bin
                fi
                ;;
        esac
        ;;
esac

# Install Tailscale via official script if not already installed via native repo
if ! command -v tailscale >/dev/null 2>&1; then
    echo "==> Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sudo sh
fi

# Enable background services for each distribution
echo "==> Enabling background services (Tailscale, Tuned, Cron)..."
sudo systemctl enable --now tailscaled 2>/dev/null || true
sudo systemctl enable --now tuned 2>/dev/null || true
case "$PKG" in
    apt)
        sudo systemctl enable --now cron 2>/dev/null || true
        ;;
    dnf)
        sudo systemctl enable --now crond 2>/dev/null || true
        ;;
    zypper)
        sudo systemctl enable --now cron 2>/dev/null || sudo systemctl enable --now cronie 2>/dev/null || true
        ;;
    pacman)
        sudo systemctl enable --now cronie 2>/dev/null || true
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

# If native flatseal was unavailable on the distribution (e.g. RHEL / Leap), install via Flatpak
if ! command -v flatseal >/dev/null 2>&1 && ! rpm -q flatseal >/dev/null 2>&1 && ! dpkg -s flatseal >/dev/null 2>&1; then
    FLATPAK_APPS+=("com.github.tchx84.Flatseal")
fi

for app in "${FLATPAK_APPS[@]}"; do
    echo "  -> Installing Flatpak: $app..."
    sudo flatpak install -y --noninteractive flathub "$app" 2>/dev/null || true
done
