#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing minimal GNOME desktop ($PKG)..."
case "$PKG" in
    apt)
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
            gnome-software-plugin-flatpak \
            gnome-tweaks \
            gnome-shell-extension-prefs \
            dconf-cli
        sudo systemctl enable gdm3
        ;;

    dnf)
        sudo dnf install -y \
            gdm \
            gnome-shell \
            nautilus \
            gnome-text-editor \
            gnome-calculator \
            gnome-software \
            gnome-tweaks \
            gnome-extensions-app
        sudo systemctl enable gdm
        ;;

    pacman)
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
        sudo systemctl enable gdm
        ;;
esac

sudo systemctl set-default graphical.target

echo "==> Installing wallpapers & registering with GNOME..."
WP_DEST="/usr/share/backgrounds/Wallpapers"
XML_DIR="/usr/share/gnome-background-properties"
XML_FILE="$XML_DIR/linuxsetup-wallpapers.xml"

sudo mkdir -p "$WP_DEST" "$XML_DIR"
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

echo "==> Installing GNOME extensions..."
SHELL_VER="$(gnome-shell --version | awk '{print $3}' | cut -d. -f1)"
EXTENSIONS=(
    "blur-my-shell@aunetx"
    "Vitals@CoreCoding.com"
    "appindicatorsupport@rgcjonas.gmail.com"
)

for uuid in "${EXTENSIONS[@]}"; do
    INFO_URL="https://extensions.gnome.org/extension-info/?uuid=${uuid}&shell_version=${SHELL_VER}"
    DL_PATH="$(curl -fsSL "$INFO_URL" 2>/dev/null | sed -n 's/.*"download_url":[[:space:]]*"\([^"]*\)".*/\1/p' || true)"

    if [ -n "$DL_PATH" ]; then
        TMP_ZIP="$(mktemp "/tmp/${uuid}.XXXXXX.zip")"
        if curl -fsSL "https://extensions.gnome.org${DL_PATH}" -o "$TMP_ZIP"; then
            gnome-extensions install --force "$TMP_ZIP" || true
            gnome-extensions enable "$uuid" 2>/dev/null || true
        fi
        rm -f "$TMP_ZIP"
    fi
done

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

sudo dconf update
