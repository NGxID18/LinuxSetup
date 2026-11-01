#!/usr/bin/env bash
set -e

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
            gnome-tweaks \
            gnome-shell-extension-prefs
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

echo "==> Installing GNOME extensions..."
SHELL_VER=$(gnome-shell --version | awk '{print $3}' | cut -d. -f1)
EXTENSIONS=(
    "blur-my-shell@aunetx"
    "Vitals@CoreCoding.com"
    "appindicatorsupport@rgcjonas.gmail.com"
)

for uuid in "${EXTENSIONS[@]}"; do
    INFO_URL="https://extensions.gnome.org/extension-info/?uuid=${uuid}&shell_version=${SHELL_VER}"
    DL_PATH=$(curl -s "$INFO_URL" | grep -oP '(?<="download_url": ")[^"]+' || true)

    if [ -n "$DL_PATH" ]; then
        TMP_ZIP="/tmp/${uuid}.zip"
        curl -sL "https://extensions.gnome.org${DL_PATH}" -o "$TMP_ZIP"
        gnome-extensions install --force "$TMP_ZIP"
        gnome-extensions enable "$uuid" 2>/dev/null || true
        rm -f "$TMP_ZIP"
    fi
done
