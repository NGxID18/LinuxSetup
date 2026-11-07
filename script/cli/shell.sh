#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing Zsh & plugins ($PKG | ${DISTRO:-$PKG})..."
case "$PKG" in
    apt)
        case "${DISTRO:-debian}" in
            ubuntu|debian|*)
                sudo DEBIAN_FRONTEND=noninteractive apt install -y \
                    zsh \
                    zsh-autosuggestions \
                    zsh-syntax-highlighting
                ;;
        esac
        ;;
    dnf)
        case "${DISTRO:-fedora}" in
            fedora|rhel|*)
                sudo dnf install -y \
                    zsh \
                    zsh-autosuggestions \
                    zsh-syntax-highlighting
                ;;
        esac
        ;;
    zypper)
        case "${DISTRO:-tumbleweed}" in
            tumbleweed|leap|*)
                sudo zypper --non-interactive --gpg-auto-import-keys install -y zsh
                sudo zypper --non-interactive --gpg-auto-import-keys install -y \
                    zsh-autosuggestions \
                    zsh-syntax-highlighting 2>/dev/null || true
                ;;
        esac
        ;;
    pacman)
        case "${DISTRO:-arch}" in
            cachyos|arch|*)
                sudo pacman -S --needed --noconfirm \
                    zsh \
                    zsh-autosuggestions \
                    zsh-syntax-highlighting
                ;;
        esac
        ;;
esac

# Ensure plugins exist across all distributions (fallback for zypper or minimal environments)
if [ ! -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ] && [ ! -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    echo "==> Setting up zsh-autosuggestions plugin..."
    sudo mkdir -p /usr/share/zsh/plugins
    sudo git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions /usr/share/zsh/plugins/zsh-autosuggestions 2>/dev/null || true
fi

if [ ! -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && [ ! -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    echo "==> Setting up zsh-syntax-highlighting plugin..."
    sudo mkdir -p /usr/share/zsh/plugins
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
