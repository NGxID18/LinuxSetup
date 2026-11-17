#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"

driver_amd_info() {
    AMD_LABEL="AMD (Mesa DRI / Vulkan Radeon / VA-API) [repo-oss]"
}

driver_amd_install() {
    ensure_repo_context
    echo "==> Installing openSUSE Leap AMD GPU driver..."
    sudo zypper --non-interactive --gpg-auto-import-keys install -y \
        Mesa-dri Mesa-libva libvulkan_radeon xf86-video-amdgpu 2>/dev/null \
        || sudo zypper --non-interactive --gpg-auto-import-keys install -y Mesa-dri libvulkan_radeon
}

driver_amd_verify() {
    ensure_repo_context
    register_expected_native Mesa-dri "Mesa-libva|libvulkan_radeon" libvulkan_radeon
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
