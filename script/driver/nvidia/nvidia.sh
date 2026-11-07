#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing NVIDIA driver, matching kernel headers & CUDA ($PKG)..."
case "$PKG" in
    apt)
        CURRENT_KERNEL="$(uname -r)"
        sudo DEBIAN_FRONTEND=noninteractive apt install -y \
            "linux-headers-${CURRENT_KERNEL}" \
            dkms \
            build-essential

        if command -v ubuntu-drivers >/dev/null 2>&1; then
            sudo ubuntu-drivers autoinstall
        else
            sudo DEBIAN_FRONTEND=noninteractive apt install -y \
                nvidia-driver \
                nvidia-smi
        fi

        sudo DEBIAN_FRONTEND=noninteractive apt install -y \
            nvidia-persistenced \
            nvidia-cuda-toolkit \
            nvidia-vaapi-driver

        sudo systemctl enable nvidia-persistenced.service 2>/dev/null || true
        sudo update-initramfs -u
        ;;

    dnf)
        CURRENT_KERNEL="$(uname -r)"
        # Install matching kernel development headers for akmods
        sudo dnf install -y \
            "kernel-devel-${CURRENT_KERNEL}" \
            kernel-headers \
            akmod-nvidia \
            xorg-x11-drv-nvidia-cuda \
            nvidia-persistenced \
            || sudo dnf install -y kernel-devel kernel-headers akmod-nvidia xorg-x11-drv-nvidia-cuda nvidia-persistenced

        sudo systemctl enable nvidia-persistenced.service 2>/dev/null || true
        sudo akmods --force || true
        sudo dracut --force || true
        ;;

    zypper)
        # Install matching openSUSE kernel headers
        sudo zypper --non-interactive install -y kernel-default-devel kernel-devel 2>/dev/null || sudo zypper --non-interactive install -y kernel-devel || true

        # Add official openSUSE NVIDIA repo if not already added
        if ! zypper repos 2>/dev/null | grep -qi "nvidia"; then
            if grep -qi "tumbleweed" /etc/os-release; then
                sudo zypper addrepo --refresh https://download.nvidia.com/opensuse/tumbleweed NVIDIA
            else
                SLE_VER="$(rpm -E %sle_version 2>/dev/null || true)"
                [ -z "$SLE_VER" ] && SLE_VER="15.6"
                sudo zypper addrepo --refresh "https://download.nvidia.com/opensuse/leap/${SLE_VER}" NVIDIA
            fi
            sudo zypper --gpg-auto-import-keys refresh
        fi

        sudo zypper --non-interactive install -y \
            nvidia-driver-G06-kmp-meta \
            nvidia-userspace-meta-G06 \
            nvidia-persistenced \
            nvidia-settings 2>/dev/null || sudo zypper --non-interactive install -y x11-video-nvidiaG06 nvidia-persistenced

        sudo systemctl enable nvidia-persistenced.service 2>/dev/null || true
        ;;

    pacman)
        HEADERS=(dkms)
        for k in linux linux-zen linux-lts linux-hardened linux-cachyos; do
            if pacman -Qq "$k" >/dev/null 2>&1; then
                HEADERS+=("${k}-headers")
            fi
        done
        if [ "${#HEADERS[@]}" -eq 1 ]; then
            HEADERS+=(linux-headers)
        fi

        sudo pacman -S --needed --noconfirm \
            "${HEADERS[@]}" \
            nvidia-open-dkms \
            nvidia-utils \
            opencl-nvidia \
            libva-nvidia-driver \
            nvidia-settings \
            cuda \
            cudnn

        sudo systemctl enable nvidia-persistenced.service 2>/dev/null || true
        sudo mkinitcpio -P
        ;;
esac
