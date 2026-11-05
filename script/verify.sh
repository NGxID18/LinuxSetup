#!/usr/bin/env bash
set -euo pipefail

if [ -z "${PKG:-}" ]; then
    if command -v apt >/dev/null 2>&1; then
        PKG="apt"
    elif command -v dnf >/dev/null 2>&1; then
        PKG="dnf"
    elif command -v pacman >/dev/null 2>&1; then
        PKG="pacman"
    else
        echo "ERROR: Unsupported package manager." >&2
        exit 1
    fi
fi

COCKPIT_PKGS=()

case "$PKG" in
    apt)
        COCKPIT_PKGS=(
            cockpit
            cockpit-podman
            cockpit-machines
            cockpit-storaged
            cockpit-packagekit
            cockpit-networkmanager
            udisks2
            udisks2-lvm2
            udisks2-btrfs
            btrfs-progs
            pcp
            packagekit
            podman
        )
        ;;
    dnf)
        COCKPIT_PKGS=(
            cockpit
            cockpit-files
            cockpit-podman
            cockpit-machines
            cockpit-storaged
            cockpit-networkmanager
            cockpit-packagekit
            cockpit-selinux
            udisks2-btrfs
            udisks2-lvm2
            btrfs-progs
            pcp
            podman
        )
        ;;
    pacman)
        COCKPIT_PKGS=(
            cockpit
            cockpit-files
            cockpit-podman
            cockpit-machines
            cockpit-storaged
            cockpit-packagekit
            packagekit
            udisks2
            udisks2-btrfs
            udisks2-lvm2
            btrfs-progs
            pcp
            mdadm
            podman
        )
        ;;
esac

is_native_installed() {
    local spec="$1"
    local candidate
    IFS='|' read -ra candidates <<< "$spec"
    for candidate in "${candidates[@]}"; do
        case "$PKG" in
            apt)
                if dpkg-query -W -f='${Status}\n' "$candidate" 2>/dev/null | grep -Fxq "install ok installed"; then
                    return 0
                fi
                ;;
            dnf)
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
echo "          COCKPIT INSTALLATION VERIFICATION       "
echo "=================================================="

TOTAL_PKGS=0
INSTALLED_PKGS=0
MISSING_PKGS=()

echo -e "\n--> Checking Cockpit Packages ($PKG):"
for pkg in "${COCKPIT_PKGS[@]}"; do
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

echo -e "\n--> Checking Modules & Extensions:"
if [ -d /usr/share/cockpit/btrfs-manager ]; then
    printf "  [\e[1;32mOK\e[0m]      btrfs-manager (/usr/share/cockpit/btrfs-manager)\n"
else
    printf "  [\e[1;31mMISSING\e[0m] btrfs-manager (/usr/share/cockpit/btrfs-manager)\n"
    MISSING_PKGS+=("btrfs-manager module")
fi

echo -e "\n--> Checking System Services:"
if systemctl is-active --quiet cockpit.socket 2>/dev/null; then
    printf "  [\e[1;32mACTIVE\e[0m]  cockpit.socket (Listening on port 9090)\n"
elif systemctl is-enabled --quiet cockpit.socket 2>/dev/null; then
    printf "  [\e[1;33mENABLED\e[0m] cockpit.socket (Will activate on next boot / socket trigger)\n"
else
    printf "  [\e[1;31mINACTIVE\e[0m] cockpit.socket\n"
    MISSING_PKGS+=("cockpit.socket service")
fi

if systemctl is-active --quiet pmproxy.service 2>/dev/null || systemctl is-active --quiet pmlogger.service 2>/dev/null; then
    printf "  [\e[1;32mACTIVE\e[0m]  PCP Metrics Services (Performance graphs enabled)\n"
else
    printf "  [\e[1;33mOPTIONAL\e[0m] PCP Metrics Services (pmproxy/pmlogger inactive or not required)\n"
fi

PERCENT=0
if [ "$TOTAL_PKGS" -gt 0 ]; then
    PERCENT=$(( (INSTALLED_PKGS * 100) / TOTAL_PKGS ))
fi

echo -e "\n--------------------------------------------------"
echo "  Installed : ${INSTALLED_PKGS} / ${TOTAL_PKGS} packages (${PERCENT}%)"
if [ "${#MISSING_PKGS[@]}" -eq 0 ]; then
    echo -e "  Status    : \e[1;32mCockpit and all dependencies are ready!\e[0m"
else
    echo -e "  Status    : \e[1;33m${#MISSING_PKGS[@]} item(s) need attention:\e[0m"
    for m in "${MISSING_PKGS[@]}"; do
        echo "              - $m"
    done
fi

echo -e "\n=================================================="
echo "          HOW TO ACCESS COCKPIT WEB CONSOLE       "
echo "=================================================="
echo "  Local Access   : https://localhost:9090"

# Detect network IPs
IP_LIST=$(ip -4 addr show 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127\.' || true)
if [ -n "$IP_LIST" ]; then
    echo "  Network Access :"
    for ip in $IP_LIST; do
        echo "                   https://$ip:9090"
    done
fi
echo "  Credentials    : Use your Linux system user and password"
echo "=================================================="
