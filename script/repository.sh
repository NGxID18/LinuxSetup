#!/usr/bin/env bash
set -euo pipefail

case "$PKG" in
    apt)
        echo "==> Configuring APT repositories & updating system (${DISTRO:-debian})..."
        sudo apt update -y
        sudo DEBIAN_FRONTEND=noninteractive apt install -y \
            ca-certificates gnupg curl wget git unzip tar xz-utils flatpak

        case "${DISTRO:-debian}" in
            ubuntu)
                # 1. Completely purge Snap from Ubuntu down to the root
                if command -v snap >/dev/null 2>&1 || dpkg-query -W -f='${Status}\n' snapd 2>/dev/null | grep -q "installed"; then
                    echo "==> Completely removing and purging Snap from Ubuntu..."

                    if command -v snap >/dev/null 2>&1; then
                        for s in $(snap list 2>/dev/null | awk 'NR>1 {print $1}' | grep -vE '^(snapd|core[0-9]*|bare)$' || true); do
                            sudo snap remove --purge "$s" 2>/dev/null || true
                        done
                        for s in $(snap list 2>/dev/null | awk 'NR>1 {print $1}' || true); do
                            sudo snap remove --purge "$s" 2>/dev/null || true
                        done
                    fi

                    sudo systemctl stop snapd.service snapd.socket snapd.seeded.service 2>/dev/null || true
                    sudo systemctl disable snapd.service snapd.socket snapd.seeded.service 2>/dev/null || true

                    sudo DEBIAN_FRONTEND=noninteractive apt purge -y snapd gnome-software-plugin-snap 2>/dev/null || true
                    sudo apt autoremove --purge -y 2>/dev/null || true

                    sudo rm -rf /snap /var/snap /var/lib/snapd /var/cache/snapd /usr/lib/snapd "$HOME/snap"
                fi

                # 2. Permanently block snapd from ever being reinstalled via APT pinning
                sudo mkdir -p /etc/apt/preferences.d
                sudo tee /etc/apt/preferences.d/nosnap.pref > /dev/null <<'EOF'
# Prevent snapd from ever being installed on this system
Package: snapd
Pin: release *
Pin-Priority: -10
EOF

                sudo DEBIAN_FRONTEND=noninteractive apt install -y software-properties-common 2>/dev/null || true
                sudo add-apt-repository -y universe
                sudo add-apt-repository -y multiverse
                ;;

            debian|*)
                # Debian 13 (Trixie): ensure stable main, contrib, non-free, non-free-firmware
                if [ -f /etc/apt/sources.list ]; then
                    sudo sed -i -E '/^[[:space:]]*deb(-src)?[[:space:]]/ s/\bmain([[:space:]]+(contrib|non-free|non-free-firmware))*\b/main contrib non-free non-free-firmware/g' /etc/apt/sources.list
                fi
                if [ -f /etc/apt/sources.list.d/debian.sources ]; then
                    sudo sed -i -E '/^Components:/ s/\bmain([[:space:]]+(contrib|non-free|non-free-firmware))*\b/main contrib non-free non-free-firmware/g' /etc/apt/sources.list.d/debian.sources
                fi
                ;;
        esac

        sudo apt update -y
        sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y
        ;;

    dnf)
        echo "==> Configuring DNF repositories & updating system (${DISTRO:-fedora})..."
        case "${DISTRO:-fedora}" in
            fedora)
                FEDORA_VER="$(rpm -E %fedora)"
                sudo dnf install -y \
                    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm" \
                    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm"
                sudo dnf install -y rpmfusion-nonfree-release-tainted 2>/dev/null || true
                # Support both DNF5 (Fedora 41-45+) and DNF4 syntax
                sudo dnf config-manager setopt "*-testing.enabled=0" 2>/dev/null \
                    || sudo dnf config-manager --set-disabled "*-testing" 2>/dev/null || true
                sudo dnf config-manager setopt "fedora-cisco-openh264.enabled=1" 2>/dev/null || true
                ;;

            rhel|*)
                RHEL_VER="$(rpm -E %rhel)"
                sudo dnf install -y epel-release
                sudo dnf config-manager setopt "crb.enabled=1" 2>/dev/null \
                    || sudo dnf config-manager --set-enabled crb 2>/dev/null || true
                sudo dnf install -y --nogpgcheck \
                    "https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-${RHEL_VER}.noarch.rpm" \
                    "https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-${RHEL_VER}.noarch.rpm"
                sudo dnf config-manager setopt "*-testing.enabled=0" 2>/dev/null \
                    || sudo dnf config-manager --set-disabled "*-testing" 2>/dev/null || true
                ;;
        esac

        sudo dnf upgrade --refresh -y
        sudo dnf install -y git curl wget unzip tar xz flatpak
        ;;

    zypper)
        echo "==> Refreshing openSUSE repositories & updating system (${DISTRO:-tumbleweed})..."
        # Disable leftover physical installation media (cd://, dvd://, hd://) & debug/source repos
        for repo in $(zypper lr -u 2>/dev/null | awk -F'|' '$0 ~ /(cd|dvd|hd):\/\// {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}'); do
            sudo zypper mr -d "$repo" 2>/dev/null || true
        done
        sudo zypper mr -d repo-debug repo-source 2>/dev/null || true
        sudo zypper --non-interactive --gpg-auto-import-keys refresh

        case "${DISTRO:-tumbleweed}" in
            tumbleweed)
                sudo zypper --non-interactive --gpg-auto-import-keys dist-upgrade -y --auto-agree-with-licenses
                ;;
            leap|*)
                sudo zypper --non-interactive --gpg-auto-import-keys update -y --auto-agree-with-licenses
                ;;
        esac

        sudo zypper --non-interactive --gpg-auto-import-keys install -y git curl wget unzip tar xz flatpak
        ;;

    pacman)
        AUR_HELPER="${AUR_HELPER:-paru}"
        echo "==> Updating Arch Linux repositories & installing base-devel (${DISTRO:-arch} | AUR: $AUR_HELPER)..."
        # Ensure testing repositories are commented out in /etc/pacman.conf if any
        if grep -qE '^\[(core-testing|extra-testing|multilib-testing)\]' /etc/pacman.conf 2>/dev/null; then
            sudo sed -i -E '/^\[(core-testing|extra-testing|multilib-testing)\]/,/^Include/ s/^/#/' /etc/pacman.conf
        fi
        # Ensure [multilib] is enabled for 32-bit GPU/Steam libraries
        if grep -qE '^#\[multilib\]' /etc/pacman.conf 2>/dev/null; then
            sudo sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf
        fi

        sudo pacman -Syu --noconfirm
        sudo pacman -S --needed --noconfirm base-devel git curl wget unzip tar xz flatpak

        case "${DISTRO:-arch}" in
            cachyos)
                sudo pacman -S --needed --noconfirm "$AUR_HELPER" 2>/dev/null || true
                ;;
            arch|*)
                ;;
        esac

        if ! command -v "$AUR_HELPER" >/dev/null 2>&1; then
            echo "==> Building & installing ${AUR_HELPER} AUR helper (${AUR_HELPER}-bin)..."
            BUILD_DIR="$(mktemp -d "/tmp/${AUR_HELPER}.XXXXXX")"
            git clone --depth 1 "https://aur.archlinux.org/${AUR_HELPER}-bin.git" "$BUILD_DIR"
            (cd "$BUILD_DIR" && makepkg -si --noconfirm)
            rm -rf "$BUILD_DIR"
        fi

        if command -v "$AUR_HELPER" >/dev/null 2>&1; then
            "$AUR_HELPER" -Sua --noconfirm 2>/dev/null || true
        fi
        ;;
esac

echo "==> Adding Flathub stable remote..."
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
