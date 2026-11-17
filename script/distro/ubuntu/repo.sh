#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"
source "$ROOT_DIR/script/common/flatpak.sh"

distro_init_repos() {
    REPO_CORE="main, updates, security"
    local codename="${DISTRO_CODENAME:-noble}"
    local def_purge_snapd=0
    if [ -f /etc/apt/preferences.d/nosnap.pref ] && ! command -v snap >/dev/null 2>&1; then
        def_purge_snapd=1
    fi

    register_repo "restricted"  "Official"    "Canonical-supported proprietary hardware drivers"      "$(repo_active_flag is_apt_component_active 'restricted')"
    register_repo "universe"    "Official"    "Community-maintained free & open-source software"      "$(repo_active_flag is_apt_component_active 'universe')"
    register_repo "multiverse"  "Official"    "Copyright/patent-restricted software & codecs"         "$(repo_active_flag is_apt_component_active 'multiverse')"
    register_repo "backports"   "Official"    "Newer backported packages (${codename}-backports)"     "$(repo_active_flag is_apt_repo_active "${codename}-backports")"
    register_repo "vscodium"    "Third-Party" "VSCodium official Ubuntu APT repository"               "$(repo_active_flag is_apt_repo_active 'vscodium')"
    register_repo "tailscale"   "Third-Party" "Tailscale official VPN repository"                     "$(repo_active_flag is_apt_repo_active 'tailscale')"
    register_repo "purge-snapd" "System"      "Purge Snapd completely & block via APT pinning"        "$def_purge_snapd"
    register_repo "flathub"     "Universal"   "Flathub Flatpak application repository"                "$(repo_active_flag is_flathub_active)"
}

distro_apply_repos() {
    detect_linux_env
    if [ "${REPO_MENU_DONE:-0}" != "1" ]; then
        run_repo_menu
    fi

    echo "==> Configuring Ubuntu APT repositories & updating system..."
    sudo apt update -y

    local -a base_pkgs=(ca-certificates gnupg curl wget git unzip tar xz-utils)
    if repo_enabled "flathub"; then
        base_pkgs+=(flatpak)
    fi
    sudo DEBIAN_FRONTEND=noninteractive apt install -y "${base_pkgs[@]}"

    local codename="${DISTRO_CODENAME:-noble}"

    if repo_enabled "purge-snapd"; then
        if command -v snap >/dev/null 2>&1 || dpkg-query -W -f='${Status}\n' snapd 2>/dev/null | grep -q "installed"; then
            echo "==> Completely removing and purging Snap from Ubuntu..."
            if command -v snap >/dev/null 2>&1; then
                local s
                for s in $(snap list 2>/dev/null | awk 'NR>1 {print $1}' | grep -vE '^(snapd|core[0-9]*|bare)$' || true); do
                    sudo snap remove --purge "$s" 2>/dev/null || true
                done
                for s in $(snap list 2>/dev/null | awk 'NR>1 {print $1}' || true); do
                    sudo snap remove --purge "$s" 2>/dev/null || true
                done
            fi

            sudo systemctl stop snapd.service snapd.socket snapd.seeded.service 2>/dev/null || true
            sudo systemctl disable snapd.service snapd.socket snapd.seeded.service 2>/dev/null || true

            sudo DEBIAN_FRONTEND=noninteractive apt purge -y snapd gnome-software-plugin-snap 2>/dev/null || true
            sudo apt autoremove --purge -y 2>/dev/null || true
            sudo rm -rf /snap /var/snap /var/lib/snapd /var/cache/snapd /usr/lib/snapd "$HOME/snap"
        fi

        sudo mkdir -p /etc/apt/preferences.d
        sudo tee /etc/apt/preferences.d/nosnap.pref > /dev/null <<'EOF'
Package: snapd
Pin: release *
Pin-Priority: -10
EOF
    elif [ -f /etc/apt/preferences.d/nosnap.pref ]; then
        echo "==> Removing APT Snap block (/etc/apt/preferences.d/nosnap.pref)..."
        sudo rm -f /etc/apt/preferences.d/nosnap.pref
    fi

    local u_comps="main"
    if repo_enabled "restricted"; then u_comps="$u_comps restricted"; fi
    if repo_enabled "universe";   then u_comps="$u_comps universe"; fi
    if repo_enabled "multiverse"; then u_comps="$u_comps multiverse"; fi

    if [ -f /etc/apt/sources.list ]; then
        sudo sed -i -E "/^[[:space:]]*deb(-src)?[[:space:]].*(\/ubuntu|restricted|universe|multiverse)/ s/\bmain([[:space:]]+(restricted|universe|multiverse))*\b/${u_comps}/g" /etc/apt/sources.list
    fi
    if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
        sudo sed -i -E "/^Components:/ s/\bmain([[:space:]]+(restricted|universe|multiverse))*\b/${u_comps}/g" /etc/apt/sources.list.d/ubuntu.sources
    fi

    if repo_enabled "restricted" || repo_enabled "universe" || repo_enabled "multiverse"; then
        sudo DEBIAN_FRONTEND=noninteractive apt install -y software-properties-common 2>/dev/null || true
        if [ ! -f /etc/apt/sources.list.d/ubuntu.sources ] && [ ! -f /etc/apt/sources.list ]; then
            if repo_enabled "restricted"; then
                sudo add-apt-repository -y -n restricted 2>/dev/null || sudo add-apt-repository -y restricted || true
            fi
            if repo_enabled "universe"; then
                sudo add-apt-repository -y -n universe 2>/dev/null || sudo add-apt-repository -y universe || true
            fi
            if repo_enabled "multiverse"; then
                sudo add-apt-repository -y -n multiverse 2>/dev/null || sudo add-apt-repository -y multiverse || true
            fi
        fi
    fi

    if [ -n "$codename" ]; then
        if repo_enabled "backports"; then
            if ! is_apt_repo_active "${codename}-backports"; then
                echo "deb http://archive.ubuntu.com/ubuntu ${codename}-backports ${u_comps}" \
                    | sudo tee /etc/apt/sources.list.d/ubuntu-backports.list > /dev/null
            elif [ -f /etc/apt/sources.list.d/ubuntu-backports.list ]; then
                sudo sed -i -E "/^[[:space:]]*deb(-src)?[[:space:]]/ s/\bmain([[:space:]]+(restricted|universe|multiverse))*\b/${u_comps}/g" /etc/apt/sources.list.d/ubuntu-backports.list
            fi
        else
            sudo rm -f /etc/apt/sources.list.d/ubuntu-backports.list
            if [ -f /etc/apt/sources.list ]; then
                sudo sed -i -E "/^[[:space:]]*deb(-src)?[[:space:]].*${codename}-backports/ s/^/# /" /etc/apt/sources.list
            fi
            if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
                sudo sed -i -E "/^Suites:/ { s/\b${codename}-backports\b//g; s/[[:space:]]+/ /g; s/[[:space:]]+$//; }" /etc/apt/sources.list.d/ubuntu.sources
            fi
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
            curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${codename}.noarmor.gpg" 2>/dev/null \
                | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg > /dev/null || true
            curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${codename}.tailscale-keyring.list" 2>/dev/null \
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
    if repo_enabled "restricted" || repo_enabled "universe" || repo_enabled "multiverse"; then
        register_expected_native software-properties-common
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
