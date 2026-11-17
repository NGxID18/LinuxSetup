#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"

system_cockpit_install() {
    echo "==> Installing Cockpit on openSUSE Tumbleweed..."
    sudo zypper --non-interactive --gpg-auto-import-keys install -y \
        cockpit cockpit-storaged cockpit-networkmanager udisks2
    "$ROOT_DIR/script/common/cockpit-config.sh"
}

system_cockpit_verify() {
    register_expected_native cockpit cockpit-storaged cockpit-networkmanager udisks2
}

case "${1:-}" in
    --verify) system_cockpit_verify ;;
    *)
        if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
            set -euo pipefail
            system_cockpit_install
        fi
        ;;
esac
