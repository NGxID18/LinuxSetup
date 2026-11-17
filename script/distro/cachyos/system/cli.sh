#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"

system_cli_install() {
    echo "==> Installing CLI tools (Fastfetch, Kitty, Nerd Font, Zsh) on CachyOS..."
    sudo pacman -S --needed --noconfirm \
        fastfetch kitty fontconfig ttf-jetbrains-mono-nerd zsh zsh-autosuggestions zsh-syntax-highlighting
    "$ROOT_DIR/script/common/cli-config.sh"
}

system_cli_verify() {
    register_expected_native fastfetch kitty fontconfig ttf-jetbrains-mono-nerd zsh
}

case "${1:-}" in
    --verify) system_cli_verify ;;
    *)
        if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
            set -euo pipefail
            system_cli_install
        fi
        ;;
esac
