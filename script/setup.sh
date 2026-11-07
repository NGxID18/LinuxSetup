#!/usr/bin/env bash

if [ "${ASSUME_YES:-0}" -eq 1 ]; then
    echo "=================================================="
    echo "   LINUX PROVISIONING SETUP (NON-INTERACTIVE)     "
    echo "=================================================="
    echo "  Applying default provisioning settings (-y)..."
    GPU_CHOICE=4
    NVD_TUNE="N"
    INSTALL_GNOME="Y"
    INSTALL_COCKPIT="Y"
    INSTALL_APPS="Y"
    INSTALL_CLI="Y"
    ZRAM_CHOICE=5
    ZRAM_SIZE=""
    export GPU_CHOICE NVD_TUNE INSTALL_GNOME INSTALL_COCKPIT INSTALL_APPS INSTALL_CLI ZRAM_CHOICE ZRAM_SIZE
    return 0 2>/dev/null || exit 0
fi

echo "=================================================="
echo "         LINUX PROVISIONING SETUP MENU            "
echo "=================================================="

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

export GPU_CHOICE NVD_TUNE INSTALL_GNOME INSTALL_COCKPIT INSTALL_APPS INSTALL_CLI ZRAM_CHOICE ZRAM_SIZE
