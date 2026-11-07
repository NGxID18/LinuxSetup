#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing minimal, non-bloated GNOME desktop ($PKG | ${DISTRO:-$PKG})..."
case "$PKG" in
    apt)
        case "${DISTRO:-debian}" in
            ubuntu|debian|*)
                sudo DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
                    gdm3 \
                    gnome-shell \
                    gnome-session \
                    gnome-settings-daemon \
                    gnome-control-center \
                    gnome-keyring \
                    gnome-backgrounds \
                    xdg-desktop-portal-gnome \
                    xdg-user-dirs-gtk \
                    gvfs-backends \
                    gvfs-fuse \
                    network-manager-gnome \
                    nautilus \
                    file-roller \
                    gnome-text-editor \
                    gnome-calculator \
                    gnome-software \
                    gnome-tweaks \
                    gnome-shell-extension-prefs \
                    dconf-cli
                sudo systemctl enable gdm3 2>/dev/null || sudo systemctl enable gdm 2>/dev/null || true
                ;;
        esac
        ;;

    dnf)
        case "${DISTRO:-fedora}" in
            fedora)
                sudo dnf install -y \
                    gdm \
                    gnome-shell \
                    gnome-session \
                    gnome-settings-daemon \
                    gnome-control-center \
                    gnome-keyring \
                    xdg-desktop-portal-gnome \
                    xdg-user-dirs-gtk \
                    nautilus \
                    file-roller \
                    gnome-text-editor \
                    gnome-calculator \
                    gnome-software \
                    gnome-tweaks \
                    gnome-extensions-app
                ;;

            rhel|*)
                sudo dnf install -y \
                    gdm \
                    gnome-shell \
                    gnome-session \
                    gnome-settings-daemon \
                    gnome-control-center \
                    gnome-keyring \
                    xdg-desktop-portal-gnome \
                    xdg-user-dirs-gtk \
                    nautilus \
                    gnome-text-editor \
                    gnome-calculator \
                    gnome-software \
                    gnome-tweaks \
                    || sudo dnf groupinstall -y "Workstation"
                sudo dnf install -y file-roller gnome-extensions-app 2>/dev/null || true
                ;;
        esac
        sudo systemctl enable gdm
        ;;

    zypper)
        # Remove minimal-base conflict package if installed on minimal server setup
        sudo zypper --non-interactive remove -y patterns-base-minimal_base-conflicts 2>/dev/null || true

        case "${DISTRO:-tumbleweed}" in
            tumbleweed|leap|*)
                sudo zypper --non-interactive --gpg-auto-import-keys install -y --no-recommends \
                    -t pattern gnome_basic 2>/dev/null \
                    || sudo zypper --non-interactive --gpg-auto-import-keys install -y --no-recommends \
                        patterns-gnome-gnome_basic 2>/dev/null || true

                sudo zypper --non-interactive --gpg-auto-import-keys install -y --no-recommends \
                    gdm \
                    gnome-shell \
                    gnome-control-center \
                    nautilus \
                    file-roller \
                    gnome-text-editor \
                    gnome-calculator \
                    gnome-tweaks \
                    gnome-extensions-app \
                    xdg-desktop-portal-gnome
                ;;
        esac
        sudo systemctl enable gdm 2>/dev/null || sudo systemctl enable display-manager 2>/dev/null || true
        ;;

    pacman)
        case "${DISTRO:-arch}" in
            cachyos|arch|*)
                sudo pacman -S --needed --noconfirm \
                    gdm \
                    gnome-shell \
                    gnome-session \
                    gnome-settings-daemon \
                    gnome-control-center \
                    gnome-keyring \
                    gnome-backgrounds \
                    xdg-desktop-portal-gnome \
                    xdg-user-dirs-gtk \
                    gvfs \
                    gvfs-mtp \
                    gvfs-smb \
                    gvfs-nfs \
                    nautilus \
                    file-roller \
                    loupe \
                    gnome-text-editor \
                    gnome-calculator \
                    gnome-software \
                    gnome-tweaks \
                    extension-manager
                ;;
        esac
        sudo systemctl enable gdm
        ;;
esac

sudo systemctl set-default graphical.target

echo "==> Installing wallpapers & registering with GNOME..."
WP_DEST="/usr/share/backgrounds/Wallpapers"
XML_DIR="/usr/share/gnome-background-properties"
XML_FILE="$XML_DIR/linuxsetup-wallpapers.xml"

sudo mkdir -p "$WP_DEST" "$XML_DIR"
if [ -d "$ROOT_DIR/Wallpapers" ]; then
    sudo cp -r "$ROOT_DIR/Wallpapers/." "$WP_DEST/"
    sudo chmod 755 "$WP_DEST"
    sudo find "$WP_DEST" -type f -exec chmod 644 {} +

    {
        echo '<?xml version="1.0" encoding="UTF-8"?>'
        echo '<!DOCTYPE wallpapers SYSTEM "gnome-wp-list.dtd">'
        echo '<wallpapers>'
        for wp in "$WP_DEST"/*; do
            [ -f "$wp" ] || continue
            wp_base="$(basename "$wp")"
            wp_name="${wp_base%.*}"
            echo '  <wallpaper deleted="false">'
            echo "    <name>${wp_name}</name>"
            echo "    <filename>${wp}</filename>"
            echo '    <options>zoom</options>'
            echo '  </wallpaper>'
        done
        echo '</wallpapers>'
    } | sudo tee "$XML_FILE" > /dev/null
    sudo chmod 644 "$XML_FILE"
fi

echo "==> Installing GNOME extensions globally (for all users)..."
SHELL_VER="$(gnome-shell --version 2>/dev/null | awk '{print $3}' | cut -d. -f1 || true)"
EXTENSIONS=(
    "blur-my-shell@aunetx"
    "Vitals@CoreCoding.com"
    "appindicatorsupport@rgcjonas.gmail.com"
)

SYS_EXT_DIR="/usr/share/gnome-shell/extensions"
sudo mkdir -p "$SYS_EXT_DIR"

if [ -n "$SHELL_VER" ]; then
    for uuid in "${EXTENSIONS[@]}"; do
        INFO_URL="https://extensions.gnome.org/extension-info/?uuid=${uuid}&shell_version=${SHELL_VER}"
        DL_PATH="$(curl -fsSL "$INFO_URL" 2>/dev/null | sed -n 's/.*"download_url":[[:space:]]*"\([^"]*\)".*/\1/p' || true)"

        if [ -n "$DL_PATH" ]; then
            echo "  -> Downloading global extension: $uuid..."
            TMP_ZIP="$(mktemp "/tmp/${uuid}.XXXXXX.zip")"
            if curl -fsSL "https://extensions.gnome.org${DL_PATH}" -o "$TMP_ZIP"; then
                TARGET_DIR="$SYS_EXT_DIR/$uuid"
                sudo rm -rf "$TARGET_DIR"
                sudo mkdir -p "$TARGET_DIR"
                sudo unzip -qo "$TMP_ZIP" -d "$TARGET_DIR"
                sudo chmod 755 "$TARGET_DIR"
                sudo find "$TARGET_DIR" -type d -exec chmod 755 {} +
                sudo find "$TARGET_DIR" -type f -exec chmod 644 {} +
            fi
            rm -f "$TMP_ZIP"
        fi
    done
fi

sudo mkdir -p /etc/dconf/profile /etc/dconf/db/local.d
if [ ! -f /etc/dconf/profile/user ]; then
    sudo tee /etc/dconf/profile/user > /dev/null <<'EOF'
user-db:user
system-db:local
EOF
fi

sudo tee /etc/dconf/db/local.d/00-extensions > /dev/null <<'EOF'
[org/gnome/shell]
disable-user-extensions=false
enabled-extensions=['blur-my-shell@aunetx', 'Vitals@CoreCoding.com', 'appindicatorsupport@rgcjonas.gmail.com']
EOF

if command -v dconf >/dev/null 2>&1; then
    sudo dconf update 2>/dev/null || true
fi
