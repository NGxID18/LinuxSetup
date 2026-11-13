#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"
source "$ROOT_DIR/script/common/flatpak.sh"

distro_init_apps() {
    local nv_default=0
    if [ "${GPU_CHOICE:-4}" = "1" ]; then
        nv_default=1
    fi

    if repo_enabled "rpmfusion-nonfree" && repo_enabled "epel"; then
        register_app "nvidia-open" "rpmfusion-nonfree" "NVIDIA Open Kernel Module driver (akmod-nvidia-open)" "$nv_default"
    fi
    if repo_enabled "rpmfusion-free" && repo_enabled "epel"; then
        register_app "codecs-extra" "rpmfusion-free" "Multimedia codecs & FFmpeg (ffmpeg)" 1
    fi
    if repo_enabled "vscodium"; then
        register_app "vscodium" "vscodium" "VSCodium open-source code editor (codium)" 1
    fi
    if repo_enabled "tailscale"; then
        register_app "tailscale" "tailscale" "Tailscale zero-config Mesh VPN" 1
    fi
    if repo_enabled "epel" || repo_enabled "flathub"; then
        local fs_src="epel"
        if ! repo_enabled "epel"; then fs_src="flathub"; fi
        register_app "flatseal" "$fs_src" "Flatseal Flatpak permissions manager" 1
    fi

    register_app "tuned" "baseos/app" "Tuned system power & performance tuning daemon" 1
    if repo_enabled "epel"; then
        register_app "snapper" "epel" "Snapper Btrfs/LVM snapshot management tool" 1
    fi
    register_app "cron"     "baseos/app" "Cronie scheduled job daemon" 1
    register_app "fs-tools" "baseos/app" "Filesystem tools (LVM2, XFS, ext4, FAT + EPEL NTFS/exFAT)" 1
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

    echo "==> Installing selected AlmaLinux/EL applications..."
    local -a native_pkgs=()
    local -a optional_pkgs=()
    local -a extra_native=()
    if [ -n "${EXTRA_NATIVE_PKGS:-}" ]; then
        read -ra extra_native <<< "$EXTRA_NATIVE_PKGS"
    fi

    if app_enabled "vscodium" && repo_enabled "vscodium"; then
        ensure_vscodium_dnf_repo
    fi

    if app_enabled "vscodium";     then native_pkgs+=(codium); fi
    if app_enabled "tuned";        then native_pkgs+=(tuned); fi
    if app_enabled "cron";         then native_pkgs+=(cronie); fi
    if app_enabled "tailscale";    then native_pkgs+=(tailscale); fi
    if app_enabled "codecs-extra"; then native_pkgs+=(ffmpeg); fi
    if app_enabled "nvidia-open"; then
        if [ "${GPU_CHOICE:-4}" != "1" ]; then
            native_pkgs+=(kernel-devel kernel-headers kmodtool akmods)
        fi
        native_pkgs+=(akmod-nvidia-open)
    fi
    if app_enabled "flatseal"; then optional_pkgs+=(flatseal); fi
    if app_enabled "snapper";  then optional_pkgs+=(snapper); fi

    if app_enabled "fs-tools"; then
        native_pkgs+=(util-linux udisks2 udisks2-lvm2 lvm2 xfsprogs dosfstools e2fsprogs)
        if repo_enabled "epel"; then native_pkgs+=(ntfs-3g exfatprogs); fi
        optional_pkgs+=(btrfs-progs udisks2-btrfs)
    fi

    install_pkg_list_with_fallback dnf "${native_pkgs[@]}"
    if [ "${#optional_pkgs[@]}" -gt 0 ]; then
        sudo dnf install -y "${optional_pkgs[@]}" 2>/dev/null || true
    fi
    if [ "${#extra_native[@]}" -gt 0 ]; then
        install_pkg_list_with_fallback dnf "${extra_native[@]}"
    fi

    ensure_tailscale_installed

    if app_enabled "tailscale"; then sudo systemctl enable --now tailscaled 2>/dev/null || true; fi
    if app_enabled "tuned";     then sudo systemctl enable --now tuned 2>/dev/null || true; fi
    if app_enabled "cron";      then sudo systemctl enable --now crond 2>/dev/null || true; fi

    install_selected_flatpaks
}

distro_install_gnome() {
    echo "==> Installing minimal GNOME desktop on AlmaLinux/EL..."
    sudo dnf install -y \
        gdm gnome-shell gnome-session gnome-settings-daemon gnome-control-center \
        gnome-keyring xdg-desktop-portal-gnome xdg-user-dirs-gtk nautilus \
        gnome-text-editor gnome-calculator gnome-software gnome-tweaks libgtop2 lm_sensors \
        || sudo dnf groupinstall -y "Workstation"
    sudo dnf install -y file-roller gnome-extensions-app 2>/dev/null || true
    sudo systemctl enable gdm
    "$ROOT_DIR/script/common/gnome-config.sh"
}

distro_install_cockpit() {
    echo "==> Installing Cockpit on AlmaLinux/EL..."
    sudo dnf install -y \
        cockpit cockpit-storaged cockpit-networkmanager cockpit-selinux udisks2
    "$ROOT_DIR/script/common/cockpit-config.sh"
}

distro_install_cli() {
    echo "==> Installing CLI tools (Fastfetch, Kitty, Zsh) on AlmaLinux/EL..."
    sudo dnf install -y \
        fastfetch kitty fontconfig zsh zsh-autosuggestions zsh-syntax-highlighting
    "$ROOT_DIR/script/common/cli-config.sh"
}

distro_install_zram() {
    echo "==> Installing zRAM generator on AlmaLinux/EL..."
    sudo dnf install -y zram-generator
    "$ROOT_DIR/script/common/zram-config.sh"
}

distro_verify_apps() {
    ensure_repo_context

    if [[ "${INSTALL_GNOME:-Y}" =~ ^[Yy]$ ]]; then
        register_expected_native \
            gdm gnome-shell gnome-session gnome-settings-daemon gnome-control-center \
            nautilus gnome-text-editor gnome-calculator gnome-software gnome-tweaks \
            libgtop2 lm_sensors
    fi

    if [[ "${INSTALL_COCKPIT:-Y}" =~ ^[Yy]$ ]]; then
        register_expected_native cockpit cockpit-storaged cockpit-networkmanager cockpit-selinux udisks2
    fi

    if [[ "${INSTALL_APPS:-Y}" =~ ^[Yy]$ ]]; then
        if app_verifies "vscodium" && repo_enabled "vscodium"; then register_expected_native "codium|vscodium"; fi
        if app_verifies "tuned"; then register_expected_native tuned; fi
        if app_verifies "cron"; then register_expected_native "cronie|cron"; fi
        if app_verifies "tailscale" && repo_enabled "tailscale"; then register_expected_native tailscale; fi
        if app_verifies "flatseal"; then
            if repo_enabled "epel"; then
                register_expected_native "flatseal|flatpak:com.github.tchx84.Flatseal"
            elif repo_enabled "flathub"; then
                register_expected_flatpak "com.github.tchx84.Flatseal"
            fi
        fi
        if [ "${APPS_MENU_DONE:-0}" = "1" ] && app_enabled "codecs-extra"; then register_expected_native ffmpeg; fi
        if [ "${APPS_MENU_DONE:-0}" = "1" ] && app_enabled "nvidia-open";  then register_expected_native akmod-nvidia-open; fi

        if app_verifies "fs-tools"; then
            register_expected_native util-linux udisks2 udisks2-lvm2 lvm2 xfsprogs dosfstools e2fsprogs
            if repo_enabled "epel"; then register_expected_native ntfs-3g exfatprogs; fi
        fi

        verify_extra_and_flatpak_apps
    fi

    if [ "${ZRAM_CHOICE:-5}" != "5" ] && [ -n "${ZRAM_SIZE:-}" ]; then
        register_expected_native zram-generator
    fi

    if [[ "${INSTALL_CLI:-Y}" =~ ^[Yy]$ ]]; then
        register_expected_native fastfetch kitty fontconfig zsh
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
