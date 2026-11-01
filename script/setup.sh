#!/usr/bin/env bash

echo "=================================================="
echo "         LINUX PROVISIONING SETUP MENU            "
echo "=================================================="

echo -e "\n[1/6] Select GPU Driver:"
echo "  1) NVIDIA"
echo "  2) AMD"
echo "  3) Intel"
echo "  4) Skip"
read -rp "Choice [1-4, default 4]: " GPU_CHOICE
GPU_CHOICE="${GPU_CHOICE:-4}"

if [ "$GPU_CHOICE" = "1" ]; then
    read -rp "  -> Apply RTX 5060 power & clock limit (5060tune)? [y/N]: " NVD_TUNE
    NVD_TUNE="${NVD_TUNE:-N}"
fi

echo -e "\n[2/6] Install minimal GNOME Desktop & Wallpapers?"
read -rp "Choice [Y/n]: " INSTALL_GNOME
INSTALL_GNOME="${INSTALL_GNOME:-Y}"

echo -e "\n[3/6] Install Cockpit Web Console?"
read -rp "Choice [Y/n]: " INSTALL_COCKPIT
INSTALL_COCKPIT="${INSTALL_COCKPIT:-Y}"

echo -e "\n[4/6] Install Applications (VSCodium, Tailscale, Snapper, Flatpaks)?"
read -rp "Choice [Y/n]: " INSTALL_APPS
INSTALL_APPS="${INSTALL_APPS:-Y}"

echo -e "\n[5/6] Configure CLI (Fastfetch, Kitty, Zsh)?"
read -rp "Choice [Y/n]: " INSTALL_CLI
INSTALL_CLI="${INSTALL_CLI:-Y}"

echo -e "\n[6/6] Configure zRAM Swap (32GB zstd)?"
read -rp "Choice [y/N]: " INSTALL_ZRAM
INSTALL_ZRAM="${INSTALL_ZRAM:-N}"

export GPU_CHOICE NVD_TUNE INSTALL_GNOME INSTALL_COCKPIT INSTALL_APPS INSTALL_CLI INSTALL_ZRAM

