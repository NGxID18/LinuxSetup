#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"

driver_intel_info() {
    INTEL_LABEL="Intel (Mesa + Vulkan Intel + Media Driver) [extra]"
}

driver_intel_install() {
    ensure_repo_context
    echo "==> Installing Arch Linux Intel GPU driver..."
    sudo pacman -S --needed --noconfirm mesa vulkan-intel intel-media-driver libva-intel-driver
}

driver_intel_verify() {
    ensure_repo_context
    register_expected_native mesa vulkan-intel intel-media-driver libva-intel-driver
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
