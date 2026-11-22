#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"
source "$ROOT_DIR/script/common/flatpak.sh"

_EL_EXTRAS_RE='^(extras|extras-common|almalinux-extras|rocky-extras)$'
_EL_CRB_RE='^(crb|powertools|almalinux-crb|rocky-crb|codeready-builder-for-rhel-.*-rpms|ol[0-9]+_codeready_builder)$'
_EL_PLUS_RE='^(plus|almalinux-plus|rocky-plus|centosplus)$'
_EL_SYNERGY_RE='^(synergy|almalinux-synergy)$'

distro_init_repos() {
    case "${DISTRO_ID:-}" in
        rhel) REPO_CORE="rhel-baseos, rhel-appstream" ;;
        ol)   REPO_CORE="ol-baseos, ol-appstream" ;;
        *)    REPO_CORE="baseos, appstream" ;;
    esac

    if { [ "${DISTRO_ID:-}" != "rhel" ] && [ "${DISTRO_ID:-}" != "ol" ]; } || is_dnf_repo_present "$_EL_EXTRAS_RE"; then
        register_repo "extras" "Official" "Supplementary release packages (required for EPEL/ELRepo)" "$(repo_active_flag is_dnf_repo_active "$_EL_EXTRAS_RE")" 1
    fi
    register_repo "crb"               "Official"    "CodeReady Builder (developer libraries & headers)"          "$(repo_active_flag is_dnf_repo_active "$_EL_CRB_RE")"                  1
    register_repo "epel"              "Community"   "Extra Packages for Enterprise Linux (epel-release)"         "$(repo_active_flag is_dnf_repo_active '^epel$')"                         1
    register_repo "rpmfusion-free"    "Community"   "RPM Fusion Free (FFmpeg, VLC, open-source multimedia)"      "$(repo_active_flag is_dnf_repo_active '^rpmfusion-free(-updates)?$')"    1
    register_repo "rpmfusion-nonfree" "Community"   "RPM Fusion Nonfree (NVIDIA drivers, codecs, Steam)"         "$(repo_active_flag is_dnf_repo_active '^rpmfusion-nonfree(-updates)?$')" 1
    if { [ "${DISTRO_ID:-}" != "rhel" ] && [ "${DISTRO_ID:-}" != "ol" ]; } || is_dnf_repo_present "$_EL_PLUS_RE"; then
        register_repo "plus" "Official" "Enterprise Linux Plus extended packages" "$(repo_active_flag is_dnf_repo_active "$_EL_PLUS_RE")" 0
    fi
    if [ "${DISTRO_ID:-}" = "almalinux" ] || is_dnf_repo_present "$_EL_SYNERGY_RE"; then
        register_repo "synergy" "Community" "AlmaLinux Synergy pre-EPEL community packages" "$(repo_active_flag is_dnf_repo_active "$_EL_SYNERGY_RE")" 0
    fi
    register_repo "elrepo"            "Third-Party" "ELRepo hardware drivers & mainline/LTS kernels"             "$(repo_active_flag is_dnf_repo_active '^elrepo$')"                       0
    register_repo "vscodium"          "Third-Party" "VSCodium official RPM repository"                           "$(repo_active_flag is_dnf_repo_active '^vscodium$')"                     1
    register_repo "tailscale"         "Third-Party" "Tailscale official VPN repository"                          "$(repo_active_flag is_dnf_repo_active '^tailscale')"                     1
    register_repo "flathub"           "Universal"   "Flathub Flatpak application repository"                     "$(repo_active_flag is_flathub_active)"                                   1
}

distro_apply_repos() {
    detect_linux_env
    if [ "${REPO_MENU_DONE:-0}" != "1" ]; then
        run_repo_menu
    fi

    echo "==> Configuring Enterprise Linux DNF repositories & updating system..."
    local rhel_ver arch
    rhel_ver="$(rpm -E %rhel)"
    arch="$(uname -m)"

    if is_dnf_repo_present "$_EL_EXTRAS_RE"; then
        if repo_enabled "extras"; then
            set_matching_dnf_repos_enabled "$_EL_EXTRAS_RE" 1
        else
            set_matching_dnf_repos_enabled "$_EL_EXTRAS_RE" 0
        fi
    fi

    if repo_enabled "crb"; then
        if [ "${DISTRO_ID:-}" = "rhel" ] && command -v subscription-manager >/dev/null 2>&1; then
            sudo subscription-manager repos --enable="codeready-builder-for-rhel-${rhel_ver}-${arch}-rpms" 2>/dev/null || true
        fi
        set_matching_dnf_repos_enabled "$_EL_CRB_RE" 1
    else
        if [ "${DISTRO_ID:-}" = "rhel" ] && command -v subscription-manager >/dev/null 2>&1; then
            sudo subscription-manager repos --disable="codeready-builder-for-rhel-${rhel_ver}-${arch}-rpms" 2>/dev/null || true
        fi
        set_matching_dnf_repos_enabled "$_EL_CRB_RE" 0
    fi

    if repo_enabled "epel"; then
        if ! is_dnf_repo_present '^epel$'; then
            sudo dnf install -y epel-release 2>/dev/null \
                || sudo dnf install -y "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${rhel_ver}.noarch.rpm" || true
        fi
        set_matching_dnf_repos_enabled '^epel(-cisco-openh264)?$' 1
    else
        set_matching_dnf_repos_enabled '^epel' 0
    fi

    if repo_enabled "rpmfusion-free"; then
        if ! is_dnf_repo_present '^rpmfusion-free'; then
            sudo dnf install -y --nogpgcheck \
                "https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-${rhel_ver}.noarch.rpm" || true
        fi
        set_matching_dnf_repos_enabled '^rpmfusion-free(-updates)?$' 1
    else
        set_matching_dnf_repos_enabled '^rpmfusion-free(-updates)?$' 0
    fi

    if repo_enabled "rpmfusion-nonfree"; then
        if ! is_dnf_repo_present '^rpmfusion-nonfree'; then
            sudo dnf install -y --nogpgcheck \
                "https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-${rhel_ver}.noarch.rpm" || true
        fi
        set_matching_dnf_repos_enabled '^rpmfusion-nonfree(-updates)?$' 1
    else
        set_matching_dnf_repos_enabled '^rpmfusion-nonfree(-updates)?$' 0
    fi

    if is_dnf_repo_present "$_EL_PLUS_RE"; then
        if repo_enabled "plus"; then
            set_matching_dnf_repos_enabled "$_EL_PLUS_RE" 1
        else
            set_matching_dnf_repos_enabled "$_EL_PLUS_RE" 0
        fi
    fi

    if repo_enabled "synergy"; then
        if ! is_dnf_repo_present "$_EL_SYNERGY_RE"; then
            sudo dnf install -y almalinux-release-synergy 2>/dev/null \
                || sudo dnf install -y "https://repo.almalinux.org/almalinux/almalinux-release-synergy-latest-${rhel_ver}.noarch.rpm" 2>/dev/null || true
        fi
        set_matching_dnf_repos_enabled "$_EL_SYNERGY_RE" 1
    elif is_dnf_repo_present "$_EL_SYNERGY_RE"; then
        set_matching_dnf_repos_enabled "$_EL_SYNERGY_RE" 0
    fi

    if repo_enabled "elrepo"; then
        if ! is_dnf_repo_present '^elrepo$'; then
            sudo dnf install -y "https://www.elrepo.org/elrepo-release-${rhel_ver}.el${rhel_ver}.elrepo.noarch.rpm" 2>/dev/null \
                || sudo dnf install -y elrepo-release 2>/dev/null || true
        fi
        set_matching_dnf_repos_enabled '^elrepo$' 1
    else
        set_matching_dnf_repos_enabled '^elrepo' 0
    fi

    set_dnf_repo_enabled "*-testing" 0

    if repo_enabled "vscodium"; then
        ensure_vscodium_dnf_repo
    else
        disable_vscodium_dnf_repo
    fi

    if repo_enabled "tailscale"; then
        if [ ! -f /etc/yum.repos.d/tailscale.repo ]; then
            echo "==> Adding Tailscale RPM repository..."
            sudo dnf config-manager addrepo --from-repofile="https://pkgs.tailscale.com/stable/rhel/${rhel_ver}/tailscale.repo" 2>/dev/null \
                || curl -fsSL "https://pkgs.tailscale.com/stable/rhel/${rhel_ver}/tailscale.repo" 2>/dev/null \
                    | sudo tee /etc/yum.repos.d/tailscale.repo > /dev/null || true
        fi
        set_matching_dnf_repos_enabled '^tailscale' 1
    else
        set_matching_dnf_repos_enabled '^tailscale' 0
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
    if repo_enabled "rpmfusion-free"; then
        register_expected_native rpmfusion-free-release
    fi
    if repo_enabled "rpmfusion-nonfree"; then
        register_expected_native rpmfusion-nonfree-release
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
