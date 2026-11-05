#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/NGxID18/LinuxSetup.git"
TARBALL_URL="https://github.com/NGxID18/LinuxSetup/archive/refs/heads/Cockpit.tar.gz"

if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    echo "ERROR: Do not run install.sh as root or with sudo!" >&2
    echo "The script will prompt for sudo when necessary." >&2
    exit 1
fi

SCRIPT_PATH="${BASH_SOURCE[0]:-}"
if [ -n "$SCRIPT_PATH" ] && [ -f "$SCRIPT_PATH" ]; then
    ROOT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
else
    ROOT_DIR=""
fi

if [ -z "$ROOT_DIR" ] || [ ! -f "$ROOT_DIR/script/cockpit.sh" ]; then
    echo "==> Bootstrapping Cockpit installer (branch: Cockpit)..."
    CLEANUP_DIR="$(mktemp -d /tmp/cockpit-installer.XXXXXX)"
    trap 'rm -rf "$CLEANUP_DIR"' EXIT INT TERM

    if command -v git >/dev/null 2>&1; then
        git clone --depth 1 -b Cockpit "$REPO_URL" "$CLEANUP_DIR" </dev/null
    elif command -v curl >/dev/null 2>&1; then
        curl -fsSL "$TARBALL_URL" | tar -xz -C "$CLEANUP_DIR" --strip-components=1
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "$TARBALL_URL" | tar -xz -C "$CLEANUP_DIR" --strip-components=1
    else
        echo "ERROR: Neither git, curl, nor wget is available." >&2
        exit 1
    fi

    chmod -R +x "$CLEANUP_DIR/install.sh" "$CLEANUP_DIR/script"
    "$CLEANUP_DIR/install.sh" "$@" </dev/tty
    exit $?
fi

# Check if non-interactive argument was supplied
ASSUME_YES=0
for arg in "$@"; do
    if [ "$arg" = "-y" ] || [ "$arg" = "--yes" ]; then
        ASSUME_YES=1
        break
    fi
done

if [ "$ASSUME_YES" -eq 0 ] && [ ! -t 0 ] && [ -e /dev/tty ]; then
    exec </dev/tty
fi

chmod -R +x "$ROOT_DIR/script"

# Package manager detection
if command -v apt >/dev/null 2>&1; then
    PKG="apt"
elif command -v dnf >/dev/null 2>&1; then
    PKG="dnf"
elif command -v zypper >/dev/null 2>&1; then
    PKG="zypper"
elif command -v pacman >/dev/null 2>&1; then
    PKG="pacman"
else
    echo "ERROR: Unsupported package manager (requires apt, dnf, zypper, or pacman)." >&2
    exit 1
fi

export ROOT_DIR PKG

echo "=================================================="
echo "        COCKPIT WEB CONSOLE AUTO-INSTALLER        "
echo "=================================================="
echo "Package Manager: $PKG"
echo "Included Components:"
echo " - Cockpit Core (Web Console, System, Bridge)"
echo " - Storage Management (cockpit-storaged, udisks2)"
echo " - Network Management (cockpit-networkmanager)"
echo " - Security Integration (cockpit-selinux on Fedora/RHEL)"
echo " - Service Activation (cockpit.socket)"
echo " - Firewall Configuration (Port 9090)"
echo "=================================================="

if [ "$ASSUME_YES" -eq 0 ]; then
    read -rp "Proceed with installation? [Y/n]: " CONFIRM
    CONFIRM="${CONFIRM:-Y}"
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "Installation aborted by user."
        exit 0
    fi
fi

# Acquire sudo credential and keep alive in background
echo -e "\n==> Requesting administrator privileges..."
sudo -v
while true; do
    sudo -n -v
    sleep 60
    kill -0 "$$" 2>/dev/null || exit
done 2>/dev/null &
SUDO_PID=$!
trap 'kill "$SUDO_PID" 2>/dev/null || true' EXIT INT TERM

echo -e "\n==> Starting Cockpit Setup..."

"$ROOT_DIR/script/repository.sh"
"$ROOT_DIR/script/cockpit.sh"
"$ROOT_DIR/script/verify.sh"

echo -e "\n==> Cockpit installation completed successfully!"
