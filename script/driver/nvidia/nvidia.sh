#!/usr/bin/env bash
set -e

echo "==> Installing NVIDIA driver & CUDA ($PKG)..."
case "$PKG" in
    apt)
        sudo DEBIAN_FRONTEND=noninteractive apt install -y \
            "linux-headers-$(uname -r)" \
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

        sudo systemctl enable nvidia-persistenced.service
        sudo update-initramfs -u
        ;;

    dnf)
        sudo dnf install -y \
            akmod-nvidia \
            xorg-x11-drv-nvidia-cuda \
            nvidia-persistenced

        sudo systemctl enable nvidia-persistenced.service
        sudo akmods --force
        sudo dracut --force
        ;;

    pacman)
        HEADERS=(dkms)
        for k in linux linux-zen linux-lts linux-hardened; do
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

        sudo systemctl enable nvidia-persistenced.service
        sudo mkinitcpio -P
        ;;
esac
