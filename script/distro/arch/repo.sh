#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"
source "$ROOT_DIR/script/common/flatpak.sh"

distro_init_repos() {
    REPO_CORE="core, extra"
    register_repo "multilib"    "Official"    "32-bit libraries (Steam, Wine, 32-bit GPU libraries)" 1
    register_repo "chaotic-aur" "Third-Party" "Pre-compiled binary repository for popular AUR packages" 0
    register_repo "testing"     "Official"    "Staging testing repositories (core-testing, extra-testing)" 0
    register_repo "aur-paru"    "AUR Helper"  "Install Paru (Rust-based AUR helper)" 1
    register_repo "aur-yay"     "AUR Helper"  "Install Yay (Go-based AUR helper)" 0
    register_repo "flathub"     "Universal"   "Flathub Flatpak application repository" 1
}

distro_apply_repos() {
    detect_linux_env
    if [ "${REPO_MENU_DONE:-0}" != "1" ]; then
        run_repo_menu
    fi

    echo "==> Configuring Arch Linux Pacman repositories (AUR: ${AUR_HELPER:-none})..."

    if repo_enabled "testing"; then
        sudo sed -i -E '/^#\[(core-testing|extra-testing|multilib-testing)\]/,/^#Include/ s/^#//' /etc/pacman.conf 2>/dev/null || true
    elif grep -qE '^\[(core-testing|extra-testing|multilib-testing)\]' /etc/pacman.conf 2>/dev/null; then
        sudo sed -i -E '/^\[(core-testing|extra-testing|multilib-testing)\]/,/^Include/ s/^/#/' /etc/pacman.conf
    fi

    if repo_enabled "multilib"; then
        if grep -qE '^#\[multilib\]' /etc/pacman.conf 2>/dev/null; then
            sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
        fi
    elif grep -qE '^\[multilib\]' /etc/pacman.conf 2>/dev/null; then
        sudo sed -i '/^\[multilib\]/,/^Include/ s/^/#/' /etc/pacman.conf
    fi

    if repo_enabled "chaotic-aur" && ! grep -qE '^\[chaotic-aur\]' /etc/pacman.conf 2>/dev/null; then
        echo "==> Setting up Chaotic-AUR repository..."
        sudo pacman-key --recv-key FBA220DFC880C036 --keyserver keyserver.ubuntu.com 2>/dev/null || true
        sudo pacman-key --lsign-key FBA220DFC880C036 2>/dev/null || true
        sudo pacman -U --noconfirm \
            'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
            'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' 2>/dev/null || true
        if [ -f /etc/pacman.d/chaotic-mirrorlist ]; then
            sudo tee -a /etc/pacman.conf > /dev/null <<'EOF'

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF
        fi
    fi

    sudo pacman -Syu --noconfirm
    local -a base_pkgs=(base-devel git curl wget unzip tar xz)
    if repo_enabled "flathub"; then
        base_pkgs+=(flatpak)
    fi
    sudo pacman -S --needed --noconfirm "${base_pkgs[@]}"

    if [ -n "${AUR_HELPER:-}" ]; then
        if ! command -v "$AUR_HELPER" >/dev/null 2>&1; then
            echo "==> Building & installing ${AUR_HELPER} AUR helper (${AUR_HELPER}-bin)..."
            local build_dir
            build_dir="$(mktemp -d "/tmp/${AUR_HELPER}.XXXXXX")"
            if git clone --depth 1 "https://aur.archlinux.org/${AUR_HELPER}-bin.git" "$build_dir"; then
                (cd "$build_dir" && makepkg -si --noconfirm) || echo "  -> [WARNING] Failed to build ${AUR_HELPER}-bin."
            else
                echo "  -> [WARNING] Failed to clone ${AUR_HELPER}-bin from AUR."
            fi
            rm -rf "$build_dir"
        fi
        if command -v "$AUR_HELPER" >/dev/null 2>&1; then
            "$AUR_HELPER" -Sua --noconfirm 2>/dev/null || true
        fi
    fi

    setup_flathub_remote
}

distro_verify_repos() {
    ensure_repo_context
    register_expected_native base-devel git curl wget unzip tar xz
    if repo_enabled "flathub"; then
        register_expected_native flatpak
    fi
    if [ "${REPO_MENU_DONE:-0}" = "1" ]; then
        if repo_enabled "aur-yay"; then
            register_expected_native "yay-bin|yay"
        elif repo_enabled "aur-paru"; then
            register_expected_native "paru-bin|paru|yay-bin|yay"
        fi
    else
        case "${AUR_HELPER:-paru}" in
            yay)    register_expected_native "yay-bin|yay" ;;
            paru|*) register_expected_native "paru-bin|paru|yay-bin|yay" ;;
        esac
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
