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

    chmod -R +x "$CLEANUP_DIR/install.sh" "$CLEANUP_DIR/script"
    "$CLEANUP_DIR/install.sh" "$@" </dev/tty
    exit $?
fi

if [ ! -t 0 ] && [ -e /dev/tty ]; then
    exec </dev/tty
fi

chmod -R +x "$ROOT_DIR/script"

# Detect OS distribution and package manager (Single Source of Truth)
DISTRO_ID="unknown"
DISTRO_LIKE=""
DISTRO_VER=""
if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    DISTRO_ID="${ID:-unknown}"
    DISTRO_LIKE="${ID_LIKE:-}"
    DISTRO_VER="${VERSION_ID:-}"
fi

if command -v apt >/dev/null 2>&1; then
    PKG="apt"
    case "$DISTRO_ID" in
        ubuntu|linuxmint|pop) DISTRO="ubuntu" ;;
        debian)               DISTRO="debian" ;;
        *)
            if [[ "$DISTRO_LIKE" == *ubuntu* ]]; then
                DISTRO="ubuntu"
            else
                DISTRO="debian"
            fi
            ;;
    esac
elif command -v dnf >/dev/null 2>&1; then
    PKG="dnf"
    case "$DISTRO_ID" in
        fedora)                         DISTRO="fedora" ;;
        rhel|rocky|almalinux|centos|ol) DISTRO="rhel" ;;
        *)
            if [ "$(rpm -E %fedora 2>/dev/null)" != "%fedora" ]; then
                DISTRO="fedora"
            else
                DISTRO="rhel"
            fi
            ;;
    esac
elif command -v zypper >/dev/null 2>&1; then
    PKG="zypper"
    case "$DISTRO_ID" in
        *tumbleweed*|*slowroll*) DISTRO="tumbleweed" ;;
        *leap*|*sles*)           DISTRO="leap" ;;
        *)
            if grep -qi "tumbleweed" /etc/os-release 2>/dev/null; then
                DISTRO="tumbleweed"
            else
                DISTRO="leap"
            fi
            ;;
    esac
elif command -v pacman >/dev/null 2>&1; then
    PKG="pacman"
    case "$DISTRO_ID" in
        cachyos) DISTRO="cachyos" ;;
        arch|*)  DISTRO="arch" ;;
    esac
else
    echo "ERROR: Unsupported package manager (requires apt, dnf, zypper, or pacman)." >&2
    exit 1
fi

export ROOT_DIR PKG DISTRO DISTRO_ID DISTRO_VER

# Acquire sudo credential and keep alive in background
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

"$ROOT_DIR/script/repository.sh"

case "${GPU_CHOICE:-4}" in
    1)
        "$ROOT_DIR/script/driver/nvidia/nvidia.sh"
        if [[ "${NVD_TUNE:-N}" =~ ^[Yy]$ ]]; then
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

if [[ "${INSTALL_GNOME:-Y}" =~ ^[Yy]$ ]]; then
    "$ROOT_DIR/script/DE/gnome/gnome.sh"
fi

if [[ "${INSTALL_COCKPIT:-Y}" =~ ^[Yy]$ ]]; then
    "$ROOT_DIR/script/apps/cockpit.sh"
fi

if [[ "${INSTALL_APPS:-Y}" =~ ^[Yy]$ ]]; then
    "$ROOT_DIR/script/apps/main.sh"
fi

if [ "${ZRAM_CHOICE:-5}" != "5" ] && [ -n "${ZRAM_SIZE:-}" ]; then
    "$ROOT_DIR/script/zram/zram.sh"
fi

if [[ "${INSTALL_CLI:-Y}" =~ ^[Yy]$ ]]; then
    "$ROOT_DIR/script/cli/fastfetch.sh"
    "$ROOT_DIR/script/cli/terminal.sh"
    "$ROOT_DIR/script/cli/shell.sh"
fi

"$ROOT_DIR/script/verify.sh"

echo -e "\n==> Provisioning completed successfully!"
