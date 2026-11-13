#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"
source "$ROOT_DIR/script/common/flatpak.sh"

distro_init_repos() {
    REPO_CORE="baseos, appstream"
    register_repo "extras"            "Official"    "Supplementary release packages (required for EPEL/ELRepo)" 1
    register_repo "crb"               "Official"    "CodeReady Builder (developer libraries & headers)" 1
    register_repo "epel"              "Community"   "Extra Packages for Enterprise Linux (epel-release)" 1
    register_repo "rpmfusion-free"    "Community"   "RPM Fusion Free (FFmpeg, VLC, open-source multimedia)" 1
    register_repo "rpmfusion-nonfree" "Community"   "RPM Fusion Nonfree (NVIDIA drivers, codecs, Steam)" 1
    register_repo "plus"              "Official"    "AlmaLinux/EL Plus extended packages" 0
    register_repo "synergy"           "Community"   "AlmaLinux Synergy community packages" 0
    register_repo "elrepo"            "Third-Party" "ELRepo hardware drivers & mainline/LTS kernels" 0
    register_repo "vscodium"          "Third-Party" "VSCodium official RPM repository" 1
    register_repo "tailscale"         "Third-Party" "Tailscale official VPN repository" 1
    register_repo "flathub"           "Universal"   "Flathub Flatpak application repository" 1
}

distro_apply_repos() {
    detect_linux_env
    if [ "${REPO_MENU_DONE:-0}" != "1" ]; then
        run_repo_menu
    fi

    echo "==> Configuring AlmaLinux/EL DNF repositories & updating system..."
    local rhel_ver
    rhel_ver="$(rpm -E %rhel)"

    if repo_enabled "extras"; then
        sudo dnf config-manager setopt "extras.enabled=1" 2>/dev/null \
            || sudo dnf config-manager --set-enabled extras 2>/dev/null || true
    fi
    if repo_enabled "crb"; then
        sudo dnf config-manager setopt "crb.enabled=1" 2>/dev/null \
            || sudo dnf config-manager --set-enabled crb 2>/dev/null || true
    fi
    if repo_enabled "epel"; then
        sudo dnf install -y epel-release || true
    fi
    if repo_enabled "rpmfusion-free"; then
        sudo dnf install -y --nogpgcheck \
            "https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-${rhel_ver}.noarch.rpm" || true
    fi
    if repo_enabled "rpmfusion-nonfree"; then
        sudo dnf install -y --nogpgcheck \
            "https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-${rhel_ver}.noarch.rpm" || true
    fi
    if repo_enabled "plus"; then
        sudo dnf config-manager setopt "plus.enabled=1" 2>/dev/null \
            || sudo dnf config-manager --set-enabled plus 2>/dev/null || true
    fi
    if repo_enabled "synergy"; then
        sudo dnf install -y almalinux-release-synergy 2>/dev/null \
            || sudo dnf install -y "https://repo.almalinux.org/almalinux/almalinux-release-synergy-latest-${rhel_ver}.noarch.rpm" 2>/dev/null || true
    fi
    if repo_enabled "elrepo"; then
        sudo dnf install -y "https://www.elrepo.org/elrepo-release-${rhel_ver}.el${rhel_ver}.elrepo.noarch.rpm" 2>/dev/null \
            || sudo dnf install -y elrepo-release 2>/dev/null || true
    fi

    sudo dnf config-manager setopt "*-testing.enabled=0" 2>/dev/null \
        || sudo dnf config-manager --set-disabled "*-testing" 2>/dev/null || true

    if repo_enabled "vscodium"; then
        ensure_vscodium_dnf_repo
    fi

    if repo_enabled "tailscale" && [ ! -f /etc/yum.repos.d/tailscale.repo ]; then
        echo "==> Adding Tailscale RPM repository..."
        sudo dnf config-manager addrepo --from-repofile="https://pkgs.tailscale.com/stable/rhel/${rhel_ver}/tailscale.repo" 2>/dev/null \
            || curl -fsSL "https://pkgs.tailscale.com/stable/rhel/${rhel_ver}/tailscale.repo" 2>/dev/null \
                | sudo tee /etc/yum.repos.d/tailscale.repo > /dev/null || true
    fi

    sudo dnf upgrade --refresh -y
    local -a base_pkgs=(git curl wget unzip tar xz)
    if repo_enabled "flathub"; then
        base_pkgs+=(flatpak)
    fi
    sudo dnf install -y "${base_pkgs[@]}"
    setup_flathub_remote
}

distro_verify_repos() {
    ensure_repo_context
    register_expected_native git curl wget unzip tar xz
    if repo_enabled "flathub"; then
        register_expected_native flatpak
    fi
    if repo_enabled "epel"; then
        register_expected_native epel-release
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
