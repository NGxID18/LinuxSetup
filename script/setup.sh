#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"
detect_linux_env

echo "=================================================="
echo "         LINUX PROVISIONING SETUP MENU            "
echo "=================================================="

echo -e "\n[1/7] Configure Repositories:"
source "$DISTRO_DIR/repo.sh" --menu

echo -e "\n[2/7] Configure GPU Driver:"
source "$DISTRO_DIR/driver.sh" --menu

echo -e "\n[3/7] Install minimal GNOME Desktop & Wallpapers?"
if ! read -rp "Choice [Y/n]: " INSTALL_GNOME; then
    INSTALL_GNOME="Y"
fi
INSTALL_GNOME="${INSTALL_GNOME:-Y}"

echo -e "\n[4/7] Install Cockpit Web Console?"
if ! read -rp "Choice [Y/n]: " INSTALL_COCKPIT; then
    INSTALL_COCKPIT="Y"
fi
INSTALL_COCKPIT="${INSTALL_COCKPIT:-Y}"

echo -e "\n[5/7] Configure Applications (Native / AUR / Flatpak):"
source "$DISTRO_DIR/apps.sh" --menu

echo -e "\n[6/7] Configure CLI (Fastfetch, Kitty, Zsh)?"
if ! read -rp "Choice [Y/n]: " INSTALL_CLI; then
    INSTALL_CLI="Y"
fi
INSTALL_CLI="${INSTALL_CLI:-Y}"

echo -e "\n[7/7] Configure zRAM Swap (zstd compression):"
echo "  1) 32 GB (32768 MB)"
echo "  2) 16 GB (16384 MB)"
echo "  3) 8 GB  (8192 MB)"
echo "  4) 4 GB  (4096 MB)"
echo "  5) Skip"
while true; do
    if ! read -rp "Choice [1-5, default 5]: " ZRAM_CHOICE; then
        ZRAM_CHOICE="5"
        ZRAM_SIZE=""
        break
    fi
    ZRAM_CHOICE="${ZRAM_CHOICE:-5}"
    case "$ZRAM_CHOICE" in
        1) ZRAM_SIZE=32768; break ;;
        2) ZRAM_SIZE=16384; break ;;
        3) ZRAM_SIZE=8192; break ;;
        4) ZRAM_SIZE=4096; break ;;
        5) ZRAM_SIZE=""; break ;;
        *) echo "  -> Invalid input. Please enter 1, 2, 3, 4, or 5." ;;
    esac
done

export GPU_CHOICE NVD_TUNE AUR_HELPER INSTALL_GNOME INSTALL_COCKPIT INSTALL_APPS SELECTED_APPS EXTRA_NATIVE_PKGS EXTRA_FLATPAK_PKGS APPS_MENU_DONE INSTALL_CLI ZRAM_CHOICE ZRAM_SIZE
