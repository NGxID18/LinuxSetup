#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"
source "$ROOT_DIR/script/common/flatpak.sh"

distro_init_apps() {
    local nv_default=0
    if [ "${GPU_CHOICE:-4}" = "1" ]; then
        nv_default=1
    fi

    register_app "nvidia-open"  "extra" "NVIDIA Open Kernel DKMS driver (nvidia-open-dkms)" "$nv_default"
    register_app "codecs-extra" "extra" "Multimedia codecs & FFmpeg (ffmpeg)" 1

    if repo_enabled "aur-paru" || repo_enabled "aur-yay" || repo_enabled "chaotic-aur"; then
        register_app "vscodium" "AUR/chaotic" "VSCodium open-source code editor (vscodium-bin)" 1
    fi

    register_app "tailscale" "extra" "Tailscale zero-config Mesh VPN" 1
    register_app "flatseal"  "extra" "Flatseal Flatpak permissions manager" 1
    register_app "tuned"     "extra" "Tuned system power & performance tuning daemon" 1
    register_app "snapper"   "extra" "Snapper Btrfs/LVM snapshot management tool" 1
    register_app "cron"      "core"  "Cronie scheduled job daemon" 1
    register_app "fs-tools"  "extra" "Filesystem tools (Btrfs, LVM2, NTFS, exFAT, XFS, ext4, FAT)" 1
}

distro_apply_apps() {
    ensure_repo_context
    if [ "${APPS_MENU_DONE:-0}" != "1" ]; then
        run_apps_menu
    fi

    if [ -z "${SELECTED_APPS:-}" ] && [ -z "${EXTRA_NATIVE_PKGS:-}" ] && [ -z "${EXTRA_FLATPAK_PKGS:-}" ]; then
        echo "==> No applications selected. Skipping application installation."
        return 0
    fi

    echo "==> Installing selected CachyOS applications..."
    local -a native_pkgs=()
    local -a aur_pkgs=()
    local -a extra_native=()
    if [ -n "${EXTRA_NATIVE_PKGS:-}" ]; then
        read -ra extra_native <<< "$EXTRA_NATIVE_PKGS"
    fi

    if app_enabled "flatseal";     then native_pkgs+=(flatseal); fi
    if app_enabled "tuned";        then native_pkgs+=(tuned); fi
    if app_enabled "snapper";      then native_pkgs+=(snapper); fi
    if app_enabled "cron";         then native_pkgs+=(cronie); fi
    if app_enabled "tailscale";    then native_pkgs+=(tailscale); fi
    if app_enabled "codecs-extra"; then native_pkgs+=(ffmpeg); fi
    if app_enabled "nvidia-open"; then
        if [ "${GPU_CHOICE:-4}" != "1" ]; then
            native_pkgs+=(dkms)
            if pacman -Si linux-cachyos-headers >/dev/null 2>&1; then
                native_pkgs+=(linux-cachyos-headers)
            else
                native_pkgs+=(linux-headers)
            fi
        fi
        native_pkgs+=(nvidia-open-dkms nvidia-utils)
    fi
    if app_enabled "fs-tools"; then
        native_pkgs+=(util-linux udisks2 lvm2 udisks2-lvm2 btrfs-progs udisks2-btrfs ntfs-3g xfsprogs exfatprogs dosfstools e2fsprogs)
    fi

    if app_enabled "vscodium"; then aur_pkgs+=(vscodium-bin); fi

    local p
    for p in "${extra_native[@]}"; do
        if pacman -Si "$p" >/dev/null 2>&1; then
            native_pkgs+=("$p")
        else
            aur_pkgs+=("$p")
        fi
    done

    if [ "${#native_pkgs[@]}" -gt 0 ]; then
        sudo pacman -S --needed --noconfirm "${native_pkgs[@]}"
    fi

    if [ "${#aur_pkgs[@]}" -gt 0 ]; then
        local aur_bin=""
        if [ -n "${AUR_HELPER:-}" ] && command -v "$AUR_HELPER" >/dev/null 2>&1; then
            aur_bin="$AUR_HELPER"
        elif command -v paru >/dev/null 2>&1; then
            aur_bin="paru"
        elif command -v yay >/dev/null 2>&1; then
            aur_bin="yay"
        fi

        if [ -n "$aur_bin" ]; then
            "$aur_bin" -S --needed --noconfirm "${aur_pkgs[@]}" || echo "  -> [WARNING] Some AUR packages failed: ${aur_pkgs[*]}"
        else
            echo "  -> [WARNING] No AUR helper installed; skipping AUR packages: ${aur_pkgs[*]}"
        fi
    fi

    if app_enabled "tailscale"; then sudo systemctl enable --now tailscaled 2>/dev/null || true; fi
    if app_enabled "tuned";     then sudo systemctl enable --now tuned 2>/dev/null || true; fi
    if app_enabled "cron";      then sudo systemctl enable --now cronie 2>/dev/null || true; fi

    install_selected_flatpaks
}

distro_install_gnome() {
    echo "==> Installing minimal GNOME desktop on CachyOS..."
    sudo pacman -S --needed --noconfirm \
        gdm gnome-shell gnome-session gnome-settings-daemon gnome-control-center \
        gnome-keyring gnome-backgrounds xdg-desktop-portal-gnome xdg-user-dirs-gtk \
        gvfs gvfs-mtp gvfs-smb gvfs-nfs nautilus file-roller loupe \
        gnome-text-editor gnome-calculator gnome-software gnome-tweaks \
        extension-manager libgtop lm_sensors
    sudo systemctl enable gdm
    "$ROOT_DIR/script/common/gnome-config.sh"
}

distro_install_cockpit() {
    echo "==> Installing Cockpit on CachyOS..."
    sudo pacman -S --needed --noconfirm cockpit cockpit-storaged udisks2 networkmanager
    "$ROOT_DIR/script/common/cockpit-config.sh"
}

distro_install_cli() {
    echo "==> Installing CLI tools (Fastfetch, Kitty, Nerd Font, Zsh) on CachyOS..."
    sudo pacman -S --needed --noconfirm \
        fastfetch kitty fontconfig ttf-jetbrains-mono-nerd zsh zsh-autosuggestions zsh-syntax-highlighting
    "$ROOT_DIR/script/common/cli-config.sh"
}

distro_install_zram() {
    echo "==> Installing zRAM generator on CachyOS..."
    sudo pacman -S --needed --noconfirm zram-generator
    "$ROOT_DIR/script/common/zram-config.sh"
}

distro_verify_apps() {
    ensure_repo_context

    if [[ "${INSTALL_GNOME:-Y}" =~ ^[Yy]$ ]]; then
        register_expected_native \
            gdm gnome-shell gnome-session gnome-settings-daemon gnome-control-center \
            gnome-keyring gnome-backgrounds xdg-desktop-portal-gnome xdg-user-dirs-gtk \
            gvfs gvfs-mtp gvfs-smb gvfs-nfs nautilus file-roller loupe \
            gnome-text-editor gnome-calculator gnome-software gnome-tweaks extension-manager \
            libgtop lm_sensors
    fi

    if [[ "${INSTALL_COCKPIT:-Y}" =~ ^[Yy]$ ]]; then
        register_expected_native cockpit cockpit-storaged udisks2 networkmanager
    fi

    if [[ "${INSTALL_APPS:-Y}" =~ ^[Yy]$ ]]; then
        if app_verifies "flatseal"; then register_expected_native flatseal; fi
        if app_verifies "vscodium" && (repo_enabled "aur-paru" || repo_enabled "aur-yay" || repo_enabled "chaotic-aur"); then
            register_expected_native "vscodium-bin|codium|vscodium"
        fi
        if app_verifies "tuned";     then register_expected_native tuned; fi
        if app_verifies "snapper";   then register_expected_native snapper; fi
        if app_verifies "tailscale"; then register_expected_native tailscale; fi
        if app_verifies "cron";      then register_expected_native cronie; fi
        if [ "${APPS_MENU_DONE:-0}" = "1" ] && app_enabled "codecs-extra"; then register_expected_native ffmpeg; fi
        if [ "${APPS_MENU_DONE:-0}" = "1" ] && app_enabled "nvidia-open";  then register_expected_native nvidia-open-dkms; fi

        if app_verifies "fs-tools"; then
            register_expected_native \
                util-linux udisks2 lvm2 udisks2-lvm2 btrfs-progs udisks2-btrfs \
                ntfs-3g xfsprogs exfatprogs dosfstools e2fsprogs
        fi

        verify_extra_and_flatpak_apps
    fi

    if [ "${ZRAM_CHOICE:-5}" != "5" ] && [ -n "${ZRAM_SIZE:-}" ]; then
        register_expected_native zram-generator
    fi

    if [[ "${INSTALL_CLI:-Y}" =~ ^[Yy]$ ]]; then
        register_expected_native fastfetch kitty fontconfig ttf-jetbrains-mono-nerd zsh
    fi
}

case "${1:-}" in
    --menu)    run_apps_menu ;;
    --gnome)   set -euo pipefail; distro_install_gnome ;;
    --cockpit) set -euo pipefail; distro_install_cockpit ;;
    --cli)     set -euo pipefail; distro_install_cli ;;
    --zram)    set -euo pipefail; distro_install_zram ;;
    --verify)  distro_verify_apps ;;
    *)
        if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
            set -euo pipefail
            distro_apply_apps
        fi
        ;;
esac
