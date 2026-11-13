#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"
source "$ROOT_DIR/script/common/flatpak.sh"

distro_init_repos() {
    REPO_CORE="repo-oss, repo-oss-update, sle-update, backports-update"
    register_repo "repo-non-oss"       "Official"    "Non-OSS & Non-OSS Update proprietary repositories" 1
    register_repo "repo-openh264"      "Official"    "Cisco OpenH264 codec repository" 1
    register_repo "packman-essentials" "Community"   "Packman Essentials (core multimedia codecs)" 1
    register_repo "packman-full"       "Community"   "Full Packman repository (all multimedia apps & codecs)" 0
    register_repo "nvidia"             "Third-Party" "Official NVIDIA Leap driver repository" 0
    register_repo "vscodium"           "Third-Party" "VSCodium official RPM repository" 1
    register_repo "tailscale"          "Third-Party" "Tailscale official VPN repository" 1
    register_repo "flathub"            "Universal"   "Flathub Flatpak application repository" 1
}

distro_apply_repos() {
    detect_linux_env
    if [ "${REPO_MENU_DONE:-0}" != "1" ]; then
        run_repo_menu
    fi

    echo "==> Configuring openSUSE Leap repositories & updating system..."

    local repo
    for repo in $(zypper lr -u 2>/dev/null | awk -F'|' '$0 ~ /(cd|dvd|hd):\/\// {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}'); do
        sudo zypper mr -d "$repo" 2>/dev/null || true
    done
    sudo zypper mr -d repo-debug repo-source 2>/dev/null || true

    if repo_enabled "repo-non-oss"; then
        sudo zypper mr -e repo-non-oss repo-non-oss-update 2>/dev/null || true
    else
        sudo zypper mr -d repo-non-oss repo-non-oss-update 2>/dev/null || true
    fi

    if repo_enabled "repo-openh264"; then
        if ! zypper lr 2>/dev/null | grep -qi "openh264"; then
            sudo zypper addrepo --refresh "https://codecs.opensuse.org/openh264/openSUSE_Leap_${DISTRO_VER:-16}" repo-openh264 2>/dev/null \
                || sudo zypper addrepo --refresh https://codecs.opensuse.org/openh264/openSUSE_Leap/ repo-openh264 2>/dev/null || true
        else
            sudo zypper mr -e repo-openh264 2>/dev/null || true
        fi
    fi

    if repo_enabled "packman-full"; then
        if ! zypper lr 2>/dev/null | grep -qi "packman"; then
            sudo zypper addrepo --refresh -p 90 "https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Leap_${DISTRO_VER:-16.0}/" packman 2>/dev/null || true
        fi
    elif repo_enabled "packman-essentials"; then
        if ! zypper lr 2>/dev/null | grep -qi "packman"; then
            sudo zypper addrepo --refresh -p 90 "https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Leap_${DISTRO_VER:-16.0}/Essentials/" packman-essentials 2>/dev/null || true
        fi
    fi

    if repo_enabled "nvidia"; then
        sudo zypper --non-interactive --gpg-auto-import-keys install -y openSUSE-repos-Leap-NVIDIA 2>/dev/null || true
        if ! zypper repos 2>/dev/null | grep -qi "nvidia"; then
            sudo zypper addrepo --refresh 'https://download.nvidia.com/opensuse/leap/$releasever' NVIDIA 2>/dev/null || true
        fi
    fi

    if repo_enabled "vscodium"; then
        ensure_vscodium_zypper_repo
    fi

    if repo_enabled "tailscale" && [ ! -f /etc/zypp/repos.d/tailscale.repo ]; then
        echo "==> Adding Tailscale Zypper repository..."
        curl -fsSL "https://pkgs.tailscale.com/stable/opensuse/leap/${DISTRO_VER:-16.0}/tailscale.repo" 2>/dev/null \
            | sudo tee /etc/zypp/repos.d/tailscale.repo > /dev/null || true
    fi

    sudo zypper --non-interactive --gpg-auto-import-keys refresh
    sudo zypper --non-interactive --gpg-auto-import-keys update -y --auto-agree-with-licenses

    local -a base_pkgs=(git curl wget unzip tar xz)
    if repo_enabled "flathub"; then
        base_pkgs+=(flatpak)
    fi
    sudo zypper --non-interactive --gpg-auto-import-keys install -y "${base_pkgs[@]}"
    setup_flathub_remote
}

distro_verify_repos() {
    ensure_repo_context
    register_expected_native git curl wget unzip tar xz
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
