#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"
source "$ROOT_DIR/script/common/flatpak.sh"

distro_init_repos() {
    REPO_CORE="main, updates, security"
    register_repo "restricted"  "Official"    "Canonical-supported proprietary hardware drivers" 1
    register_repo "universe"    "Official"    "Community-maintained free & open-source software" 1
    register_repo "multiverse"  "Official"    "Copyright/patent-restricted software & codecs" 1
    register_repo "backports"   "Official"    "Newer backported packages (${DISTRO_CODENAME:-noble}-backports)" 0
    register_repo "vscodium"    "Third-Party" "VSCodium official Ubuntu APT repository" 1
    register_repo "tailscale"   "Third-Party" "Tailscale official VPN repository" 1
    register_repo "purge-snapd" "System"      "Purge Snapd completely & block via APT pinning" 1
    register_repo "flathub"     "Universal"   "Flathub Flatpak application repository" 1
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
    fi

    if repo_enabled "restricted" || repo_enabled "universe" || repo_enabled "multiverse"; then
        sudo DEBIAN_FRONTEND=noninteractive apt install -y software-properties-common 2>/dev/null || true
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

    if repo_enabled "backports" && [ -n "$codename" ]; then
        local u_comps="main"
        if repo_enabled "restricted"; then u_comps="$u_comps restricted"; fi
        if repo_enabled "universe";   then u_comps="$u_comps universe"; fi
        if repo_enabled "multiverse"; then u_comps="$u_comps multiverse"; fi
        if ! grep -qs "${codename}-backports" /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources 2>/dev/null; then
            echo "deb http://archive.ubuntu.com/ubuntu ${codename}-backports ${u_comps}" \
                | sudo tee /etc/apt/sources.list.d/ubuntu-backports.list > /dev/null
        fi
    fi

    if repo_enabled "vscodium"; then
        ensure_vscodium_apt_repo
    fi

    if repo_enabled "tailscale" && [ ! -f /etc/apt/sources.list.d/tailscale.list ]; then
        echo "==> Adding Tailscale APT repository..."
        sudo mkdir -p /usr/share/keyrings
        curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${codename}.noarmor.gpg" 2>/dev/null \
            | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg > /dev/null || true
        curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${codename}.tailscale-keyring.list" 2>/dev/null \
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
