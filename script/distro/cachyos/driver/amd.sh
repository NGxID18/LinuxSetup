#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"

driver_amd_info() {
    AMD_LABEL="AMD (Mesa + Vulkan Radeon + VA-API) [cachyos/extra]"
}

driver_amd_install() {
    ensure_repo_context
    echo "==> Installing CachyOS AMD GPU driver..."
    sudo pacman -S --needed --noconfirm mesa vulkan-radeon libva-mesa-driver xf86-video-amdgpu
}

driver_amd_verify() {
    ensure_repo_context
    register_expected_native mesa vulkan-radeon libva-mesa-driver xf86-video-amdgpu
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
