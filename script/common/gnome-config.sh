#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

sudo systemctl set-default graphical.target

echo "==> Installing wallpapers & registering with GNOME..."
WP_DEST="/usr/share/backgrounds/Wallpapers"
XML_DIR="/usr/share/gnome-background-properties"
XML_FILE="$XML_DIR/linuxsetup-wallpapers.xml"

sudo mkdir -p "$WP_DEST" "$XML_DIR"
if [ -d "$ROOT_DIR/Wallpapers" ]; then
    sudo cp -r "$ROOT_DIR/Wallpapers/." "$WP_DEST/"
    sudo chmod 755 "$WP_DEST"
    sudo find "$WP_DEST" -type f -exec chmod 644 {} +

    {
        echo '<?xml version="1.0" encoding="UTF-8"?>'
        echo '<!DOCTYPE wallpapers SYSTEM "gnome-wp-list.dtd">'
        echo '<wallpapers>'
        for wp in "$WP_DEST"/*; do
            [ -f "$wp" ] || continue
            wp_base="$(basename "$wp")"
            wp_name="${wp_base%.*}"
            echo '  <wallpaper deleted="false">'
            echo "    <name>${wp_name}</name>"
            echo "    <filename>${wp}</filename>"
            echo '    <options>zoom</options>'
            echo '  </wallpaper>'
        done
        echo '</wallpapers>'
    } | sudo tee "$XML_FILE" > /dev/null
    sudo chmod 644 "$XML_FILE"
fi

echo "==> Installing GNOME extensions globally (for all users)..."
SHELL_VER="$(gnome-shell --version 2>/dev/null | awk '{print $3}' | cut -d. -f1 || true)"
EXTENSIONS=(
    "blur-my-shell@aunetx"
    "Vitals@CoreCoding.com"
    "appindicatorsupport@rgcjonas.gmail.com"
)

SYS_EXT_DIR="/usr/share/gnome-shell/extensions"
sudo mkdir -p "$SYS_EXT_DIR" /usr/share/glib-2.0/schemas

for uuid in "${EXTENSIONS[@]}"; do
    DL_PATH=""
    if [ -n "$SHELL_VER" ]; then
        INFO_URL="https://extensions.gnome.org/extension-info/?uuid=${uuid}&shell_version=${SHELL_VER}"
        DL_PATH="$(curl -fsSL "$INFO_URL" 2>/dev/null | sed -n 's/.*"download_url":[[:space:]]*"\([^"]*\)".*/\1/p' || true)"
    fi

    if [ -z "$DL_PATH" ]; then
        INFO_URL="https://extensions.gnome.org/extension-info/?uuid=${uuid}"
        DL_PATH="$(curl -fsSL "$INFO_URL" 2>/dev/null | sed -n 's/.*"download_url":[[:space:]]*"\([^"]*\)".*/\1/p' || true)"
    fi

    if [ -n "$DL_PATH" ]; then
        echo "  -> Downloading global extension: $uuid..."
        TMP_ZIP="$(mktemp "/tmp/${uuid}.XXXXXX.zip")"
        if curl -fsSL "https://extensions.gnome.org${DL_PATH}" -o "$TMP_ZIP"; then
            TARGET_DIR="$SYS_EXT_DIR/$uuid"
            sudo rm -rf "$TARGET_DIR"
            sudo mkdir -p "$TARGET_DIR"
            sudo unzip -qo "$TMP_ZIP" -d "$TARGET_DIR"

            if [ -d "$TARGET_DIR/schemas" ]; then
                sudo glib-compile-schemas "$TARGET_DIR/schemas" 2>/dev/null || true
                sudo cp "$TARGET_DIR"/schemas/*.gschema.xml /usr/share/glib-2.0/schemas/ 2>/dev/null || true
            fi

            sudo chmod 755 "$TARGET_DIR"
            sudo find "$TARGET_DIR" -type d -exec chmod 755 {} +
            sudo find "$TARGET_DIR" -type f -exec chmod 644 {} +
        fi
        rm -f "$TMP_ZIP"
    else
        echo "  -> [WARNING] Failed to resolve download URL for extension: $uuid"
    fi
done

sudo glib-compile-schemas /usr/share/glib-2.0/schemas/ 2>/dev/null || true

sudo mkdir -p /etc/dconf/profile /etc/dconf/db/local.d
if [ ! -f /etc/dconf/profile/user ]; then
    sudo tee /etc/dconf/profile/user > /dev/null <<'EOF'
user-db:user
system-db:local
EOF
fi

sudo tee /etc/dconf/db/local.d/00-extensions > /dev/null <<'EOF'
[org/gnome/shell]
disable-user-extensions=false
disable-extension-version-validation=true
enabled-extensions=['blur-my-shell@aunetx', 'Vitals@CoreCoding.com', 'appindicatorsupport@rgcjonas.gmail.com']
EOF

if command -v dconf >/dev/null 2>&1; then
    sudo dconf update 2>/dev/null || true
fi
