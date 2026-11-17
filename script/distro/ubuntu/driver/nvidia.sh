#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"

driver_nvidia_info() {
    if repo_enabled "restricted"; then
        NVIDIA_AVAILABLE=1
        NVIDIA_LABEL="NVIDIA (ubuntu-drivers / nvidia-driver + CUDA) [restricted]"
    else
        NVIDIA_AVAILABLE=0
        NVIDIA_LABEL="NVIDIA [Disabled — requires restricted repository]"
        NVIDIA_BLOCKED_REASON="NVIDIA driver on Ubuntu requires the 'restricted' repository."
    fi
}

driver_nvidia_install() {
    ensure_repo_context
    if ! repo_enabled "restricted"; then
        echo "==> [SKIPPED] Ubuntu NVIDIA driver requires the 'restricted' repository."
        return 0
    fi

    echo "==> Installing Ubuntu NVIDIA driver & CUDA..."
    local current_kernel
    current_kernel="$(uname -r)"
    sudo DEBIAN_FRONTEND=noninteractive apt install -y \
        "linux-headers-${current_kernel}" \
        linux-headers-generic \
        dkms \
        build-essential \
        || sudo DEBIAN_FRONTEND=noninteractive apt install -y linux-headers-generic dkms build-essential

    if command -v ubuntu-drivers >/dev/null 2>&1; then
        sudo ubuntu-drivers install 2>/dev/null || sudo ubuntu-drivers autoinstall
    else
        sudo DEBIAN_FRONTEND=noninteractive apt install -y nvidia-driver
    fi

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
    if repo_enabled "restricted"; then
        register_expected_native \
            "linux-headers-$(uname -r)|linux-headers-generic" \
            dkms \
            build-essential \
            "nvidia-driver|nvidia-driver-*" \
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
