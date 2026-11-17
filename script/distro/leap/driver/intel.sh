#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"

driver_intel_info() {
    INTEL_LABEL="Intel (Mesa DRI / Vulkan Intel / Media Driver) [repo-oss]"
}

driver_intel_install() {
    ensure_repo_context
    echo "==> Installing openSUSE Leap Intel GPU driver..."
    sudo zypper --non-interactive --gpg-auto-import-keys install -y \
        Mesa-dri libvulkan_intel intel-media-driver libva-intel-driver 2>/dev/null \
        || sudo zypper --non-interactive --gpg-auto-import-keys install -y \
            Mesa-dri libvulkan_intel intel-media-driver 2>/dev/null \
        || sudo zypper --non-interactive --gpg-auto-import-keys install -y Mesa-dri libvulkan_intel
}

driver_intel_verify() {
    ensure_repo_context
    register_expected_native Mesa-dri libvulkan_intel "intel-media-driver|libva-intel-driver"
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
