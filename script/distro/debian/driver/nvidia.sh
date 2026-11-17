#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"

driver_nvidia_info() {
    if repo_enabled "non-free" && repo_enabled "non-free-firmware"; then
        NVIDIA_AVAILABLE=1
        NVIDIA_LABEL="NVIDIA (Open Kernel DKMS + CUDA) [non-free + non-free-firmware]"
    else
        NVIDIA_AVAILABLE=0
        NVIDIA_LABEL="NVIDIA [Disabled — requires non-free + non-free-firmware]"
        NVIDIA_BLOCKED_REASON="NVIDIA driver on Debian requires both 'non-free' and 'non-free-firmware' repositories."
    fi
}

driver_nvidia_install() {
    ensure_repo_context
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
}

driver_nvidia_verify() {
    ensure_repo_context
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
}

case "${1:-}" in
    --info)   driver_nvidia_info ;;
    --verify) driver_nvidia_verify ;;
    *)
        if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
            set -euo pipefail
            driver_nvidia_install
        fi
        ;;
esac
