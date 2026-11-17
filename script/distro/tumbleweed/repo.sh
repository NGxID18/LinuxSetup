#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"
source "$ROOT_DIR/script/common/flatpak.sh"

distro_init_repos() {
    REPO_CORE="repo-oss, repo-update"
    local def_packman_ess=0 def_packman_full=0
    if is_zypper_repo_active 'packman.*essentials|essentials.*packman' 'debug|source'; then
        def_packman_ess=1
    elif is_zypper_repo_active 'packman' 'essentials|debug|source'; then
        def_packman_full=1
    fi

    local def_nvidia rec_nvidia=0
    def_nvidia="$(repo_active_flag is_zypper_repo_active 'nvidia' 'debug|source')"
    if [ "$def_nvidia" -eq 1 ] || has_nvidia_gpu; then
        rec_nvidia=1
    fi

    register_repo "repo-non-oss"       "Official"    "Non-OSS proprietary packages & firmware"                "$(repo_active_flag is_zypper_repo_active 'non-oss' 'debug|source')"  1
    register_repo "repo-openh264"      "Official"    "Cisco OpenH264 codec repository"                        "$(repo_active_flag is_zypper_repo_active 'openh264' 'debug|source')" 1
    register_repo "packman-essentials" "Community"   "Packman Essentials (core multimedia codecs)"            "$def_packman_ess"                                                    1
    register_repo "packman-full"       "Community"   "Full Packman repository (all multimedia apps & codecs)" "$def_packman_full"                                                   0
    register_repo "nvidia"             "Third-Party" "Official NVIDIA Tumbleweed driver repository"           "$def_nvidia"                                                         "$rec_nvidia"
    register_repo "vscodium"           "Third-Party" "VSCodium official RPM repository"                       "$(repo_active_flag is_zypper_repo_active 'vscodium' 'debug|source')" 1
    register_repo "flathub"            "Universal"   "Flathub Flatpak application repository"                 "$(repo_active_flag is_flathub_active)"                               1
}

distro_apply_repos() {
    detect_linux_env
    if [ "${REPO_MENU_DONE:-0}" != "1" ]; then
        run_repo_menu
    fi

    echo "==> Configuring openSUSE Tumbleweed repositories & updating system..."

    local repo
    for repo in $(zypper lr -u 2>/dev/null | awk -F'|' '$0 ~ /(cd|dvd|hd):\/\// {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}'); do
        sudo zypper mr -d "$repo" 2>/dev/null || true
    done
    sudo zypper mr -d repo-debug repo-source 2>/dev/null || true

    if repo_enabled "repo-non-oss"; then
        zypper_set_matching_repos_enabled 'non-oss' e 'debug|source'
    else
        zypper_set_matching_repos_enabled 'non-oss' d 'debug|source'
    fi

    if repo_enabled "repo-openh264"; then
        if ! zypper lr -u 2>/dev/null | grep -qi "openh264"; then
            sudo zypper addrepo --refresh https://codecs.opensuse.org/openh264/openSUSE_Tumbleweed repo-openh264 2>/dev/null || true
        else
            zypper_set_matching_repos_enabled 'openh264' e 'debug|source'
        fi
    else
        zypper_set_matching_repos_enabled 'openh264' d 'debug|source'
    fi

    if repo_enabled "packman-full"; then
        zypper_set_matching_repos_enabled 'packman.*essentials|essentials.*packman' d 'debug|source'
        if ! zypper lr -u 2>/dev/null | grep -i "packman" | grep -qiEv "essentials|debug|source"; then
            sudo zypper addrepo --refresh -p 90 https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/ packman 2>/dev/null || true
        fi
        zypper_set_matching_repos_enabled 'packman' e 'essentials|debug|source'
    elif repo_enabled "packman-essentials"; then
        zypper_set_matching_repos_enabled 'packman' d 'essentials|debug|source'
        if ! zypper lr -u 2>/dev/null | grep -iE "packman.*essentials|essentials.*packman" | grep -qiEv "debug|source"; then
            sudo zypper addrepo --refresh -p 90 https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/Essentials/ packman-essentials 2>/dev/null || true
        fi
        zypper_set_matching_repos_enabled 'packman.*essentials|essentials.*packman' e 'debug|source'
    else
        zypper_set_matching_repos_enabled 'packman' d 'debug|source'
    fi

    if repo_enabled "nvidia"; then
        if ! zypper lr -u 2>/dev/null | grep -qi "nvidia"; then
            sudo zypper --non-interactive --gpg-auto-import-keys install -y openSUSE-repos-Tumbleweed-NVIDIA 2>/dev/null || true
            if ! zypper repos 2>/dev/null | grep -qi "nvidia"; then
                sudo zypper addrepo --refresh https://download.nvidia.com/opensuse/tumbleweed NVIDIA 2>/dev/null || true
            fi
        fi
        zypper_set_matching_repos_enabled 'nvidia' e 'debug|source'
    else
        zypper_set_matching_repos_enabled 'nvidia' d 'debug|source'
    fi

    if repo_enabled "vscodium"; then
        ensure_vscodium_zypper_repo
    else
        disable_vscodium_zypper_repo
    fi

    sudo zypper --non-interactive --gpg-auto-import-keys refresh
    sudo zypper --non-interactive --gpg-auto-import-keys dist-upgrade -y --auto-agree-with-licenses

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
