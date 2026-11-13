#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"
source "$ROOT_DIR/script/common/flatpak.sh"

distro_init_apps() {
    local nv_default=0
    if [ "${GPU_CHOICE:-4}" = "1" ]; then
        nv_default=1
    fi

    if repo_enabled "nvidia"; then
        register_app "nvidia-open" "nvidia" "NVIDIA Open Kernel G06 signed driver" "$nv_default"
    fi
    if repo_enabled "packman-full" || repo_enabled "packman-essentials"; then
        register_app "codecs-extra" "packman" "Restricted multimedia codecs & FFmpeg (ffmpeg)" 1
    fi
    if repo_enabled "vscodium"; then
        register_app "vscodium" "vscodium" "VSCodium open-source code editor (codium)" 1
    fi
    if repo_enabled "tailscale"; then
        register_app "tailscale" "tailscale" "Tailscale zero-config Mesh VPN" 1
    fi
    if repo_enabled "flathub"; then
        register_app "flatseal" "flathub" "Flatseal Flatpak permissions manager" 1
    fi

    register_app "tuned"    "repo-oss" "Tuned system power & performance tuning daemon" 1
    register_app "snapper"  "repo-oss" "Snapper Btrfs/LVM snapshot management tool" 1
    register_app "cron"     "repo-oss" "Cronie scheduled job daemon" 1
    register_app "fs-tools" "repo-oss" "Filesystem tools (Btrfs, LVM2, NTFS, exFAT, XFS, ext4, FAT)" 1
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

    echo "==> Installing selected openSUSE Leap applications..."
    local -a native_pkgs=()
    local -a optional_pkgs=()
    local -a extra_native=()
    if [ -n "${EXTRA_NATIVE_PKGS:-}" ]; then
        read -ra extra_native <<< "$EXTRA_NATIVE_PKGS"
    fi

    if app_enabled "vscodium" && repo_enabled "vscodium"; then
        ensure_vscodium_zypper_repo --refresh
    fi

    if app_enabled "vscodium";     then native_pkgs+=(codium); fi
    if app_enabled "tuned";        then native_pkgs+=(tuned); fi
    if app_enabled "snapper";      then native_pkgs+=(snapper); fi
    if app_enabled "cron";         then native_pkgs+=(cronie); fi
    if app_enabled "codecs-extra"; then native_pkgs+=(ffmpeg); fi
    if app_enabled "nvidia-open"; then
        if [ "${GPU_CHOICE:-4}" != "1" ]; then
            native_pkgs+=(kernel-default-devel kernel-devel)
        fi
        native_pkgs+=(nvidia-open-driver-G06-signed-kmp-meta)
    fi
    if app_enabled "flatseal";  then optional_pkgs+=(flatseal); fi
    if app_enabled "tailscale"; then optional_pkgs+=(tailscale); fi
    if app_enabled "fs-tools"; then
        native_pkgs+=(util-linux udisks2 btrfs-progs lvm2 ntfs-3g exfatprogs xfsprogs dosfstools e2fsprogs)
        optional_pkgs+=(udisks2-btrfs udisks2-lvm2)
    fi

    install_pkg_list_with_fallback zypper "${native_pkgs[@]}"
    if [ "${#optional_pkgs[@]}" -gt 0 ]; then
        sudo zypper --non-interactive --gpg-auto-import-keys install -y "${optional_pkgs[@]}" 2>/dev/null || true
    fi
    if [ "${#extra_native[@]}" -gt 0 ]; then
        install_pkg_list_with_fallback zypper "${extra_native[@]}"
    fi

    ensure_tailscale_installed

    if app_enabled "tailscale"; then sudo systemctl enable --now tailscaled 2>/dev/null || true; fi
    if app_enabled "tuned";     then sudo systemctl enable --now tuned 2>/dev/null || true; fi
    if app_enabled "cron"; then
        sudo systemctl enable --now cron 2>/dev/null || sudo systemctl enable --now cronie 2>/dev/null || true
    fi

    install_selected_flatpaks
}

distro_install_gnome() {
    echo "==> Installing minimal GNOME desktop on openSUSE Leap..."
    sudo zypper --non-interactive remove -y patterns-base-minimal_base-conflicts 2>/dev/null || true
    sudo zypper --non-interactive --gpg-auto-import-keys install -y --no-recommends \
        -t pattern gnome_basic 2>/dev/null \
        || sudo zypper --non-interactive --gpg-auto-import-keys install -y --no-recommends \
            patterns-gnome-gnome_basic 2>/dev/null || true

    sudo zypper --non-interactive --gpg-auto-import-keys install -y --no-recommends \
        gdm gnome-shell gnome-control-center nautilus file-roller \
        gnome-text-editor gnome-calculator gnome-tweaks gnome-extensions-app \
        xdg-desktop-portal-gnome glib2-tools libgtop-2_0-0 sensors 2>/dev/null \
        || sudo zypper --non-interactive --gpg-auto-import-keys install -y --no-recommends \
            gdm gnome-shell gnome-control-center nautilus file-roller gnome-text-editor \
            gnome-calculator gnome-tweaks gnome-extensions-app xdg-desktop-portal-gnome glib2-tools

    sudo systemctl enable gdm 2>/dev/null || sudo systemctl enable display-manager 2>/dev/null || true
    "$ROOT_DIR/script/common/gnome-config.sh"
}

distro_install_cockpit() {
    echo "==> Installing Cockpit on openSUSE Leap..."
    sudo zypper --non-interactive --gpg-auto-import-keys install -y \
        cockpit cockpit-storaged cockpit-networkmanager udisks2
    "$ROOT_DIR/script/common/cockpit-config.sh"
}

distro_install_cli() {
    echo "==> Installing CLI tools (Fastfetch, Kitty, Zsh) on openSUSE Leap..."
    sudo zypper --non-interactive --gpg-auto-import-keys install -y fastfetch kitty fontconfig zsh
    sudo zypper --non-interactive --gpg-auto-import-keys install -y \
        zsh-autosuggestions zsh-syntax-highlighting 2>/dev/null || true
    "$ROOT_DIR/script/common/cli-config.sh"
}

distro_install_zram() {
    echo "==> Installing zRAM generator on openSUSE Leap..."
    sudo zypper --non-interactive --gpg-auto-import-keys install -y zram-generator
    "$ROOT_DIR/script/common/zram-config.sh"
}

distro_verify_apps() {
    ensure_repo_context

    if [[ "${INSTALL_GNOME:-Y}" =~ ^[Yy]$ ]]; then
        register_expected_native \
            gdm gnome-shell gnome-control-center nautilus file-roller \
            gnome-text-editor gnome-calculator gnome-tweaks gnome-extensions-app \
            glib2-tools "libgtop-2_0-0|typelib-1_0-GTop-2_0"
    fi

    if [[ "${INSTALL_COCKPIT:-Y}" =~ ^[Yy]$ ]]; then
        register_expected_native cockpit cockpit-storaged cockpit-networkmanager udisks2
    fi

    if [[ "${INSTALL_APPS:-Y}" =~ ^[Yy]$ ]]; then
        if app_verifies "vscodium" && repo_enabled "vscodium"; then register_expected_native "codium|vscodium"; fi
        if app_verifies "tuned";     then register_expected_native tuned; fi
        if app_verifies "snapper";   then register_expected_native snapper; fi
        if app_verifies "cron";      then register_expected_native "cronie|cron"; fi
        if app_verifies "tailscale" && repo_enabled "tailscale"; then register_expected_native tailscale; fi
        if app_verifies "flatseal"  && repo_enabled "flathub"; then
            register_expected_native "flatseal|flatpak:com.github.tchx84.Flatseal"
        fi
        if [ "${APPS_MENU_DONE:-0}" = "1" ] && app_enabled "codecs-extra"; then register_expected_native ffmpeg; fi
        if [ "${APPS_MENU_DONE:-0}" = "1" ] && app_enabled "nvidia-open"; then
            register_expected_native "nvidia-open-driver-G06-signed-kmp-meta|nvidia-open-driver-G06-signed-kmp-default"
        fi

        if app_verifies "fs-tools"; then
            register_expected_native \
                util-linux udisks2 btrfs-progs lvm2 \
                ntfs-3g exfatprogs xfsprogs dosfstools e2fsprogs
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
