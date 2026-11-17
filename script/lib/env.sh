#!/usr/bin/env bash

trim_whitespace() {
    local s="${1:-}"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

has_token() {
    local list="${1:-}"
    local target="${2:-}"
    [ -n "$target" ] && [[ " ${list} " == *" ${target} "* ]]
}

repo_enabled() {
    has_token "${SELECTED_REPOS:-}" "$1"
}

app_enabled() {
    has_token "${SELECTED_APPS:-}" "$1"
}

append_unique_tokens() {
    local current="${1:-}"
    shift
    local tok
    for tok in "$@"; do
        [ -n "$tok" ] || continue
        if [[ " $current " != *" $tok "* ]]; then
            current="${current:+$current }$tok"
        fi
    done
    printf '%s' "$current"
}

remove_tokens() {
    local current="${1:-}"
    shift
    local out="" tok rm_tok skip
    for tok in $current; do
        skip=0
        for rm_tok in "$@"; do
            if [ "$tok" = "$rm_tok" ]; then
                skip=1
                break
            fi
        done
        if [ "$skip" -eq 0 ]; then
            out="${out:+$out }$tok"
        fi
    done
    printf '%s' "$out"
}

detect_linux_env() {
    if [ -z "${ROOT_DIR:-}" ]; then
        ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    fi

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID="${DISTRO_ID:-${ID:-unknown}}"
        DISTRO_LIKE="${DISTRO_LIKE:-${ID_LIKE:-}}"
        DISTRO_VER="${DISTRO_VER:-${VERSION_ID:-}}"
        DISTRO_CODENAME="${DISTRO_CODENAME:-${VERSION_CODENAME:-}}"
    else
        DISTRO_ID="${DISTRO_ID:-unknown}"
        DISTRO_LIKE="${DISTRO_LIKE:-}"
        DISTRO_VER="${DISTRO_VER:-}"
        DISTRO_CODENAME="${DISTRO_CODENAME:-}"
    fi

    if [ -z "${PKG:-}" ] || [ -z "${DISTRO:-}" ]; then
        if command -v apt >/dev/null 2>&1; then
            PKG="${PKG:-apt}"
            case "$DISTRO_ID" in
                ubuntu|linuxmint|pop) DISTRO="${DISTRO:-ubuntu}" ;;
                debian)               DISTRO="${DISTRO:-debian}" ;;
                *)
                    if [[ "$DISTRO_LIKE" == *ubuntu* ]]; then
                        DISTRO="${DISTRO:-ubuntu}"
                    else
                        DISTRO="${DISTRO:-debian}"
                    fi
                    ;;
            esac
        elif command -v dnf >/dev/null 2>&1; then
            PKG="${PKG:-dnf}"
            case "$DISTRO_ID" in
                fedora)                         DISTRO="${DISTRO:-fedora}" ;;
                almalinux|rhel|rocky|centos|ol) DISTRO="${DISTRO:-almalinux}" ;;
                *)
                    if [ "$(rpm -E %fedora 2>/dev/null || echo '%fedora')" != "%fedora" ]; then
                        DISTRO="${DISTRO:-fedora}"
                    else
                        DISTRO="${DISTRO:-almalinux}"
                    fi
                    ;;
            esac
        elif command -v zypper >/dev/null 2>&1; then
            PKG="${PKG:-zypper}"
            case "$DISTRO_ID" in
                *tumbleweed*|*slowroll*) DISTRO="${DISTRO:-tumbleweed}" ;;
                *leap*|*sles*)           DISTRO="${DISTRO:-leap}" ;;
                *)
                    if grep -qi "tumbleweed" /etc/os-release 2>/dev/null; then
                        DISTRO="${DISTRO:-tumbleweed}"
                    else
                        DISTRO="${DISTRO:-leap}"
                    fi
                    ;;
            esac
        elif command -v pacman >/dev/null 2>&1; then
            PKG="${PKG:-pacman}"
            case "$DISTRO_ID" in
                cachyos) DISTRO="${DISTRO:-cachyos}" ;;
                arch|*)  DISTRO="${DISTRO:-arch}" ;;
            esac
        else
            echo "ERROR: Unsupported package manager (requires apt, dnf, zypper, or pacman)." >&2
            return 1
        fi
    fi

    case "$DISTRO" in
        rhel|rocky|centos|ol) DISTRO="almalinux" ;;
    esac

    DISTRO_DIR="$ROOT_DIR/script/distro/$DISTRO"
    export ROOT_DIR DISTRO_DIR PKG DISTRO DISTRO_ID DISTRO_LIKE DISTRO_VER DISTRO_CODENAME
}

ensure_repo_context() {
    detect_linux_env
    if [ "${REPO_MENU_DONE:-0}" != "1" ] && [ -z "${SELECTED_REPOS+x}" ]; then
        if [ -f "$DISTRO_DIR/repo.sh" ]; then
            source "$DISTRO_DIR/repo.sh" --init-defaults
        fi
    fi
}

ensure_apps_context() {
    ensure_repo_context
    if [ "${APPS_MENU_DONE:-0}" != "1" ] && [ -z "${SELECTED_APPS+x}" ]; then
        if declare -F init_default_apps >/dev/null 2>&1; then
            init_default_apps
        fi
    fi
}

install_pkg_list_with_fallback() {
    local pm="$1"
    shift
    local -a pkgs=("$@")
    [ "${#pkgs[@]}" -gt 0 ] || return 0

    case "$pm" in
        apt)
            if ! sudo DEBIAN_FRONTEND=noninteractive apt install -y "${pkgs[@]}"; then
                local p
                for p in "${pkgs[@]}"; do
                    sudo DEBIAN_FRONTEND=noninteractive apt install -y "$p" || echo "  -> [WARNING] Could not install APT package: $p"
                done
            fi
            ;;
        dnf)
            if ! sudo dnf install -y "${pkgs[@]}"; then
                local p
                for p in "${pkgs[@]}"; do
                    sudo dnf install -y "$p" || echo "  -> [WARNING] Could not install DNF package: $p"
                done
            fi
            ;;
        zypper)
            if ! sudo zypper --non-interactive --gpg-auto-import-keys install -y "${pkgs[@]}"; then
                local p
                for p in "${pkgs[@]}"; do
                    sudo zypper --non-interactive --gpg-auto-import-keys install -y "$p" || echo "  -> [WARNING] Could not install Zypper package: $p"
                done
            fi
            ;;
        pacman)
            if ! sudo pacman -S --needed --noconfirm "${pkgs[@]}"; then
                local p
                for p in "${pkgs[@]}"; do
                    sudo pacman -S --needed --noconfirm "$p" || echo "  -> [WARNING] Could not install Pacman package: $p"
                done
            fi
            ;;
    esac
}

EXPECTED_NATIVE_PKGS=()
EXPECTED_FLATPAK_PKGS=()

register_expected_native() {
    local pkg
    for pkg in "$@"; do
        [ -n "$pkg" ] || continue
        EXPECTED_NATIVE_PKGS+=("$pkg")
    done
}

register_expected_flatpak() {
    local app
    for app in "$@"; do
        [ -n "$app" ] || continue
        EXPECTED_FLATPAK_PKGS+=("$app")
    done
}
