#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"
source "$ROOT_DIR/script/common/flatpak.sh"

distro_init_repos() {
    REPO_CORE="main, main-updates, debian-security"
    local codename="${DISTRO_CODENAME:-trixie}"
    register_repo "contrib"           "Official"    "DFSG-free packages that depend on non-free software" "$(repo_active_flag is_apt_component_active 'contrib')"           1
    register_repo "non-free"          "Official"    "Proprietary software & drivers (NVIDIA, etc.)"       "$(repo_active_flag is_apt_component_active 'non-free')"          1
    register_repo "non-free-firmware" "Official"    "Hardware firmware & CPU microcode binaries"          "$(repo_active_flag is_apt_component_active 'non-free-firmware')" 1
    register_repo "backports"         "Official"    "Newer backported packages (${codename}-backports)"   "$(repo_active_flag is_apt_repo_active "${codename}-backports")"   0
    register_repo "vscodium"          "Third-Party" "VSCodium official Debian APT repository"             "$(repo_active_flag is_apt_repo_active 'vscodium')"               1
    register_repo "tailscale"         "Third-Party" "Tailscale official VPN repository"                   "$(repo_active_flag is_apt_repo_active 'tailscale')"              1
    register_repo "flathub"           "Universal"   "Flathub Flatpak application repository"              "$(repo_active_flag is_flathub_active)"                           1
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
        if ! is_apt_repo_active "${codename}-backports"; then
            echo "deb http://deb.debian.org/debian ${codename}-backports ${comps}" \
                | sudo tee /etc/apt/sources.list.d/debian-backports.list > /dev/null
        elif [ -f /etc/apt/sources.list.d/debian-backports.list ]; then
            sudo sed -i -E "/^[[:space:]]*deb(-src)?[[:space:]]/ s/\bmain([[:space:]]+(contrib|non-free|non-free-firmware))*\b/${comps}/g" /etc/apt/sources.list.d/debian-backports.list
        fi
    else
        sudo rm -f /etc/apt/sources.list.d/debian-backports.list
        if [ -f /etc/apt/sources.list ]; then
            sudo sed -i -E "/^[[:space:]]*deb(-src)?[[:space:]].*${codename}-backports/ s/^/# /" /etc/apt/sources.list
        fi
        if [ -f /etc/apt/sources.list.d/debian.sources ]; then
            sudo sed -i -E "/^Suites:/ { s/\b${codename}-backports\b//g; s/[[:space:]]+/ /g; s/[[:space:]]+$//; }" /etc/apt/sources.list.d/debian.sources
        fi
    fi

    if repo_enabled "vscodium"; then
        ensure_vscodium_apt_repo
    else
        disable_vscodium_apt_repo
    fi

    if repo_enabled "tailscale"; then
        if ! is_apt_repo_active "tailscale"; then
            echo "==> Adding Tailscale APT repository..."
            sudo mkdir -p /usr/share/keyrings
            curl -fsSL "https://pkgs.tailscale.com/stable/debian/${codename}.noarmor.gpg" 2>/dev/null \
                | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg > /dev/null || true
            curl -fsSL "https://pkgs.tailscale.com/stable/debian/${codename}.tailscale-keyring.list" 2>/dev/null \
                | sudo tee /etc/apt/sources.list.d/tailscale.list > /dev/null || true
        fi
    elif [ -f /etc/apt/sources.list.d/tailscale.list ] || [ -f /etc/apt/sources.list.d/tailscale.sources ]; then
        echo "==> Disabling Tailscale APT repository..."
        sudo rm -f /etc/apt/sources.list.d/tailscale.list /etc/apt/sources.list.d/tailscale.sources
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
