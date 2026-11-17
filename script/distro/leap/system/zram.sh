#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"

system_zram_install() {
    echo "==> Installing zRAM generator on openSUSE Leap..."
    sudo zypper --non-interactive --gpg-auto-import-keys install -y zram-generator
    "$ROOT_DIR/script/common/zram-config.sh"
}

system_zram_verify() {
    register_expected_native zram-generator
}

case "${1:-}" in
    --verify) system_zram_verify ;;
    *)
        if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
            set -euo pipefail
            system_zram_install
        fi
        ;;
esac
