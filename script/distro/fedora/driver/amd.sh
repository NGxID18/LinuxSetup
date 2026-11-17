#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"

driver_amd_info() {
    if repo_enabled "rpmfusion-free"; then
        AMD_LABEL="AMD (Mesa Vulkan + Freeworld VA-API) [fedora + rpmfusion-free]"
    else
        AMD_LABEL="AMD (Mesa Vulkan / VA-API) [fedora]"
    fi
}

driver_amd_install() {
    ensure_repo_context
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
}

driver_amd_verify() {
    ensure_repo_context
    if repo_enabled "rpmfusion-free"; then
        register_expected_native mesa-dri-drivers mesa-vulkan-drivers "mesa-va-drivers-freeworld|mesa-va-drivers"
    else
        register_expected_native mesa-dri-drivers mesa-vulkan-drivers mesa-va-drivers
    fi
}

case "${1:-}" in
    --info)   driver_amd_info ;;
    --verify) driver_amd_verify ;;
    *)
        if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
            set -euo pipefail
            driver_amd_install
        fi
        ;;
esac
