#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"
source "$ROOT_DIR/script/common/flatpak.sh"

distro_init_apps() {
    local nv_default=0
    if [ "${GPU_CHOICE:-4}" = "1" ]; then
        nv_default=1
    fi

    if repo_enabled "non-free" && repo_enabled "non-free-firmware"; then
        register_app "nvidia-open" "non-free" "NVIDIA Open Kernel DKMS driver (nvidia-kernel-open-dkms)" "$nv_default"
    fi
    if repo_enabled "non-free"; then
        register_app "codecs-extra" "non-free" "Multimedia codecs & FFmpeg (ffmpeg)" 1
    fi
    if repo_enabled "vscodium"; then
        register_app "vscodium" "vscodium" "VSCodium open-source code editor (codium)" 1
    fi
    if repo_enabled "tailscale"; then
        register_app "tailscale" "tailscale" "Tailscale zero-config Mesh VPN" 1
    fi

    register_app "flatseal" "main" "Flatseal Flatpak permissions manager" 1
    register_app "tuned"    "main" "Tuned system power & performance tuning daemon" 1
    register_app "snapper"  "main" "Snapper Btrfs/LVM snapshot management tool" 1
    register_app "cron"     "main" "Cron scheduled job daemon" 1
    register_app "fs-tools" "main" "Filesystem tools (Btrfs, LVM2, NTFS, exFAT, XFS, ext4, FAT)" 1
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

    echo "==> Installing selected Debian applications..."
    local -a native_pkgs=()
    local -a extra_native=()
    if [ -n "${EXTRA_NATIVE_PKGS:-}" ]; then
        read -ra extra_native <<< "$EXTRA_NATIVE_PKGS"
    fi

    if app_enabled "vscodium" && repo_enabled "vscodium"; then
        ensure_vscodium_apt_repo --update
    fi

    if app_enabled "flatseal";     then native_pkgs+=(flatseal); fi
    if app_enabled "vscodium";     then native_pkgs+=(codium); fi
    if app_enabled "tuned";        then native_pkgs+=(tuned); fi
    if app_enabled "snapper";      then native_pkgs+=(snapper); fi
    if app_enabled "cron";         then native_pkgs+=(cron); fi
    if app_enabled "tailscale";    then native_pkgs+=(tailscale); fi
    if app_enabled "codecs-extra"; then native_pkgs+=(ffmpeg); fi
    if app_enabled "nvidia-open"; then
        if [ "${GPU_CHOICE:-4}" != "1" ]; then
            native_pkgs+=(linux-headers-amd64 dkms build-essential)
        fi
        native_pkgs+=(nvidia-kernel-open-dkms nvidia-driver)
    fi
    if app_enabled "fs-tools"; then
        native_pkgs+=(util-linux udisks2 udisks2-btrfs udisks2-lvm2 btrfs-progs lvm2 ntfs-3g xfsprogs exfatprogs dosfstools e2fsprogs)
    fi

    install_pkg_list_with_fallback apt "${native_pkgs[@]}"
    if [ "${#extra_native[@]}" -gt 0 ]; then
        install_pkg_list_with_fallback apt "${extra_native[@]}"
    fi

    ensure_tailscale_installed

    if app_enabled "tailscale"; then sudo systemctl enable --now tailscaled 2>/dev/null || true; fi
    if app_enabled "tuned";     then sudo systemctl enable --now tuned 2>/dev/null || true; fi
    if app_enabled "cron";      then sudo systemctl enable --now cron 2>/dev/null || true; fi

    install_selected_flatpaks
}

distro_install_gnome() {
    echo "==> Installing minimal GNOME desktop on Debian..."
    sudo DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
        gdm3 gnome-shell gnome-session gnome-settings-daemon gnome-control-center \
        gnome-keyring gnome-backgrounds xdg-desktop-portal-gnome xdg-user-dirs-gtk \
        gvfs-backends gvfs-fuse network-manager-gnome nautilus file-roller \
        gnome-text-editor gnome-calculator gnome-software gnome-tweaks \
        gnome-shell-extension-prefs dconf-cli libglib2.0-bin gir1.2-gtop-2.0 lm-sensors
    sudo systemctl enable gdm3 2>/dev/null || sudo systemctl enable gdm 2>/dev/null || true
    "$ROOT_DIR/script/common/gnome-config.sh"
}

distro_install_cockpit() {
    echo "==> Installing Cockpit on Debian..."
    sudo DEBIAN_FRONTEND=noninteractive apt install -y \
        cockpit cockpit-storaged cockpit-networkmanager udisks2
    "$ROOT_DIR/script/common/cockpit-config.sh"
}

distro_install_cli() {
    echo "==> Installing CLI tools (Fastfetch, Kitty, Zsh) on Debian..."
    sudo DEBIAN_FRONTEND=noninteractive apt install -y \
        fastfetch kitty fontconfig zsh zsh-autosuggestions zsh-syntax-highlighting
    "$ROOT_DIR/script/common/cli-config.sh"
}

distro_install_zram() {
    echo "==> Installing zRAM generator on Debian..."
    sudo DEBIAN_FRONTEND=noninteractive apt install -y systemd-zram-generator
    "$ROOT_DIR/script/common/zram-config.sh"
}

distro_verify_apps() {
    ensure_repo_context

    if [[ "${INSTALL_GNOME:-Y}" =~ ^[Yy]$ ]]; then
        register_expected_native \
            "gdm3|gdm" gnome-shell gnome-session gnome-settings-daemon gnome-control-center \
            gnome-keyring gnome-backgrounds xdg-desktop-portal-gnome xdg-user-dirs-gtk \
            gvfs-backends gvfs-fuse network-manager-gnome nautilus file-roller \
            gnome-text-editor gnome-calculator gnome-software \
            gnome-tweaks gnome-shell-extension-prefs dconf-cli \
            libglib2.0-bin gir1.2-gtop-2.0 lm-sensors
    fi

    if [[ "${INSTALL_COCKPIT:-Y}" =~ ^[Yy]$ ]]; then
        register_expected_native cockpit cockpit-storaged cockpit-networkmanager udisks2
    fi

    if [[ "${INSTALL_APPS:-Y}" =~ ^[Yy]$ ]]; then
        if app_verifies "flatseal"; then register_expected_native flatseal; fi
        if app_verifies "vscodium" && repo_enabled "vscodium"; then register_expected_native "codium|vscodium"; fi
        if app_verifies "tuned"; then register_expected_native tuned; fi
        if app_verifies "snapper"; then register_expected_native snapper; fi
        if app_verifies "cron"; then register_expected_native "cron|cronie"; fi
        if app_verifies "tailscale" && repo_enabled "tailscale"; then register_expected_native tailscale; fi
        if [ "${APPS_MENU_DONE:-0}" = "1" ] && app_enabled "codecs-extra"; then register_expected_native ffmpeg; fi
        if [ "${APPS_MENU_DONE:-0}" = "1" ] && app_enabled "nvidia-open"; then
            register_expected_native "nvidia-kernel-open-dkms|nvidia-driver"
        fi
        if app_verifies "fs-tools"; then
            register_expected_native \
                util-linux udisks2 udisks2-btrfs udisks2-lvm2 btrfs-progs lvm2 \
                ntfs-3g xfsprogs exfatprogs dosfstools e2fsprogs
        fi
        verify_extra_and_flatpak_apps
    fi

    if [ "${ZRAM_CHOICE:-5}" != "5" ] && [ -n "${ZRAM_SIZE:-}" ]; then
        register_expected_native systemd-zram-generator
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
