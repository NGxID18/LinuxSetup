#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/NGxID18/LinuxSetup.git"
TARBALL_URL="https://github.com/NGxID18/LinuxSetup/archive/refs/heads/main.tar.gz"

if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    echo "ERROR: Do not run install.sh as root or with sudo!" >&2
    echo "The script will prompt for administrator privileges when required." >&2
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

    chmod -R +x "$CLEANUP_DIR/install.sh" "$CLEANUP_DIR/script" 2>/dev/null || true
    "$CLEANUP_DIR/install.sh" "$@" </dev/tty
    exit $?
fi

if [ ! -t 0 ] && [ -e /dev/tty ]; then
    exec </dev/tty
fi

chmod -R +x "$ROOT_DIR/script" 2>/dev/null || true
export ROOT_DIR

source "$ROOT_DIR/script/lib/tui.sh"
detect_linux_env

echo "==> Requesting administrator privileges..."
sudo -v
while true; do
    sudo -n -v
    sleep 60
    kill -0 "$$" 2>/dev/null || exit
done 2>/dev/null &
SUDO_PID=$!
trap 'kill "$SUDO_PID" 2>/dev/null || true' EXIT INT TERM

source "$ROOT_DIR/script/setup.sh"

echo -e "\n==> Starting installation (Package Manager: $PKG | Distro: $DISTRO ${DISTRO_VER})..."

"$DISTRO_DIR/repo.sh"
"$DISTRO_DIR/driver.sh"

if [[ "${INSTALL_GNOME:-Y}" =~ ^[Yy]$ ]]; then
    "$DISTRO_DIR/apps.sh" --gnome
fi

if [[ "${INSTALL_COCKPIT:-Y}" =~ ^[Yy]$ ]]; then
    "$DISTRO_DIR/apps.sh" --cockpit
fi

if [[ "${INSTALL_APPS:-Y}" =~ ^[Yy]$ ]]; then
    "$DISTRO_DIR/apps.sh"
fi

if [ "${ZRAM_CHOICE:-5}" != "5" ] && [ -n "${ZRAM_SIZE:-}" ]; then
    "$DISTRO_DIR/apps.sh" --zram
fi

if [[ "${INSTALL_CLI:-Y}" =~ ^[Yy]$ ]]; then
    "$DISTRO_DIR/apps.sh" --cli
fi

"$ROOT_DIR/script/verify.sh"

echo -e "\n==> Provisioning completed successfully!"
