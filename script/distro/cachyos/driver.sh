#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"

distro_get_driver_info() {
    NVIDIA_AVAILABLE=1
    NVIDIA_LABEL="NVIDIA (Open Kernel DKMS + CUDA) [cachyos/extra]"
    AMD_LABEL="AMD (Mesa + Vulkan Radeon + VA-API) [cachyos/extra]"
    INTEL_LABEL="Intel (Mesa + Vulkan Intel + Media Driver) [cachyos/extra]"
}

distro_apply_driver() {
    ensure_repo_context
    local choice="${GPU_CHOICE:-4}"

    case "$choice" in
        1)
            echo "==> Installing CachyOS NVIDIA Open Kernel DKMS driver & CUDA..."
            local -a headers=(dkms)
            local k
            for k in linux linux-zen linux-lts linux-hardened linux-cachyos; do
                if pacman -Qq "$k" >/dev/null 2>&1; then
                    headers+=("${k}-headers")
                fi
            done
            if [ "${#headers[@]}" -eq 1 ]; then
                if pacman -Si linux-cachyos-headers >/dev/null 2>&1; then
                    headers+=(linux-cachyos-headers)
                else
                    headers+=(linux-headers)
                fi
            fi

            sudo pacman -S --needed --noconfirm \
                "${headers[@]}" \
                nvidia-open-dkms \
                nvidia-utils \
                opencl-nvidia \
                libva-nvidia-driver \
                nvidia-settings \
                cuda \
                cudnn

            sudo systemctl enable nvidia-persistenced.service 2>/dev/null || true
            sudo systemctl enable nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service 2>/dev/null || true
            sudo mkinitcpio -P

            if [[ "${NVD_TUNE:-N}" =~ ^[Yy]$ ]]; then
                "$ROOT_DIR/script/common/5060tune.sh"
            fi
            ;;
        2)
            echo "==> Installing CachyOS AMD GPU driver..."
            sudo pacman -S --needed --noconfirm mesa vulkan-radeon libva-mesa-driver xf86-video-amdgpu
            ;;
        3)
            echo "==> Installing CachyOS Intel GPU driver..."
            sudo pacman -S --needed --noconfirm mesa vulkan-intel intel-media-driver libva-intel-driver
            ;;
        4|*)
            echo "==> Skipping GPU driver installation."
            ;;
    esac
}

distro_verify_driver() {
    ensure_repo_context
    case "${GPU_CHOICE:-4}" in
        1)
            register_expected_native dkms
            local found_hdr=0 k
            for k in linux linux-zen linux-lts linux-hardened linux-cachyos; do
                if pacman -Qq "$k" >/dev/null 2>&1; then
                    register_expected_native "${k}-headers"
                    found_hdr=1
                fi
            done
            if [ "$found_hdr" -eq 0 ]; then
                register_expected_native "linux-cachyos-headers|linux-headers"
            fi
            register_expected_native \
                "nvidia-open-dkms|nvidia-dkms|nvidia" \
                nvidia-utils \
                opencl-nvidia \
                libva-nvidia-driver \
                nvidia-settings \
                cuda \
                cudnn
            ;;
        2)
            register_expected_native mesa vulkan-radeon libva-mesa-driver xf86-video-amdgpu
            ;;
        3)
            register_expected_native mesa vulkan-intel intel-media-driver libva-intel-driver
            ;;
    esac
}

case "${1:-}" in
    --menu)   run_driver_menu ;;
    --verify) distro_verify_driver ;;
    *)
        if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
            set -euo pipefail
            distro_apply_driver
        fi
        ;;
esac
