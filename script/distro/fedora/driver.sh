#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"

distro_get_driver_info() {
    if ! repo_enabled "rpmfusion-nonfree"; then
        NVIDIA_AVAILABLE=0
        NVIDIA_LABEL="NVIDIA [Disabled — requires rpmfusion-nonfree]"
        NVIDIA_BLOCKED_REASON="NVIDIA driver on Fedora requires the 'rpmfusion-nonfree' repository."
    elif repo_enabled "rpmfusion-nonfree-tainted"; then
        NVIDIA_AVAILABLE=1
        NVIDIA_LABEL="NVIDIA (Open Kernel akmod-nvidia-open) [rpmfusion-nonfree-tainted]"
    else
        NVIDIA_AVAILABLE=1
        NVIDIA_LABEL="NVIDIA (Proprietary akmod-nvidia — rpmfusion-nonfree-tainted disabled) [rpmfusion-nonfree]"
    fi

    if repo_enabled "rpmfusion-free"; then
        AMD_LABEL="AMD (Mesa Vulkan + Freeworld VA-API) [fedora + rpmfusion-free]"
    else
        AMD_LABEL="AMD (Mesa Vulkan / VA-API) [fedora]"
    fi
    INTEL_LABEL="Intel (Mesa Vulkan / Media VA-API) [fedora]"
}

distro_apply_driver() {
    ensure_repo_context
    local choice="${GPU_CHOICE:-4}"

    case "$choice" in
        1)
            if ! repo_enabled "rpmfusion-nonfree"; then
                echo "==> [SKIPPED] Fedora NVIDIA driver requires 'rpmfusion-nonfree'."
                return 0
            fi
            echo "==> Installing Fedora NVIDIA driver, matching kernel headers & CUDA..."
            local current_kernel
            current_kernel="$(uname -r)"
            sudo dnf install -y \
                "kernel-devel-${current_kernel}" \
                kernel-devel \
                kernel-headers \
                kmodtool \
                akmods \
                || sudo dnf install -y kernel-devel kernel-headers kmodtool akmods

            if repo_enabled "rpmfusion-nonfree-tainted"; then
                sudo dnf install -y \
                    akmod-nvidia-open \
                    xorg-x11-drv-nvidia-cuda \
                    xorg-x11-drv-nvidia-power \
                    nvidia-settings \
                    nvidia-persistenced \
                    libva-nvidia-driver \
                    || sudo dnf install -y \
                        akmod-nvidia-open \
                        xorg-x11-drv-nvidia-cuda \
                        nvidia-persistenced \
                    || sudo dnf install -y \
                        akmod-nvidia \
                        xorg-x11-drv-nvidia-cuda \
                        nvidia-persistenced
            else
                sudo dnf install -y \
                    akmod-nvidia \
                    xorg-x11-drv-nvidia-cuda \
                    xorg-x11-drv-nvidia-power \
                    nvidia-settings \
                    nvidia-persistenced \
                    libva-nvidia-driver \
                    || sudo dnf install -y \
                        akmod-nvidia \
                        xorg-x11-drv-nvidia-cuda \
                        nvidia-persistenced
            fi

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
            ;;
        2)
            echo "==> Installing Fedora AMD GPU driver..."
            sudo dnf install -y mesa-dri-drivers mesa-vulkan-drivers
            if repo_enabled "rpmfusion-free"; then
                sudo dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld --allowerasing 2>/dev/null \
                    || sudo dnf install -y mesa-va-drivers
                sudo dnf swap -y mesa-vdpau-drivers mesa-vdpau-drivers-freeworld --allowerasing 2>/dev/null \
                    || sudo dnf install -y mesa-vdpau-drivers 2>/dev/null || true
            else
                sudo dnf install -y mesa-va-drivers
                sudo dnf install -y mesa-vdpau-drivers 2>/dev/null || true
            fi
            ;;
        3)
            echo "==> Installing Fedora Intel GPU driver..."
            sudo dnf install -y \
                mesa-dri-drivers \
                mesa-vulkan-drivers \
                intel-media-driver \
                || sudo dnf install -y mesa-dri-drivers mesa-vulkan-drivers
            sudo dnf install -y libva-intel-driver 2>/dev/null || true
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
            if repo_enabled "rpmfusion-nonfree"; then
                local nv_pkg="akmod-nvidia"
                if repo_enabled "rpmfusion-nonfree-tainted"; then
                    nv_pkg="akmod-nvidia-open|akmod-nvidia"
                fi
                register_expected_native \
                    "kernel-devel-$(uname -r)|kernel-devel" \
                    kernel-headers \
                    "$nv_pkg" \
                    xorg-x11-drv-nvidia-cuda \
                    xorg-x11-drv-nvidia-power \
                    nvidia-settings \
                    nvidia-persistenced \
                    libva-nvidia-driver
            fi
            ;;
        2)
            if repo_enabled "rpmfusion-free"; then
                register_expected_native mesa-dri-drivers mesa-vulkan-drivers "mesa-va-drivers-freeworld|mesa-va-drivers"
            else
                register_expected_native mesa-dri-drivers mesa-vulkan-drivers mesa-va-drivers
            fi
            ;;
        3)
            register_expected_native mesa-dri-drivers mesa-vulkan-drivers "intel-media-driver|libva-intel-driver"
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
