#!/usr/bin/env bash
set -euo pipefail

case "$PKG" in
    apt)
        echo "==> Configuring APT stable repositories & updating system..."
        sudo apt update -y
        sudo DEBIAN_FRONTEND=noninteractive apt install -y \
            ca-certificates gnupg curl wget git unzip tar xz-utils flatpak

        if grep -qiE '^ID(_LIKE)?=.*ubuntu' /etc/os-release; then
            # 1. Completely purge Snap from Ubuntu down to the root
            if command -v snap >/dev/null 2>&1 || dpkg-query -W -f='${Status}\n' snapd 2>/dev/null | grep -q "installed"; then
                echo "==> Completely removing and purging Snap from Ubuntu..."

                # Remove all installed snap packages in proper order
                if command -v snap >/dev/null 2>&1; then
                    for s in $(snap list 2>/dev/null | awk 'NR>1 {print $1}' | grep -vE '^(snapd|core[0-9]*|bare)$' || true); do
                        sudo snap remove --purge "$s" 2>/dev/null || true
                    done
                    for s in $(snap list 2>/dev/null | awk 'NR>1 {print $1}' || true); do
                        sudo snap remove --purge "$s" 2>/dev/null || true
                    done
                fi

                # Stop and disable systemd services and sockets
                sudo systemctl stop snapd.service snapd.socket snapd.seeded.service 2>/dev/null || true
                sudo systemctl disable snapd.service snapd.socket snapd.seeded.service 2>/dev/null || true

                # Purge snapd package and related plugins
                sudo DEBIAN_FRONTEND=noninteractive apt purge -y snapd gnome-software-plugin-snap 2>/dev/null || true
                sudo apt autoremove --purge -y 2>/dev/null || true

                # Clean residual directories and cache
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

            sudo DEBIAN_FRONTEND=noninteractive apt install -y software-properties-common
            sudo add-apt-repository -y universe
            sudo add-apt-repository -y multiverse
        else
            # Debian: ensure stable main, contrib, non-free, non-free-firmware only (no testing/unstable)
            if [ -f /etc/apt/sources.list ]; then
                sudo sed -i -E '/^[[:space:]]*deb(-src)?[[:space:]]/ s/\bmain([[:space:]]+(contrib|non-free|non-free-firmware))*\b/main contrib non-free non-free-firmware/g' /etc/apt/sources.list
            fi
            if [ -f /etc/apt/sources.list.d/debian.sources ]; then
                sudo sed -i -E '/^Components:/ s/\bmain([[:space:]]+(contrib|non-free|non-free-firmware))*\b/main contrib non-free non-free-firmware/g' /etc/apt/sources.list.d/debian.sources
            fi
        fi

        sudo apt update -y
        sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y
        ;;

    dnf)
        echo "==> Configuring DNF stable repositories & updating system..."
        if [ "$(rpm -E %fedora 2>/dev/null)" != "%fedora" ]; then
            FEDORA_VER="$(rpm -E %fedora)"
            sudo dnf install -y \
                "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm" \
                "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm"
            sudo dnf config-manager disable "*-testing" 2>/dev/null || true
        elif [ "$(rpm -E %rhel 2>/dev/null)" != "%rhel" ]; then
            RHEL_VER="$(rpm -E %rhel)"
            sudo dnf install -y epel-release
            sudo dnf config-manager enable crb 2>/dev/null || true
            sudo dnf install -y --nogpgcheck \
                "https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-${RHEL_VER}.noarch.rpm" \
                "https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-${RHEL_VER}.noarch.rpm"
            sudo dnf config-manager disable "*-testing" 2>/dev/null || true
        fi

        sudo dnf upgrade --refresh -y
        sudo dnf install -y git curl wget unzip tar xz flatpak
        ;;

    zypper)
        echo "==> Refreshing openSUSE stable repositories & updating system..."
        # Ensure only default official stable repositories (OSS, Non-OSS, Update) are active
        sudo zypper mr -d repo-debug repo-source 2>/dev/null || true
        sudo zypper --non-interactive refresh
        sudo zypper --non-interactive dist-upgrade 2>/dev/null || sudo zypper --non-interactive update -y
        sudo zypper --non-interactive install -y git curl wget unzip tar xz flatpak
        ;;

    pacman)
        echo "==> Updating Arch Linux stable repositories & installing base-devel..."
        # Ensure testing repositories are commented out in /etc/pacman.conf if any
        if grep -qE '^\[(core-testing|extra-testing|multilib-testing)\]' /etc/pacman.conf 2>/dev/null; then
            sudo sed -i -E '/^\[(core-testing|extra-testing|multilib-testing)\]/,/^Include/ s/^/#/' /etc/pacman.conf
        fi
        sudo pacman -Syu --noconfirm
        sudo pacman -S --needed --noconfirm base-devel git curl wget unzip tar xz flatpak

        if ! command -v paru >/dev/null 2>&1 && ! command -v yay >/dev/null 2>&1; then
            echo "==> Building & installing Paru AUR helper (paru-bin)..."
            BUILD_DIR="$(mktemp -d /tmp/paru.XXXXXX)"
            git clone --depth 1 https://aur.archlinux.org/paru-bin.git "$BUILD_DIR"
            (cd "$BUILD_DIR" && makepkg -si --noconfirm)
            rm -rf "$BUILD_DIR"
        fi

        if command -v paru >/dev/null 2>&1; then
            paru -Sua --noconfirm 2>/dev/null || true
        fi
        ;;
esac

echo "==> Adding Flathub stable remote..."
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
