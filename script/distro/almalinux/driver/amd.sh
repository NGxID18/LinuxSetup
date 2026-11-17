#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"

driver_amd_info() {
    AMD_LABEL="AMD (Mesa Vulkan / VA-API) [appstream]"
}

driver_amd_install() {
    ensure_repo_context
    echo "==> Installing AlmaLinux/EL AMD GPU driver..."
    sudo dnf install -y mesa-dri-drivers mesa-vulkan-drivers
    sudo dnf install -y mesa-va-drivers 2>/dev/null || true
}

driver_amd_verify() {
    ensure_repo_context
    register_expected_native mesa-dri-drivers mesa-vulkan-drivers
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
