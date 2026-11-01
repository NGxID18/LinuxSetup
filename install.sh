#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/NGxID18/LinuxSetup.git"
TARBALL_URL="https://github.com/NGxID18/LinuxSetup/archive/refs/heads/main.tar.gz"

if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    echo "ERROR: Do not run install.sh as root or with sudo!" >&2
    exit 1
fi

SCRIPT_PATH="${BASH_SOURCE[0]:-}"
if [ -n "$SCRIPT_PATH" ] && [ -f "$SCRIPT_PATH" ]; then
    ROOT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
else
    ROOT_DIR=""
fi

if [ -z "$ROOT_DIR" ] || [ ! -f "$ROOT_DIR/script/setup.sh" ]; then
    echo "==> Bootstrapping LinuxSetup repository..."
    CLEANUP_DIR="$(mktemp -d /tmp/linuxsetup.XXXXXX)"
    trap 'rm -rf "$CLEANUP_DIR"' EXIT INT TERM

    if command -v git >/dev/null 2>&1; then
        git clone --depth 1 "$REPO_URL" "$CLEANUP_DIR" </dev/null
    elif command -v curl >/dev/null 2>&1; then
        curl -fsSL "$TARBALL_URL" | tar -xz -C "$CLEANUP_DIR" --strip-components=1
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "$TARBALL_URL" | tar -xz -C "$CLEANUP_DIR" --strip-components=1
    else
        echo "ERROR: Neither git, curl, nor wget is available." >&2
        exit 1
    fi

    chmod -R +x "$CLEANUP_DIR/install.sh" "$CLEANUP_DIR/script"
    "$CLEANUP_DIR/install.sh" </dev/tty
    exit $?
fi

if [ ! -t 0 ] && [ -e /dev/tty ]; then
    exec </dev/tty
fi

chmod -R +x "$ROOT_DIR/script"

sudo -v
while true; do
    sudo -n -v
    sleep 60
    kill -0 "$$" 2>/dev/null || exit
done 2>/dev/null &
SUDO_PID=$!
trap 'kill "$SUDO_PID" 2>/dev/null || true' EXIT INT TERM

if command -v apt >/dev/null 2>&1; then
    PKG="apt"
elif command -v dnf >/dev/null 2>&1; then
    PKG="dnf"
elif command -v pacman >/dev/null 2>&1; then
    PKG="pacman"
else
    echo "ERROR: Unsupported package manager (requires apt, dnf, or pacman)." >&2
    exit 1
fi

export ROOT_DIR PKG

source "$ROOT_DIR/script/setup.sh"

echo -e "\n==> Starting installation (Package Manager: $PKG)..."

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
    "$ROOT_DIR/script/DE/gnome/gnome.sh"
fi

if [[ "$INSTALL_COCKPIT" =~ ^[Yy]$ ]]; then
    "$ROOT_DIR/script/apps/cockpit.sh"
fi

if [[ "$INSTALL_APPS" =~ ^[Yy]$ ]]; then
    "$ROOT_DIR/script/apps/main.sh"
fi

if [[ "$INSTALL_ZRAM" =~ ^[Yy]$ ]]; then
    "$ROOT_DIR/script/zram/zram.sh"
fi

if [[ "$INSTALL_CLI" =~ ^[Yy]$ ]]; then
    "$ROOT_DIR/script/cli/fastfetch.sh"
    "$ROOT_DIR/script/cli/terminal.sh"
    "$ROOT_DIR/script/cli/shell.sh"
fi

"$ROOT_DIR/script/verify.sh"

echo -e "\n==> Provisioning completed successfully!"
