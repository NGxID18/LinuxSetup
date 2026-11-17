#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"

de_gnome_info() {
    DE_LABEL="GNOME (Minimal Desktop, GDM, Extensions & Wallpapers)"
}

de_gnome_install() {
    echo "==> Installing minimal GNOME desktop on Fedora..."
    sudo dnf install -y \
        gdm gnome-shell gnome-session gnome-settings-daemon gnome-control-center \
        gnome-keyring xdg-desktop-portal-gnome xdg-user-dirs-gtk nautilus file-roller \
        gnome-text-editor gnome-calculator gnome-software gnome-tweaks \
        gnome-extensions-app libgtop2 lm_sensors
    sudo systemctl enable gdm
    "$ROOT_DIR/script/common/gnome-config.sh"
}

de_gnome_verify() {
    register_expected_native \
        gdm gnome-shell gnome-session gnome-settings-daemon gnome-control-center \
        nautilus file-roller gnome-text-editor gnome-calculator \
        gnome-software gnome-tweaks gnome-extensions-app libgtop2 lm_sensors
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
