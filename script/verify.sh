#!/usr/bin/env bash
set -euo pipefail

if [ -z "${PKG:-}" ] || [ -z "${DISTRO:-}" ]; then
    DISTRO_ID="unknown"
    DISTRO_LIKE=""
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        DISTRO_ID="${ID:-unknown}"
        DISTRO_LIKE="${ID_LIKE:-}"
    fi

    if command -v apt >/dev/null 2>&1; then
        PKG="apt"
        case "$DISTRO_ID" in
            ubuntu|linuxmint|pop) DISTRO="ubuntu" ;;
            debian|*)
                if [[ "$DISTRO_LIKE" == *ubuntu* ]]; then DISTRO="ubuntu"; else DISTRO="debian"; fi
                ;;
        esac
    elif command -v dnf >/dev/null 2>&1; then
        PKG="dnf"
        case "$DISTRO_ID" in
            fedora) DISTRO="fedora" ;;
            *)
                if [ "$(rpm -E %fedora 2>/dev/null)" != "%fedora" ]; then DISTRO="fedora"; else DISTRO="rhel"; fi
                ;;
        esac
    elif command -v zypper >/dev/null 2>&1; then
        PKG="zypper"
        case "$DISTRO_ID" in
            *tumbleweed*|*slowroll*) DISTRO="tumbleweed" ;;
            *)
                if grep -qi "tumbleweed" /etc/os-release 2>/dev/null; then DISTRO="tumbleweed"; else DISTRO="leap"; fi
                ;;
        esac
    elif command -v pacman >/dev/null 2>&1; then
        PKG="pacman"
        case "$DISTRO_ID" in
            cachyos) DISTRO="cachyos" ;;
            *)       DISTRO="arch" ;;
        esac
    else
        echo "ERROR: Unsupported package manager." >&2
        exit 1
    fi
fi

GPU_CHOICE="${GPU_CHOICE:-4}"
INSTALL_GNOME="${INSTALL_GNOME:-Y}"
INSTALL_COCKPIT="${INSTALL_COCKPIT:-Y}"
INSTALL_APPS="${INSTALL_APPS:-Y}"
INSTALL_CLI="${INSTALL_CLI:-Y}"
ZRAM_CHOICE="${ZRAM_CHOICE:-5}"

NATIVE_PKGS=()
FLATPAK_PKGS=()

# 1. Base / Repository packages
case "$PKG" in
    apt)
        NATIVE_PKGS+=(ca-certificates gnupg curl wget git unzip tar xz-utils flatpak)
        case "$DISTRO" in
            ubuntu) NATIVE_PKGS+=(software-properties-common) ;;
            debian|*) ;;
        esac
        ;;
    dnf)
        case "$DISTRO" in
            fedora) NATIVE_PKGS+=(git curl wget unzip tar xz flatpak rpmfusion-nonfree-release-tainted) ;;
            rhel|*) NATIVE_PKGS+=(git curl wget unzip tar xz flatpak epel-release) ;;
        esac
        ;;
    zypper)
        NATIVE_PKGS+=(git curl wget unzip tar xz flatpak)
        ;;
    pacman)
        case "${AUR_HELPER:-paru}" in
            yay)    NATIVE_PKGS+=(base-devel git curl wget unzip tar xz flatpak "yay-bin|yay") ;;
            paru|*) NATIVE_PKGS+=(base-devel git curl wget unzip tar xz flatpak "paru-bin|paru|yay-bin|yay") ;;
        esac
        ;;
esac

# 2. GPU Driver packages
case "$GPU_CHOICE" in
    1)
        case "$PKG" in
            apt)
                case "$DISTRO" in
                    ubuntu)
                        NATIVE_PKGS+=(
                            "linux-headers-$(uname -r)|linux-headers-generic"
                            dkms
                            build-essential
                            "nvidia-driver|nvidia-driver-*"
                            "nvidia-smi|nvidia-utils-*"
                            nvidia-persistenced
                            nvidia-cuda-toolkit
                            nvidia-vaapi-driver
                        )
                        ;;
                    debian|*)
                        NATIVE_PKGS+=(
                            "linux-headers-$(uname -r)|linux-headers-amd64"
                            dkms
                            build-essential
                            "nvidia-kernel-open-dkms|nvidia-kernel-dkms|nvidia-driver"
                            "nvidia-smi|nvidia-utils-*"
                            nvidia-persistenced
                            nvidia-cuda-toolkit
                            nvidia-vaapi-driver
                        )
                        ;;
                esac
                ;;
            dnf)
                case "$DISTRO" in
                    fedora)
                        NATIVE_PKGS+=(
                            "kernel-devel-$(uname -r)|kernel-devel"
                            kernel-headers
                            "akmod-nvidia-open|akmod-nvidia"
                            xorg-x11-drv-nvidia-cuda
                            xorg-x11-drv-nvidia-power
                            nvidia-settings
                            nvidia-persistenced
                            libva-nvidia-driver
                        )
                        ;;
                    rhel|*)
                        NATIVE_PKGS+=(
                            "kernel-devel-$(uname -r)|kernel-devel"
                            kernel-headers
                            "akmod-nvidia-open|akmod-nvidia"
                            xorg-x11-drv-nvidia-cuda
                            nvidia-persistenced
                        )
                        ;;
                esac
                ;;
            zypper)
                NATIVE_PKGS+=(
                    "kernel-default-devel|kernel-devel"
                    "nvidia-open-driver-G06-signed-kmp-meta|nvidia-open-driver-G06-signed-kmp-default|nvidia-driver-G06-kmp-meta|x11-video-nvidiaG06"
                    "nvidia-userspace-meta-G06|nvidia-compute-utils-G06|nvidia-persistenced"
                )
                ;;
            pacman)
                NATIVE_PKGS+=(dkms)
                FOUND_HDR=0
                for k in linux linux-zen linux-lts linux-hardened linux-cachyos; do
                    if pacman -Qq "$k" >/dev/null 2>&1; then
                        NATIVE_PKGS+=("${k}-headers")
                        FOUND_HDR=1
                    fi
                done
                [ "$FOUND_HDR" -eq 0 ] && NATIVE_PKGS+=(linux-headers)
                NATIVE_PKGS+=(
                    "nvidia-open-dkms|nvidia-dkms|nvidia"
                    nvidia-utils
                    opencl-nvidia
                    libva-nvidia-driver
                    nvidia-settings
                    cuda
                    cudnn
                )
                ;;
        esac
        ;;
    2)
        case "$PKG" in
            apt)    NATIVE_PKGS+=(mesa-vulkan-drivers mesa-va-drivers libgl1-mesa-dri xserver-xorg-video-amdgpu) ;;
            dnf)
                case "$DISTRO" in
                    fedora) NATIVE_PKGS+=(mesa-dri-drivers mesa-vulkan-drivers "mesa-va-drivers-freeworld|mesa-va-drivers") ;;
                    rhel|*) NATIVE_PKGS+=(mesa-dri-drivers mesa-vulkan-drivers) ;;
                esac
                ;;
            zypper) NATIVE_PKGS+=(Mesa-dri "Mesa-libva|libvulkan_radeon" libvulkan_radeon) ;;
            pacman) NATIVE_PKGS+=(mesa vulkan-radeon libva-mesa-driver xf86-video-amdgpu) ;;
        esac
        ;;
    3)
        case "$PKG" in
            apt)    NATIVE_PKGS+=(mesa-vulkan-drivers libgl1-mesa-dri "intel-media-va-driver-non-free|intel-media-va-driver") ;;
            dnf)    NATIVE_PKGS+=(mesa-dri-drivers mesa-vulkan-drivers "intel-media-driver|libva-intel-driver") ;;
            zypper) NATIVE_PKGS+=(Mesa-dri libvulkan_intel "intel-media-driver|libva-intel-driver") ;;
            pacman) NATIVE_PKGS+=(mesa vulkan-intel intel-media-driver libva-intel-driver) ;;
        esac
        ;;
esac

# 3. GNOME Desktop packages
if [[ "$INSTALL_GNOME" =~ ^[Yy]$ ]]; then
    case "$PKG" in
        apt)
            NATIVE_PKGS+=(
                "gdm3|gdm" gnome-shell gnome-session gnome-settings-daemon gnome-control-center
                gnome-keyring gnome-backgrounds xdg-desktop-portal-gnome xdg-user-dirs-gtk
                gvfs-backends gvfs-fuse network-manager-gnome nautilus file-roller
                gnome-text-editor gnome-calculator gnome-software
                gnome-tweaks gnome-shell-extension-prefs dconf-cli
                libglib2.0-bin gir1.2-gtop-2.0 lm-sensors
            )
            ;;
        dnf)
            case "$DISTRO" in
                fedora)
                    NATIVE_PKGS+=(
                        gdm gnome-shell gnome-session gnome-settings-daemon gnome-control-center
                        nautilus file-roller gnome-text-editor gnome-calculator
                        gnome-software gnome-tweaks gnome-extensions-app
                        libgtop2 lm_sensors
                    )
                    ;;
                rhel|*)
                    NATIVE_PKGS+=(
                        gdm gnome-shell gnome-session gnome-settings-daemon gnome-control-center
                        nautilus gnome-text-editor gnome-calculator gnome-software gnome-tweaks
                        libgtop2 lm_sensors
                    )
                    ;;
            esac
            ;;
        zypper)
            NATIVE_PKGS+=(
                gdm gnome-shell gnome-control-center nautilus file-roller
                gnome-text-editor gnome-calculator gnome-tweaks gnome-extensions-app
                glib2-tools "libgtop-2_0-0|typelib-1_0-GTop-2_0"
            )
            ;;
        pacman)
            NATIVE_PKGS+=(
                gdm gnome-shell gnome-session gnome-settings-daemon gnome-control-center
                gnome-keyring gnome-backgrounds xdg-desktop-portal-gnome xdg-user-dirs-gtk
                gvfs gvfs-mtp gvfs-smb gvfs-nfs nautilus file-roller loupe
                gnome-text-editor gnome-calculator gnome-software gnome-tweaks extension-manager
                libgtop lm_sensors
            )
            ;;
    esac
fi

# 4. Cockpit packages
if [[ "$INSTALL_COCKPIT" =~ ^[Yy]$ ]]; then
    case "$PKG" in
        apt)
            NATIVE_PKGS+=(cockpit cockpit-storaged cockpit-networkmanager udisks2)
            ;;
        dnf)
            NATIVE_PKGS+=(cockpit cockpit-storaged cockpit-networkmanager cockpit-selinux udisks2)
            ;;
        zypper)
            NATIVE_PKGS+=(cockpit cockpit-storaged cockpit-networkmanager udisks2)
            ;;
        pacman)
            NATIVE_PKGS+=(cockpit cockpit-storaged udisks2 networkmanager)
            ;;
    esac
fi

# 5. Applications (Native & Flatpak)
if [[ "$INSTALL_APPS" =~ ^[Yy]$ ]]; then
    case "$PKG" in
        apt)
            NATIVE_PKGS+=(
                flatseal "codium|vscodium" tuned snapper util-linux udisks2
                udisks2-btrfs udisks2-lvm2 btrfs-progs lvm2
                ntfs-3g exfatprogs xfsprogs dosfstools e2fsprogs "cron|cronie" tailscale
            )
            ;;
        dnf)
            case "$DISTRO" in
                fedora)
                    NATIVE_PKGS+=(
                        flatseal "codium|vscodium" tuned snapper util-linux udisks2
                        udisks2-btrfs udisks2-lvm2 btrfs-progs lvm2
                        ntfs-3g exfatprogs xfsprogs dosfstools e2fsprogs "cronie|cron" tailscale
                    )
                    ;;
                rhel|*)
                    NATIVE_PKGS+=(
                        "codium|vscodium" tuned util-linux udisks2
                        udisks2-lvm2 lvm2
                        ntfs-3g exfatprogs xfsprogs dosfstools e2fsprogs "cronie|cron" tailscale
                    )
                    ;;
            esac
            ;;
        zypper)
            case "$DISTRO" in
                tumbleweed)
                    NATIVE_PKGS+=(
                        flatseal "codium|vscodium" tuned snapper util-linux udisks2
                        udisks2-btrfs udisks2-lvm2 btrfs-progs lvm2
                        ntfs-3g exfatprogs xfsprogs dosfstools e2fsprogs "cronie|cron" tailscale
                    )
                    ;;
                leap|*)
                    NATIVE_PKGS+=(
                        "codium|vscodium" tuned snapper util-linux udisks2
                        btrfs-progs lvm2
                        ntfs-3g exfatprogs xfsprogs dosfstools e2fsprogs "cronie|cron" tailscale
                    )
                    ;;
            esac
            ;;
        pacman)
            NATIVE_PKGS+=(
                flatseal "vscodium-bin|codium|vscodium" tuned snapper tailscale cronie
                util-linux udisks2 lvm2 udisks2-lvm2 btrfs-progs udisks2-btrfs
                ntfs-3g xfsprogs exfatprogs dosfstools e2fsprogs
            )
            ;;
    esac

    FLATPAK_PKGS+=(
        com.valvesoftware.Steam
        com.discordapp.Discord
        io.gitlab.librewolf-community
        org.prismlauncher.PrismLauncher
        com.rtosta.zapzap
        com.obsproject.Studio
    )
fi

# 6. zRAM packages
if [ "$ZRAM_CHOICE" != "5" ] && [ -n "${ZRAM_SIZE:-}" ]; then
    case "$PKG" in
        apt)    NATIVE_PKGS+=(systemd-zram-generator) ;;
        dnf|zypper|pacman) NATIVE_PKGS+=(zram-generator) ;;
    esac
fi

# 7. CLI packages
if [[ "$INSTALL_CLI" =~ ^[Yy]$ ]]; then
    case "$PKG" in
        apt|dnf|zypper)
            NATIVE_PKGS+=(fastfetch kitty fontconfig zsh)
            ;;
        pacman)
            NATIVE_PKGS+=(fastfetch kitty fontconfig ttf-jetbrains-mono-nerd zsh)
            ;;
    esac
fi

is_native_installed() {
    local spec="$1"
    local candidate
    IFS='|' read -ra candidates <<< "$spec"
    for candidate in "${candidates[@]}"; do
        case "$PKG" in
            apt)
                if dpkg-query -W -f='${Status}\n' "$candidate" 2>/dev/null | grep -Fxq "install ok installed"; then
                    return 0
                fi
                ;;
            dnf|zypper)
                if rpm -q "$candidate" >/dev/null 2>&1 || rpm -q --whatprovides "$candidate" >/dev/null 2>&1; then
                    return 0
                fi
                ;;
            pacman)
                if pacman -Qq "$candidate" >/dev/null 2>&1 || pacman -Qg "$candidate" >/dev/null 2>&1 || pacman -T "$candidate" >/dev/null 2>&1; then
                    return 0
                fi
                ;;
        esac
    done
    return 1
}

is_flatpak_installed() {
    flatpak info "$1" >/dev/null 2>&1
}

echo -e "\n=================================================="
echo "           INSTALLATION VERIFICATION              "
echo "=================================================="

declare -A SEEN_NATIVE=()
declare -A SEEN_FLATPAK=()

TOTAL_PKGS=0
INSTALLED_PKGS=0
MISSING_PKGS=()

echo -e "\n--> Checking Native Packages ($PKG | $DISTRO):"
for pkg in "${NATIVE_PKGS[@]}"; do
    [ -n "${SEEN_NATIVE[$pkg]:-}" ] && continue
    SEEN_NATIVE[$pkg]=1
    TOTAL_PKGS=$((TOTAL_PKGS + 1))
    LABEL="${pkg%%|*}"

    if is_native_installed "$pkg"; then
        printf "  [\e[1;32mOK\e[0m]      %s\n" "$LABEL"
        INSTALLED_PKGS=$((INSTALLED_PKGS + 1))
    else
        printf "  [\e[1;31mMISSING\e[0m] %s\n" "$LABEL"
        MISSING_PKGS+=("$LABEL ($PKG)")
    fi
done

if [ "${#FLATPAK_PKGS[@]}" -gt 0 ]; then
    echo -e "\n--> Checking Flatpak Packages:"
    for app in "${FLATPAK_PKGS[@]}"; do
        [ -n "${SEEN_FLATPAK[$app]:-}" ] && continue
        SEEN_FLATPAK[$app]=1
        TOTAL_PKGS=$((TOTAL_PKGS + 1))

        if is_flatpak_installed "$app"; then
            printf "  [\e[1;32mOK\e[0m]      %s\n" "$app"
            INSTALLED_PKGS=$((INSTALLED_PKGS + 1))
        else
            printf "  [\e[1;31mMISSING\e[0m] %s\n" "$app"
            MISSING_PKGS+=("$app (flatpak)")
        fi
    done
fi

PERCENT=0
if [ "$TOTAL_PKGS" -gt 0 ]; then
    PERCENT=$(( (INSTALLED_PKGS * 100) / TOTAL_PKGS ))
fi

echo "--------------------------------------------------"
echo "  Installed : ${INSTALLED_PKGS} / ${TOTAL_PKGS} packages (${PERCENT}%)"
if [ "${#MISSING_PKGS[@]}" -eq 0 ]; then
    echo -e "  Status    : \e[1;32mAll selected dependencies are installed!\e[0m"
else
    echo -e "  Status    : \e[1;33m${#MISSING_PKGS[@]} package(s) missing:\e[0m"
    for m in "${MISSING_PKGS[@]}"; do
        echo "              - $m"
    done
fi
echo "=================================================="
