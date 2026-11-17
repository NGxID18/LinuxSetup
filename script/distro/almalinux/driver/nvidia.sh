#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"

driver_nvidia_info() {
    if repo_enabled "epel" && repo_enabled "rpmfusion-nonfree"; then
        NVIDIA_AVAILABLE=1
        NVIDIA_LABEL="NVIDIA (Open Kernel akmod-nvidia + CUDA) [epel + rpmfusion-nonfree]"
    else
        NVIDIA_AVAILABLE=0
        NVIDIA_LABEL="NVIDIA [Disabled — requires epel + rpmfusion-nonfree]"
        NVIDIA_BLOCKED_REASON="NVIDIA driver on AlmaLinux/EL requires both 'epel' and 'rpmfusion-nonfree'."
    fi
}

driver_nvidia_install() {
    ensure_repo_context
    if ! repo_enabled "epel" || ! repo_enabled "rpmfusion-nonfree"; then
        echo "==> [SKIPPED] AlmaLinux/EL NVIDIA driver requires 'epel' and 'rpmfusion-nonfree'."
        return 0
    fi

    echo "==> Installing AlmaLinux/EL NVIDIA driver, kernel headers & CUDA..."
    local current_kernel
    current_kernel="$(uname -r)"
    sudo dnf install -y \
        "kernel-devel-${current_kernel}" \
        kernel-devel \
        kernel-headers \
        kmodtool \
        akmods \
        || sudo dnf install -y kernel-devel kernel-headers kmodtool akmods

    sudo dnf install -y \
        akmod-nvidia \
        xorg-x11-drv-nvidia-cuda \
        nvidia-persistenced \
        || sudo dnf install -y \
            akmod-nvidia-open \
            xorg-x11-drv-nvidia-cuda \
            nvidia-persistenced

    sudo systemctl enable nvidia-persistenced.service 2>/dev/null || true
    sudo systemctl enable nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service 2>/dev/null || true
    sudo systemctl enable nvidia-powerd.service 2>/dev/null || true

    sudo akmods --force || true
    sudo dracut --force || true

    if command -v mokutil >/dev/null 2>&1 && mokutil --sb-state 2>/dev/null | grep -qi "enabled"; then
        echo "==> [NOTICE] UEFI Secure Boot is active."
        echo "    If module loading is rejected, enroll MOK key using:"
        echo "    sudo kmodgenca && sudo mokutil --import /etc/pki/akmods/certs/public_key.der"
    fi

    if [[ "${NVD_TUNE:-N}" =~ ^[Yy]$ ]]; then
        "$ROOT_DIR/script/common/5060tune.sh"
    fi
}

driver_nvidia_verify() {
    ensure_repo_context
    if repo_enabled "epel" && repo_enabled "rpmfusion-nonfree"; then
        register_expected_native \
            "kernel-devel-$(uname -r)|kernel-devel" \
            kernel-headers \
            "akmod-nvidia|akmod-nvidia-open" \
            xorg-x11-drv-nvidia-cuda \
            nvidia-persistenced
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
