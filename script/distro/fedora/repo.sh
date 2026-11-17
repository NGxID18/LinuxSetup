#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"
source "$ROOT_DIR/script/common/flatpak.sh"

distro_init_repos() {
    REPO_CORE="fedora, updates"
    register_repo "rpmfusion-free"            "Community"   "RPM Fusion Free (multimedia codecs & FOSS tools)"            "$(repo_active_flag is_dnf_repo_active '^rpmfusion-free(-updates)?$')"      1
    register_repo "rpmfusion-nonfree"         "Community"   "RPM Fusion Nonfree (NVIDIA drivers, Steam, codecs)"          "$(repo_active_flag is_dnf_repo_active '^rpmfusion-nonfree(-updates)?$')"   1
    register_repo "rpmfusion-free-tainted"    "Community"   "RPM Fusion Free Tainted (libdvdcss & patent-restricted FOSS)" "$(repo_active_flag is_dnf_repo_active '^rpmfusion-free-tainted$')"         0
    register_repo "rpmfusion-nonfree-tainted" "Community"   "RPM Fusion Nonfree Tainted (restricted firmware & drivers)"  "$(repo_active_flag is_dnf_repo_active '^rpmfusion-nonfree-tainted$')"      0
    register_repo "fedora-cisco-openh264"     "Official"    "Cisco OpenH264 codec for browsers & GStreamer"              "$(repo_active_flag is_dnf_repo_active '^fedora-cisco-openh264$')"         1
    register_repo "terra"                     "Third-Party" "Fyra Labs Terra rolling community repository"                "$(repo_active_flag is_dnf_repo_active '^terra')"                         0
    register_repo "updates-testing"           "Official"    "Fedora staging updates testing repository (*-testing)"       "$(repo_active_flag is_dnf_repo_active '^updates-testing$')"               0
    register_repo "vscodium"                  "Third-Party" "VSCodium official RPM repository"                            "$(repo_active_flag is_dnf_repo_active '^vscodium$')"                      1
    register_repo "flathub"                   "Universal"   "Flathub Flatpak application repository"                      "$(repo_active_flag is_flathub_active)"                                   1
}

distro_apply_repos() {
    detect_linux_env
    if [ "${REPO_MENU_DONE:-0}" != "1" ]; then
        run_repo_menu
    fi

    echo "==> Configuring Fedora DNF repositories & updating system..."
    local fedora_ver
    fedora_ver="$(rpm -E %fedora)"

    if repo_enabled "rpmfusion-free"; then
        if ! is_dnf_repo_present '^rpmfusion-free$'; then
            sudo dnf install -y \
                "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_ver}.noarch.rpm" || true
        fi
        set_matching_dnf_repos_enabled '^rpmfusion-free(-updates)?$' 1
    else
        set_matching_dnf_repos_enabled '^rpmfusion-free(-updates)?$' 0
    fi

    if repo_enabled "rpmfusion-nonfree"; then
        if ! is_dnf_repo_present '^rpmfusion-nonfree$'; then
            sudo dnf install -y \
                "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_ver}.noarch.rpm" || true
        fi
        set_matching_dnf_repos_enabled '^rpmfusion-nonfree(-updates)?$' 1
    else
        set_matching_dnf_repos_enabled '^rpmfusion-nonfree(-updates)?$' 0
    fi

    if repo_enabled "rpmfusion-free-tainted"; then
        if ! is_dnf_repo_present '^rpmfusion-free-tainted$'; then
            sudo dnf install -y rpmfusion-free-release-tainted 2>/dev/null || true
        fi
        set_matching_dnf_repos_enabled '^rpmfusion-free-tainted$' 1
    else
        set_matching_dnf_repos_enabled '^rpmfusion-free-tainted$' 0
    fi

    if repo_enabled "rpmfusion-nonfree-tainted"; then
        if ! is_dnf_repo_present '^rpmfusion-nonfree-tainted$'; then
            sudo dnf install -y rpmfusion-nonfree-release-tainted 2>/dev/null || true
        fi
        set_matching_dnf_repos_enabled '^rpmfusion-nonfree-tainted$' 1
    else
        set_matching_dnf_repos_enabled '^rpmfusion-nonfree-tainted$' 0
    fi

    if repo_enabled "fedora-cisco-openh264"; then
        set_dnf_repo_enabled "fedora-cisco-openh264" 1
    else
        set_dnf_repo_enabled "fedora-cisco-openh264" 0
    fi

    if repo_enabled "terra"; then
        if ! is_dnf_repo_present '^terra'; then
            sudo dnf install -y --nogpgcheck --repofrompath "terra,https://repos.fyralabs.com/terra${fedora_ver}" terra-release 2>/dev/null \
                || sudo dnf config-manager addrepo --from-repofile=https://github.com/terrapkg/subatomic-repos/raw/main/terra.repo 2>/dev/null || true
        fi
        set_matching_dnf_repos_enabled '^terra(-mesa|-nvidia|-extras)?$' 1
    else
        set_matching_dnf_repos_enabled '^terra' 0
    fi

    if repo_enabled "updates-testing"; then
        set_dnf_repo_enabled "updates-testing" 1
    else
        set_dnf_repo_enabled "*-testing" 0
    fi

    if repo_enabled "vscodium"; then
        ensure_vscodium_dnf_repo
    else
        disable_vscodium_dnf_repo
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
    if repo_enabled "rpmfusion-free"; then
        register_expected_native rpmfusion-free-release
    fi
    if repo_enabled "rpmfusion-nonfree"; then
        register_expected_native rpmfusion-nonfree-release
    fi
    if repo_enabled "rpmfusion-free-tainted"; then
        register_expected_native rpmfusion-free-release-tainted
    fi
    if repo_enabled "rpmfusion-nonfree-tainted"; then
        register_expected_native rpmfusion-nonfree-release-tainted
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
