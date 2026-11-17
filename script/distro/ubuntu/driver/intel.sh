#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"

driver_intel_info() {
    INTEL_LABEL="Intel (Mesa Vulkan / Media VA-API) [main]"
}

driver_intel_install() {
    ensure_repo_context
    echo "==> Installing Ubuntu Intel GPU driver..."
    sudo DEBIAN_FRONTEND=noninteractive apt install -y \
        mesa-vulkan-drivers \
        libgl1-mesa-dri
    sudo DEBIAN_FRONTEND=noninteractive apt install -y intel-media-va-driver-non-free 2>/dev/null \
        || sudo DEBIAN_FRONTEND=noninteractive apt install -y intel-media-va-driver
    sudo DEBIAN_FRONTEND=noninteractive apt install -y i965-va-driver 2>/dev/null || true
}

driver_intel_verify() {
    ensure_repo_context
    register_expected_native mesa-vulkan-drivers libgl1-mesa-dri "intel-media-va-driver-non-free|intel-media-va-driver"
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
