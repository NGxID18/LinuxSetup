#!/usr/bin/env bash

echo "=================================================="
echo "         LINUX PROVISIONING SETUP MENU            "
echo "=================================================="

AUR_HELPER="paru"
if [ "${PKG:-}" = "pacman" ]; then
    echo -e "\n[Arch] Select AUR Helper:"
    echo "  1) Paru (default)"
    echo "  2) Yay"
    while true; do
        read -rp "Choice [1-2, default 1]: " AUR_CHOICE || AUR_CHOICE="1"
        AUR_CHOICE="${AUR_CHOICE:-1}"
        case "$AUR_CHOICE" in
            1) AUR_HELPER="paru"; break ;;
            2) AUR_HELPER="yay"; break ;;
            *) echo "  -> Invalid input. Please enter 1 or 2." ;;
        esac
    done
fi

echo -e "\n[1/6] Select GPU Driver:"
echo "  1) NVIDIA"
echo "  2) AMD"
echo "  3) Intel"
echo "  4) Skip"
while true; do
    read -rp "Choice [1-4, default 4]: " GPU_CHOICE || GPU_CHOICE="4"
    GPU_CHOICE="${GPU_CHOICE:-4}"
    case "$GPU_CHOICE" in
        [1-4]) break ;;
        *) echo "  -> Invalid input. Please enter 1, 2, 3, or 4." ;;
    esac
done

NVD_TUNE="N"
if [ "$GPU_CHOICE" = "1" ]; then
    read -rp "  -> Apply RTX 5060 power & clock limit (5060tune)? [y/N]: " NVD_TUNE || NVD_TUNE="N"
    NVD_TUNE="${NVD_TUNE:-N}"
fi

echo -e "\n[2/6] Install minimal GNOME Desktop & Wallpapers?"
read -rp "Choice [Y/n]: " INSTALL_GNOME || INSTALL_GNOME="Y"
INSTALL_GNOME="${INSTALL_GNOME:-Y}"

echo -e "\n[3/6] Install Cockpit Web Console?"
read -rp "Choice [Y/n]: " INSTALL_COCKPIT || INSTALL_COCKPIT="Y"
INSTALL_COCKPIT="${INSTALL_COCKPIT:-Y}"

echo -e "\n[4/6] Install Applications (VSCodium, Tailscale, Snapper, Flatpaks)?"
read -rp "Choice [Y/n]: " INSTALL_APPS || INSTALL_APPS="Y"
INSTALL_APPS="${INSTALL_APPS:-Y}"

echo -e "\n[5/6] Configure CLI (Fastfetch, Kitty, Zsh)?"
read -rp "Choice [Y/n]: " INSTALL_CLI || INSTALL_CLI="Y"
INSTALL_CLI="${INSTALL_CLI:-Y}"

echo -e "\n[6/6] Configure zRAM Swap (zstd compression):"
echo "  1) 32 GB (32768 MB)"
echo "  2) 16 GB (16384 MB)"
echo "  3) 8 GB  (8192 MB)"
echo "  4) 4 GB  (4096 MB)"
echo "  5) Skip"
while true; do
    read -rp "Choice [1-5, default 5]: " ZRAM_CHOICE || ZRAM_CHOICE="5"
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

export GPU_CHOICE NVD_TUNE AUR_HELPER INSTALL_GNOME INSTALL_COCKPIT INSTALL_APPS INSTALL_CLI ZRAM_CHOICE ZRAM_SIZE
