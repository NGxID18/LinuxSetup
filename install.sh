#!/usr/bin/env bash
set -e

if [ "$EUID" -eq 0 ]; then
    echo "ERROR: Do not run install.sh with sudo!"
    exit 1
fi

sudo -v
while true; do sudo -n -v; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_PID=$!
trap 'kill "$SUDO_PID" 2>/dev/null || true' EXIT INT TERM

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if command -v apt >/dev/null 2>&1; then
    PKG="apt"
elif command -v dnf >/dev/null 2>&1; then
    PKG="dnf"
elif command -v pacman >/dev/null 2>&1; then
    PKG="pacman"
else
    echo "Unsupported package manager." >&2
    exit 1
fi

export ROOT_DIR PKG

source "$ROOT_DIR/script/setup.sh"

echo -e "\n==> Starting installation (Package Manager: $PKG)..."

echo "==> Installing wallpapers..."
sudo mkdir -p /usr/share/backgrounds/Wallpapers
sudo cp -r "$ROOT_DIR/Wallpapers/." /usr/share/backgrounds/Wallpapers/
sudo chmod -R 755 /usr/share/backgrounds/Wallpapers

"$ROOT_DIR/script/repository.sh"

case "$GPU_CHOICE" in
    1)
        "$ROOT_DIR/script/driver/nvidia/nvidia.sh"
        if [[ "$NVD_TUNE" =~ ^[Yy]$ ]]; then
            "$ROOT_DIR/script/driver/nvidia/5060tune.sh"
        fi
        ;;
    2)
        "$ROOT_DIR/script/driver/amd/amd.sh"
        ;;
    3)
        "$ROOT_DIR/script/driver/intel/intel.sh"
        ;;
esac

if [[ "$INSTALL_GNOME" =~ ^[Yy]$ ]]; then
    "$ROOT_DIR/script/gnome.sh"
fi

if [[ "$INSTALL_COCKPIT" =~ ^[Yy]$ ]]; then
    "$ROOT_DIR/script/cockpit.sh"
fi

if [[ "$INSTALL_APPS" =~ ^[Yy]$ ]]; then
    "$ROOT_DIR/script/apps.sh"
fi

if [[ "$INSTALL_ZRAM" =~ ^[Yy]$ ]]; then
    "$ROOT_DIR/script/zram.sh"
fi

if [[ "$INSTALL_CLI" =~ ^[Yy]$ ]]; then
    "$ROOT_DIR/script/cli/fastfetch.sh"
    "$ROOT_DIR/script/cli/terminal.sh"
    "$ROOT_DIR/script/cli/shell.sh"
fi

echo -e "\n==> Provisioning completed successfully!"
