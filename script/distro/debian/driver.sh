#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"

distro_get_driver_info() {
    if repo_enabled "non-free" && repo_enabled "non-free-firmware"; then
        NVIDIA_AVAILABLE=1
        NVIDIA_LABEL="NVIDIA (Open Kernel DKMS + CUDA) [non-free + non-free-firmware]"
    else
        NVIDIA_AVAILABLE=0
        NVIDIA_LABEL="NVIDIA [Disabled — requires non-free + non-free-firmware]"
        NVIDIA_BLOCKED_REASON="NVIDIA driver on Debian requires both 'non-free' and 'non-free-firmware' repositories."
    fi
    AMD_LABEL="AMD (Mesa Vulkan / VA-API / AMDGPU) [main]"
    INTEL_LABEL="Intel (Mesa Vulkan / Media VA-API) [main]"
}

distro_apply_driver() {
    ensure_repo_context
    local choice="${GPU_CHOICE:-4}"

    case "$choice" in
        1)
            if ! repo_enabled "non-free" || ! repo_enabled "non-free-firmware"; then
                echo "==> [SKIPPED] Debian NVIDIA driver requires 'non-free' and 'non-free-firmware'."
                return 0
            fi
            echo "==> Installing Debian NVIDIA Open Kernel DKMS driver & CUDA..."
            local current_kernel
            current_kernel="$(uname -r)"
            sudo DEBIAN_FRONTEND=noninteractive apt install -y \
                "linux-headers-${current_kernel}" \
                linux-headers-amd64 \
                dkms \
                build-essential \
                firmware-misc-nonfree \
                || sudo DEBIAN_FRONTEND=noninteractive apt install -y linux-headers-amd64 dkms build-essential firmware-misc-nonfree

            sudo DEBIAN_FRONTEND=noninteractive apt install -y \
                nvidia-kernel-open-dkms \
                nvidia-driver \
                nvidia-smi \
                nvidia-settings \
                || sudo DEBIAN_FRONTEND=noninteractive apt install -y \
                    nvidia-driver \
                    nvidia-smi

            sudo DEBIAN_FRONTEND=noninteractive apt install -y \
                nvidia-persistenced \
                nvidia-cuda-toolkit \
                nvidia-vaapi-driver

            sudo systemctl enable nvidia-persistenced.service 2>/dev/null || true
            sudo systemctl enable nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service 2>/dev/null || true
            sudo update-initramfs -u

            if [[ "${NVD_TUNE:-N}" =~ ^[Yy]$ ]]; then
                "$ROOT_DIR/script/common/5060tune.sh"
            fi
            ;;
        2)
            echo "==> Installing Debian AMD GPU driver..."
            sudo DEBIAN_FRONTEND=noninteractive apt install -y \
                mesa-vulkan-drivers \
                mesa-va-drivers \
                libgl1-mesa-dri \
                xserver-xorg-video-amdgpu
            ;;
        3)
            echo "==> Installing Debian Intel GPU driver..."
            sudo DEBIAN_FRONTEND=noninteractive apt install -y \
                mesa-vulkan-drivers \
                libgl1-mesa-dri
            sudo DEBIAN_FRONTEND=noninteractive apt install -y intel-media-va-driver-non-free 2>/dev/null \
                || sudo DEBIAN_FRONTEND=noninteractive apt install -y intel-media-va-driver
            sudo DEBIAN_FRONTEND=noninteractive apt install -y i965-va-driver 2>/dev/null || true
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
            if repo_enabled "non-free" && repo_enabled "non-free-firmware"; then
                register_expected_native \
                    "linux-headers-$(uname -r)|linux-headers-amd64" \
                    dkms \
                    build-essential \
                    "nvidia-kernel-open-dkms|nvidia-kernel-dkms|nvidia-driver" \
                    "nvidia-smi|nvidia-utils-*" \
                    nvidia-persistenced \
                    nvidia-cuda-toolkit \
                    nvidia-vaapi-driver
            fi
            ;;
        2)
            register_expected_native mesa-vulkan-drivers mesa-va-drivers libgl1-mesa-dri xserver-xorg-video-amdgpu
            ;;
        3)
            register_expected_native mesa-vulkan-drivers libgl1-mesa-dri "intel-media-va-driver-non-free|intel-media-va-driver"
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
