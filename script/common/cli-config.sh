#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

echo "==> Configuring Fastfetch..."
mkdir -p "$HOME/.config/fastfetch"
cp "$ROOT_DIR/config/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"

echo "==> Configuring Kitty & JetBrainsMono Nerd Font..."
if ! fc-list 2>/dev/null | grep -i "JetBrainsMono Nerd Font" >/dev/null 2>&1; then
    echo "  -> Downloading and installing JetBrainsMono Nerd Font..."
    FONT_DIR="/usr/local/share/fonts/JetBrainsMonoNerd"
    TMP_FONT="$(mktemp /tmp/jetbrainsmono.XXXXXX.tar.xz)"
    sudo mkdir -p "$FONT_DIR"
    curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz" -o "$TMP_FONT"
    sudo tar -xJf "$TMP_FONT" -C "$FONT_DIR"
    rm -f "$TMP_FONT"
    sudo fc-cache -f
fi

mkdir -p "$HOME/.config/kitty"
cp -r "$ROOT_DIR/config/kitty/." "$HOME/.config/kitty/"

echo "==> Configuring Zsh & plugins..."
if [ ! -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ] && [ ! -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    echo "  -> Setting up zsh-autosuggestions plugin..."
    sudo mkdir -p /usr/share/zsh/plugins
    sudo rm -rf /usr/share/zsh/plugins/zsh-autosuggestions
    sudo git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions /usr/share/zsh/plugins/zsh-autosuggestions 2>/dev/null || true
fi

if [ ! -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && [ ! -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    echo "  -> Setting up zsh-syntax-highlighting plugin..."
    sudo mkdir -p /usr/share/zsh/plugins
    sudo rm -rf /usr/share/zsh/plugins/zsh-syntax-highlighting
    sudo git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting /usr/share/zsh/plugins/zsh-syntax-highlighting 2>/dev/null || true
fi

if [ -f "$HOME/.zshrc" ] && ! cmp -s "$ROOT_DIR/config/shell/.zshrc" "$HOME/.zshrc"; then
    cp "$HOME/.zshrc" "$HOME/.zshrc.bak"
fi

cp "$ROOT_DIR/config/shell/.zshrc" "$HOME/.zshrc"

TARGET_USER="${SUDO_USER:-$USER}"
ZSH_BIN="$(command -v zsh || echo "/bin/zsh")"
if [ -n "$ZSH_BIN" ]; then
    if ! grep -qxF "$ZSH_BIN" /etc/shells 2>/dev/null; then
        echo "$ZSH_BIN" | sudo tee -a /etc/shells >/dev/null
    fi
    sudo chsh -s "$ZSH_BIN" "$TARGET_USER" 2>/dev/null || sudo usermod -s "$ZSH_BIN" "$TARGET_USER" 2>/dev/null || true
fi
