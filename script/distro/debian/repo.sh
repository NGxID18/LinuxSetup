#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"
source "$ROOT_DIR/script/common/flatpak.sh"

distro_init_repos() {
    REPO_CORE="main, main-updates, debian-security"
    register_repo "contrib"           "Official"    "DFSG-free packages that depend on non-free software" 1
    register_repo "non-free"          "Official"    "Proprietary software & drivers (NVIDIA, etc.)" 1
    register_repo "non-free-firmware" "Official"    "Hardware firmware & CPU microcode binaries" 1
    register_repo "backports"         "Official"    "Newer backported packages (${DISTRO_CODENAME:-trixie}-backports)" 0
    register_repo "vscodium"          "Third-Party" "VSCodium official Debian APT repository" 1
    register_repo "tailscale"         "Third-Party" "Tailscale official VPN repository" 1
    register_repo "flathub"           "Universal"   "Flathub Flatpak application repository" 1
}

distro_apply_repos() {
    detect_linux_env
    if [ "${REPO_MENU_DONE:-0}" != "1" ]; then
        run_repo_menu
    fi

    echo "==> Configuring Debian APT repositories & updating system..."
    sudo apt update -y

    local -a base_pkgs=(ca-certificates gnupg curl wget git unzip tar xz-utils)
    if repo_enabled "flathub"; then
        base_pkgs+=(flatpak)
    fi
    sudo DEBIAN_FRONTEND=noninteractive apt install -y "${base_pkgs[@]}"

    local codename="${DISTRO_CODENAME:-trixie}"
    local comps="main"
    if repo_enabled "contrib"; then comps="$comps contrib"; fi
    if repo_enabled "non-free"; then comps="$comps non-free"; fi
    if repo_enabled "non-free-firmware"; then comps="$comps non-free-firmware"; fi

    if [ -f /etc/apt/sources.list ]; then
        sudo sed -i -E "/^[[:space:]]*deb(-src)?[[:space:]]/ s/\bmain([[:space:]]+(contrib|non-free|non-free-firmware))*\b/${comps}/g" /etc/apt/sources.list
    fi
    if [ -f /etc/apt/sources.list.d/debian.sources ]; then
        sudo sed -i -E "/^Components:/ s/\bmain([[:space:]]+(contrib|non-free|non-free-firmware))*\b/${comps}/g" /etc/apt/sources.list.d/debian.sources
    fi

    if repo_enabled "backports"; then
        if ! grep -qs "${codename}-backports" /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources 2>/dev/null; then
            echo "deb http://deb.debian.org/debian ${codename}-backports ${comps}" \
                | sudo tee /etc/apt/sources.list.d/debian-backports.list > /dev/null
        fi
    fi

    if repo_enabled "vscodium"; then
        ensure_vscodium_apt_repo
    fi

    if repo_enabled "tailscale" && [ ! -f /etc/apt/sources.list.d/tailscale.list ]; then
        echo "==> Adding Tailscale APT repository..."
        sudo mkdir -p /usr/share/keyrings
        curl -fsSL "https://pkgs.tailscale.com/stable/debian/${codename}.noarmor.gpg" 2>/dev/null \
            | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg > /dev/null || true
        curl -fsSL "https://pkgs.tailscale.com/stable/debian/${codename}.tailscale-keyring.list" 2>/dev/null \
            | sudo tee /etc/apt/sources.list.d/tailscale.list > /dev/null || true
    fi

    sudo apt update -y
    sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y
    setup_flathub_remote
}

distro_verify_repos() {
    ensure_repo_context
    register_expected_native ca-certificates gnupg curl wget git unzip tar xz-utils
    if repo_enabled "flathub"; then
        register_expected_native flatpak
    fi
}

case "${1:-}" in
    --init-defaults) init_default_repos ;;
    --menu)          run_repo_menu ;;
    --verify)        distro_verify_repos ;;
    *)
        if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
            set -euo pipefail
            distro_apply_repos
        fi
        ;;
esac
