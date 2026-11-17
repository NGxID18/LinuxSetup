#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"

driver_nvidia_info() {
    if repo_enabled "nvidia"; then
        NVIDIA_AVAILABLE=1
        NVIDIA_LABEL="NVIDIA (G06 Signed Open Kernel Driver) [nvidia]"
    else
        NVIDIA_AVAILABLE=0
        NVIDIA_LABEL="NVIDIA [Disabled — requires nvidia repository]"
        NVIDIA_BLOCKED_REASON="NVIDIA driver on openSUSE Tumbleweed requires enabling the 'nvidia' repository."
    fi
}

driver_nvidia_install() {
    ensure_repo_context
    if ! repo_enabled "nvidia"; then
        echo "==> [SKIPPED] Tumbleweed NVIDIA driver requires the 'nvidia' repository."
        return 0
    fi

    echo "==> Installing openSUSE Tumbleweed NVIDIA G06 driver..."
    sudo zypper --non-interactive --gpg-auto-import-keys install -y kernel-default-devel kernel-devel 2>/dev/null \
        || sudo zypper --non-interactive --gpg-auto-import-keys install -y kernel-devel || true

    sudo zypper --non-interactive --gpg-auto-import-keys install -y --auto-agree-with-licenses \
        nvidia-open-driver-G06-signed-kmp-meta \
        nvidia-userspace-meta-G06 \
        nvidia-compute-utils-G06 \
        nvidia-persistenced \
        nvidia-settings 2>/dev/null \
        || sudo zypper --non-interactive --gpg-auto-import-keys install -y --auto-agree-with-licenses \
            nvidia-open-driver-G06-signed-kmp-default \
            nvidia-compute-utils-G06 \
            nvidia-video-G06 \
            nvidia-gl-G06 \
            nvidia-persistenced 2>/dev/null \
        || sudo zypper --non-interactive --gpg-auto-import-keys install -y --auto-agree-with-licenses \
            nvidia-driver-G06-kmp-meta \
            nvidia-userspace-meta-G06 \
            nvidia-compute-utils-G06 \
            nvidia-persistenced \
            nvidia-settings 2>/dev/null \
        || sudo zypper --non-interactive --gpg-auto-import-keys install -y --auto-agree-with-licenses \
            x11-video-nvidiaG06 \
            nvidia-computeG06 \
            nvidia-persistenced

    sudo systemctl enable nvidia-persistenced.service 2>/dev/null || true
    sudo systemctl enable nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service 2>/dev/null || true
    sudo dracut --force 2>/dev/null || true

    if command -v mokutil >/dev/null 2>&1 && mokutil --sb-state 2>/dev/null | grep -qi "enabled"; then
        echo "==> [NOTICE] UEFI Secure Boot is active on openSUSE."
        echo "    If MokManager appears upon reboot, select 'Enroll MOK' to authorize the driver signature."
    fi

    if [[ "${NVD_TUNE:-N}" =~ ^[Yy]$ ]]; then
        "$ROOT_DIR/script/common/5060tune.sh"
    fi
}

driver_nvidia_verify() {
    ensure_repo_context
    if repo_enabled "nvidia"; then
        register_expected_native \
            "kernel-default-devel|kernel-devel" \
            "nvidia-open-driver-G06-signed-kmp-meta|nvidia-open-driver-G06-signed-kmp-default|nvidia-driver-G06-kmp-meta|x11-video-nvidiaG06" \
            "nvidia-userspace-meta-G06|nvidia-compute-utils-G06|nvidia-persistenced"
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
