#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"

driver_amd_info() {
    AMD_LABEL="AMD (Mesa Vulkan / VA-API / AMDGPU) [main]"
}

driver_amd_install() {
    ensure_repo_context
    echo "==> Installing Debian AMD GPU driver..."
    sudo DEBIAN_FRONTEND=noninteractive apt install -y \
        mesa-vulkan-drivers \
        mesa-va-drivers \
        libgl1-mesa-dri \
        xserver-xorg-video-amdgpu
}

driver_amd_verify() {
    ensure_repo_context
    register_expected_native mesa-vulkan-drivers mesa-va-drivers libgl1-mesa-dri xserver-xorg-video-amdgpu
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
