#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"

de_gnome_info() {
    DE_LABEL="GNOME (Minimal Desktop, GDM, Extensions & Wallpapers)"
}

de_gnome_install() {
    echo "==> Installing minimal GNOME desktop on Debian..."
    sudo DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
        gdm3 gnome-shell gnome-session gnome-settings-daemon gnome-control-center \
        gnome-keyring gnome-backgrounds xdg-desktop-portal-gnome xdg-user-dirs-gtk \
        gvfs-backends gvfs-fuse network-manager-gnome nautilus file-roller \
        gnome-text-editor gnome-calculator gnome-software gnome-tweaks \
        gnome-shell-extension-prefs dconf-cli libglib2.0-bin gir1.2-gtop-2.0 lm-sensors
    sudo systemctl enable gdm3 2>/dev/null || sudo systemctl enable gdm 2>/dev/null || true
    "$ROOT_DIR/script/common/gnome-config.sh"
}

de_gnome_verify() {
    register_expected_native \
        "gdm3|gdm" gnome-shell gnome-session gnome-settings-daemon gnome-control-center \
        gnome-keyring gnome-backgrounds xdg-desktop-portal-gnome xdg-user-dirs-gtk \
        gvfs-backends gvfs-fuse network-manager-gnome nautilus file-roller \
        gnome-text-editor gnome-calculator gnome-software \
        gnome-tweaks gnome-shell-extension-prefs dconf-cli \
        libglib2.0-bin gir1.2-gtop-2.0 lm-sensors
}

case "${1:-}" in
    --info)   de_gnome_info ;;
    --verify) de_gnome_verify ;;
    *)
        if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
            set -euo pipefail
            de_gnome_install
        fi
        ;;
esac
