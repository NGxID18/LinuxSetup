#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"

driver_intel_info() {
    INTEL_LABEL="Intel (Mesa Vulkan / Media VA-API) [fedora]"
}

driver_intel_install() {
    ensure_repo_context
    echo "==> Installing Fedora Intel GPU driver..."
    sudo dnf install -y \
        mesa-dri-drivers \
        mesa-vulkan-drivers \
        intel-media-driver \
        || sudo dnf install -y mesa-dri-drivers mesa-vulkan-drivers
    sudo dnf install -y libva-intel-driver 2>/dev/null || true
}

driver_intel_verify() {
    ensure_repo_context
    register_expected_native mesa-dri-drivers mesa-vulkan-drivers "intel-media-driver|libva-intel-driver"
}

case "${1:-}" in
    --info)   driver_intel_info ;;
    --verify) driver_intel_verify ;;
    *)
        if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
            set -euo pipefail
            driver_intel_install
        fi
        ;;
esac
