#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"

de_gnome_info() {
    DE_LABEL="GNOME (Minimal Desktop, GDM, Extensions & Wallpapers)"
}

de_gnome_install() {
    echo "==> Installing minimal GNOME desktop on openSUSE Leap..."
    sudo zypper --non-interactive remove -y patterns-base-minimal_base-conflicts 2>/dev/null || true
    sudo zypper --non-interactive --gpg-auto-import-keys install -y --no-recommends \
        -t pattern gnome_basic 2>/dev/null \
        || sudo zypper --non-interactive --gpg-auto-import-keys install -y --no-recommends \
            patterns-gnome-gnome_basic 2>/dev/null || true

    sudo zypper --non-interactive --gpg-auto-import-keys install -y --no-recommends \
        gdm gnome-shell gnome-control-center nautilus file-roller \
        gnome-text-editor gnome-calculator gnome-tweaks gnome-extensions-app \
        xdg-desktop-portal-gnome glib2-tools libgtop-2_0-0 sensors 2>/dev/null \
        || sudo zypper --non-interactive --gpg-auto-import-keys install -y --no-recommends \
            gdm gnome-shell gnome-control-center nautilus file-roller gnome-text-editor \
            gnome-calculator gnome-tweaks gnome-extensions-app xdg-desktop-portal-gnome glib2-tools

    sudo systemctl enable gdm 2>/dev/null || sudo systemctl enable display-manager 2>/dev/null || true
    "$ROOT_DIR/script/common/gnome-config.sh"
}

de_gnome_verify() {
    register_expected_native \
        gdm gnome-shell gnome-control-center nautilus file-roller \
        gnome-text-editor gnome-calculator gnome-tweaks gnome-extensions-app \
        glib2-tools "libgtop-2_0-0|typelib-1_0-GTop-2_0"
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
