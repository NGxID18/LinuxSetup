#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"
detect_linux_env
ensure_repo_context

GPU_CHOICE="${GPU_CHOICE:-4}"
INSTALL_GNOME="${INSTALL_GNOME:-Y}"
INSTALL_COCKPIT="${INSTALL_COCKPIT:-Y}"
INSTALL_APPS="${INSTALL_APPS:-Y}"
INSTALL_CLI="${INSTALL_CLI:-Y}"
ZRAM_CHOICE="${ZRAM_CHOICE:-5}"

EXPECTED_NATIVE_PKGS=()
EXPECTED_FLATPAK_PKGS=()

source "$DISTRO_DIR/repo.sh" --verify
source "$DISTRO_DIR/driver.sh" --verify
source "$DISTRO_DIR/apps.sh" --verify

is_flatpak_installed() {
    flatpak info "$1" >/dev/null 2>&1
}

is_native_installed() {
    local spec="$1"
    local candidate
    IFS='|' read -ra candidates <<< "$spec"
    for candidate in "${candidates[@]}"; do
        if [[ "$candidate" == flatpak:* ]]; then
            if is_flatpak_installed "${candidate#flatpak:}"; then
                return 0
            fi
            continue
        fi
        case "$PKG" in
            apt)
                if dpkg-query -W -f='${Status}\n' "$candidate" 2>/dev/null | grep -Fxq "install ok installed"; then
                    return 0
                fi
                ;;
            dnf|zypper)
                if rpm -q "$candidate" >/dev/null 2>&1 || rpm -q --whatprovides "$candidate" >/dev/null 2>&1; then
                    return 0
                fi
                ;;
            pacman)
                if pacman -Qq "$candidate" >/dev/null 2>&1 || pacman -Qg "$candidate" >/dev/null 2>&1 || pacman -T "$candidate" >/dev/null 2>&1; then
                    return 0
                fi
                ;;
        esac
    done
    return 1
}

echo -e "\n=================================================="
echo "           INSTALLATION VERIFICATION              "
echo "=================================================="

declare -A SEEN_NATIVE=()
declare -A SEEN_FLATPAK=()

TOTAL_PKGS=0
INSTALLED_PKGS=0
MISSING_PKGS=()

echo -e "\n--> Checking Native Packages ($PKG | $DISTRO):"
for pkg in "${EXPECTED_NATIVE_PKGS[@]}"; do
    [ -n "${SEEN_NATIVE[$pkg]:-}" ] && continue
    SEEN_NATIVE[$pkg]=1
    TOTAL_PKGS=$((TOTAL_PKGS + 1))
    LABEL="${pkg%%|*}"

    if is_native_installed "$pkg"; then
        printf "  [\e[1;32mOK\e[0m]      %s\n" "$LABEL"
        INSTALLED_PKGS=$((INSTALLED_PKGS + 1))
    else
        printf "  [\e[1;31mMISSING\e[0m] %s\n" "$LABEL"
        MISSING_PKGS+=("$LABEL ($PKG)")
    fi
done

if [ "${#EXPECTED_FLATPAK_PKGS[@]}" -gt 0 ]; then
    echo -e "\n--> Checking Flatpak Packages:"
    for app in "${EXPECTED_FLATPAK_PKGS[@]}"; do
        [ -n "${SEEN_FLATPAK[$app]:-}" ] && continue
        SEEN_FLATPAK[$app]=1
        TOTAL_PKGS=$((TOTAL_PKGS + 1))

        if is_flatpak_installed "$app"; then
            printf "  [\e[1;32mOK\e[0m]      %s\n" "$app"
            INSTALLED_PKGS=$((INSTALLED_PKGS + 1))
        else
            printf "  [\e[1;31mMISSING\e[0m] %s\n" "$app"
            MISSING_PKGS+=("$app (flatpak)")
        fi
    done
fi

PERCENT=0
if [ "$TOTAL_PKGS" -gt 0 ]; then
    PERCENT=$(( (INSTALLED_PKGS * 100) / TOTAL_PKGS ))
fi

echo "--------------------------------------------------"
echo "  Installed : ${INSTALLED_PKGS} / ${TOTAL_PKGS} packages (${PERCENT}%)"
if [ "${#MISSING_PKGS[@]}" -eq 0 ]; then
    echo -e "  Status    : \e[1;32mAll selected dependencies are installed!\e[0m"
else
    echo -e "  Status    : \e[1;33m${#MISSING_PKGS[@]} package(s) missing:\e[0m"
    for m in "${MISSING_PKGS[@]}"; do
        echo "              - $m"
    done
fi
echo "=================================================="
