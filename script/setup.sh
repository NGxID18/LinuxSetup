#!/usr/bin/env bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/script/lib/tui.sh"
detect_linux_env

_resolve_initial_de_choice() {
    local requested="${1:-gnome}"
    DE_CHOICE="$requested"
    if [ ! -f "$DISTRO_DIR/de/${DE_CHOICE}.sh" ] && [ "$DE_CHOICE" != "none" ]; then
        DE_CHOICE="none"
        local f
        for f in "$DISTRO_DIR"/de/*.sh; do
            [ -f "$f" ] || continue
            DE_CHOICE="$(basename "$f" .sh)"
            break
        done
    fi
    [ "$DE_CHOICE" = "gnome" ] && INSTALL_GNOME="Y" || INSTALL_GNOME="N"
}

refresh_repo_dependent_defaults() {
    detect_linux_env

    NVIDIA_AVAILABLE=1
    [ -f "$DISTRO_DIR/driver/nvidia.sh" ] && source "$DISTRO_DIR/driver/nvidia.sh" --info

    if [ "${_GPU_USER_SET:-0}" -eq 0 ]; then
        if has_nvidia_gpu && [ "${NVIDIA_AVAILABLE:-1}" -eq 1 ]; then
            GPU_CHOICE=1; GPU_VENDOR="nvidia"
        elif has_amd_gpu; then
            GPU_CHOICE=2; GPU_VENDOR="amd"
        elif has_intel_gpu; then
            GPU_CHOICE=3; GPU_VENDOR="intel"
        else
            GPU_CHOICE=4; GPU_VENDOR="none"
        fi
        NVD_TUNE="${NVD_TUNE:-N}"
    elif [ "${GPU_CHOICE:-4}" = "1" ] && [ "${NVIDIA_AVAILABLE:-1}" -eq 0 ]; then
        GPU_CHOICE=4
        GPU_VENDOR="none"
        NVD_TUNE="N"
    fi

    if [ -f "$DISTRO_DIR/apps.sh" ]; then
        if [ "${_APPS_CUSTOMIZED:-0}" -eq 0 ]; then
            init_default_apps
        else
            _populate_default_apps_registry
            local count="${#APP_IDS[@]}" i filtered="" tok
            for tok in ${SELECTED_APPS:-}; do
                for ((i = 0; i < count; i++)); do
                    if [ "${APP_IDS[$i]}" = "$tok" ]; then
                        filtered="${filtered:+$filtered }$tok"
                        break
                    fi
                done
            done
            SELECTED_APPS="$filtered"
            if [ -n "${SELECTED_APPS:-}" ] || [ -n "${EXTRA_NATIVE_PKGS:-}" ] || [ -n "${EXTRA_FLATPAK_PKGS:-}" ]; then
                INSTALL_APPS="Y"
            else
                INSTALL_APPS="N"
            fi
        fi
    fi
}

init_setup_defaults() {
    detect_linux_env
    if [ "${REPO_MENU_DONE:-0}" != "1" ]; then
        source "$DISTRO_DIR/repo.sh" --init-defaults
    fi

    _resolve_initial_de_choice "${DE_CHOICE:-gnome}"

    INSTALL_COCKPIT="${INSTALL_COCKPIT:-N}"
    INSTALL_CLI="${INSTALL_CLI:-Y}"
    EXTRA_NATIVE_PKGS="${EXTRA_NATIVE_PKGS:-}"
    EXTRA_FLATPAK_PKGS="${EXTRA_FLATPAK_PKGS:-}"

    _detect_recommended_zram
    ZRAM_CHOICE="${ZRAM_CHOICE:-$_REC_ZRAM_CHOICE}"
    ZRAM_SIZE="${ZRAM_SIZE:-$_REC_ZRAM_SIZE}"

    _GPU_USER_SET=0
    _APPS_CUSTOMIZED=0
    refresh_repo_dependent_defaults
}

apply_recommended_preset() {
    detect_linux_env
    source "$DISTRO_DIR/repo.sh" ""
    apply_recommended_repos

    _resolve_initial_de_choice "gnome"

    INSTALL_COCKPIT="N"
    INSTALL_CLI="Y"

    _detect_recommended_zram
    ZRAM_CHOICE="$_REC_ZRAM_CHOICE"
    ZRAM_SIZE="$_REC_ZRAM_SIZE"

    _GPU_USER_SET=0
    _APPS_CUSTOMIZED=0
    NVD_TUNE="N"
    refresh_repo_dependent_defaults
}

_dashboard_item_help() {
    case "$1" in
        0)
            printf '%s\n' \
                "Package & app download sources. Press [Enter] to configure manually," \
                "or press [r] to auto-enable all recommended (*Rec) repositories."
            ;;
        1)
            printf '%s\n' \
                "Graphics card drivers (NVIDIA/AMD/Intel) for gaming, display & video." \
                "Automatically detects the GPU installed on your machine."
            ;;
        2)
            printf '%s\n' \
                "Graphical desktop environment (Minimal GNOME + GDM + wallpapers)." \
                "Choose Skip for headless servers or if you already have a desktop."
            ;;
        3)
            printf '%s\n' \
                "Browser-based server admin panel (port 9090). Press [Space/Enter]" \
                "to toggle. Recommended to keep Disabled on daily desktop/laptops."
            ;;
        4)
            printf '%s\n' \
                "Pick daily apps (Steam, Discord, OBS, VSCodium, etc.) and live-search" \
                "additional native/AUR/Flathub packages. Press [Enter] to open."
            ;;
        5)
            printf '%s\n' \
                "Enhance your terminal with Kitty, Fastfetch, JetBrainsMono Nerd Font," \
                "and Zsh (with autosuggestions & syntax highlighting)."
            ;;
        6)
            printf '%s\n' \
                "Fast compressed swap in RAM (zstd) for smoother multitasking." \
                "Default size is automatically matched to your physical RAM."
            ;;
        7)
            printf '%s\n' \
                "READY? Press [Enter] here (or press [i] anytime) to begin" \
                "automated installation and post-install package verification."
            ;;
        *)
            printf '%s\n' \
                "Cancel and exit the installer without making any changes to your" \
                "system (or press [q] / [ESC] anytime)."
            ;;
    esac
}

run_setup_dashboard() {
    detect_linux_env

    if tui_is_interactive; then
        init_setup_defaults
        tui_enter_screen

        local cursor=0 status_msg="" gpu_summary=""
        gpu_summary="$(detect_gpu_summary)"

        while true; do
            local repo_count=0 tok
            for tok in ${SELECTED_REPOS:-}; do repo_count=$((repo_count + 1)); done
            local repo_val="${repo_count} enabled (${SELECTED_REPOS:-core only})"

            local gpu_val="Skip"
            case "${GPU_VENDOR:-none}" in
                nvidia)
                    gpu_val="NVIDIA"
                    if is_rtx_5060_present; then
                        [[ "${NVD_TUNE:-N}" =~ ^[Yy]$ ]] && gpu_val="$gpu_val [5060tune: ON]" || gpu_val="$gpu_val [5060tune: OFF]"
                    fi
                    ;;
                amd)    gpu_val="AMD" ;;
                intel)  gpu_val="Intel" ;;
            esac

            local de_val="Skip (None)"
            if [ "${DE_CHOICE:-none}" != "none" ]; then
                de_val="${DE_CHOICE^^} Minimal"
                if [ -f "$DISTRO_DIR/de/${DE_CHOICE}.sh" ]; then
                    DE_LABEL=""
                    source "$DISTRO_DIR/de/${DE_CHOICE}.sh" --info
                    [ -n "${DE_LABEL:-}" ] && de_val="$DE_LABEL"
                fi
            fi

            local cockpit_val="Disabled"
            [[ "${INSTALL_COCKPIT:-N}" =~ ^[Yy]$ ]] && cockpit_val="Enabled (port 9090)"

            local app_count=0 extra_count=0
            for tok in ${SELECTED_APPS:-}; do app_count=$((app_count + 1)); done
            for tok in ${EXTRA_NATIVE_PKGS:-} ${EXTRA_FLATPAK_PKGS:-}; do extra_count=$((extra_count + 1)); done
            local apps_val="${app_count} preset(s)"
            [ "$extra_count" -gt 0 ] && apps_val="${apps_val} + ${extra_count} custom"

            local cli_val="Disabled"
            [[ "${INSTALL_CLI:-Y}" =~ ^[Yy]$ ]] && cli_val="Enabled (Fastfetch, Kitty, Zsh)"

            local zram_val="Skip"
            [ -n "${ZRAM_SIZE:-}" ] && zram_val="$((ZRAM_SIZE / 1024)) GB (${ZRAM_SIZE} MB zstd)"

            local -a labels=(
                "1) Repositories"
                "2) GPU Driver"
                "3) Desktop / GUI"
                "4) Cockpit Web Console"
                "5) Applications"
                "6) CLI Stack"
                "7) zRAM Swap (zstd)"
                "8) >> Start Installation & Provision System <<"
                "9) Quit / Abort Setup"
            )
            local -a values=(
                "$(tui_truncate "$repo_val" 42)"
                "$(tui_truncate "$gpu_val" 42)"
                "$(tui_truncate "$de_val" 42)"
                "$cockpit_val"
                "$apps_val"
                "$cli_val"
                "$zram_val"
                ""
                ""
            )

            local help_line1="" help_line2=""
            {
                IFS= read -r help_line1 || true
                IFS= read -r help_line2 || true
            } < <(_dashboard_item_help "$cursor")

            printf '\e[H'
            printf '\e[1;36m========================================================================\e[0m\e[K\n'
            printf '\e[1;37m  LINUX PROVISIONING DASHBOARD (%s %s | %s)\e[0m\e[K\n' "${DISTRO^^}" "${DISTRO_VER}" "${PKG}"
            printf '\e[1;36m========================================================================\e[0m\e[K\n'
            printf '  \e[1;32mQuick Start:\e[0m Press \e[1;33m[r]\e[0m for Recommended Preset, then \e[1;33m[i]\e[0m to Install!\e[K\n'
            printf '  Hardware   : GPU: \e[36m%s\e[0m\e[K\n' "$(tui_truncate "$gpu_summary" 54)"
            printf '               RAM: \e[36m%s\e[0m\e[K\n' "${_REC_ZRAM_RAM_LABEL:-Unknown}"
            printf '\e[90m------------------------------------------------------------------------\e[0m\e[K\n'

            local i
            for ((i = 0; i < 9; i++)); do
                if [ "$i" -eq 7 ]; then
                    printf '\e[90m------------------------------------------------------------------------\e[0m\e[K\n'
                fi
                if [ "$i" -eq "$cursor" ]; then
                    if [ "$i" -ge 7 ]; then
                        printf '\e[7;1m> %-68s\e[0m\e[K\n' "${labels[$i]}"
                    else
                        printf '\e[7;1m> %-24s : %-41s\e[0m\e[K\n' "${labels[$i]}" "${values[$i]}"
                    fi
                else
                    if [ "$i" -eq 7 ]; then
                        printf '  \e[1;32m%-68s\e[0m\e[K\n' "${labels[$i]}"
                    elif [ "$i" -eq 8 ]; then
                        printf '  \e[1;31m%-68s\e[0m\e[K\n' "${labels[$i]}"
                    else
                        printf '  %-24s : \e[36m%-41s\e[0m\e[K\n' "${labels[$i]}" "${values[$i]}"
                    fi
                fi
            done

            printf '\e[90m------------------------------------------------------------------------\e[0m\e[K\n'
            printf '  \e[1;36mFEATURE INFO & GUIDE:\e[0m\e[K\n'
            printf '    %s\e[K\n' "$help_line1"
            printf '    %s\e[K\n' "$help_line2"
            if [ -n "$status_msg" ]; then
                printf '  \e[1;33m-> %s\e[0m\e[K\n' "$status_msg"
            else
                printf '\e[K\n'
            fi
            printf '  [↑/↓/j/k] Move   [Enter/Space] Open/Toggle  [r] Recommended Preset\e[K\n'
            printf '  [1-9] Jump #     [i] Start Install          [?] Help      [q/ESC] Quit\e[K\n'
            printf '\e[1;36m========================================================================\e[0m\e[J'

            status_msg=""
            tui_read_key
            local action="$cursor"
            case "$_TUI_KEY" in
                UP|k|K)      cursor=$(( (cursor - 1 + 9) % 9 )); continue ;;
                DOWN|j|J)    cursor=$(( (cursor + 1) % 9 )); continue ;;
                HOME)        cursor=0; continue ;;
                END)         cursor=8; continue ;;
                \?|h|H)      tui_show_help_modal "dashboard"; continue ;;
                r|R)
                    apply_recommended_preset
                    status_msg="Recommended preset applied! Press [i] or #8 to start installation."
                    continue
                    ;;
                [1-9])       cursor=$((_TUI_KEY - 1)); action="$cursor" ;;
                ENTER|SPACE) action="$cursor" ;;
                i|I)         action=7 ;;
                q|Q|ESC|EOF) action=8 ;;
                *)           continue ;;
            esac

            case "$action" in
                0)
                    REPO_MENU_DONE=1
                    source "$DISTRO_DIR/repo.sh" --menu
                    refresh_repo_dependent_defaults
                    ;;
                1)
                    run_driver_menu
                    ;;
                2)
                    run_de_menu
                    ;;
                3)
                    if [[ "${INSTALL_COCKPIT:-N}" =~ ^[Yy]$ ]]; then
                        INSTALL_COCKPIT="N"
                        status_msg="Cockpit Web Console disabled."
                    else
                        INSTALL_COCKPIT="Y"
                        status_msg="Cockpit Web Console enabled (port 9090)."
                    fi
                    ;;
                4)
                    APPS_MENU_DONE=1
                    source "$DISTRO_DIR/apps.sh" --menu
                    ;;
                5)
                    if [[ "${INSTALL_CLI:-Y}" =~ ^[Yy]$ ]]; then
                        INSTALL_CLI="N"
                        status_msg="CLI Stack disabled."
                    else
                        INSTALL_CLI="Y"
                        status_msg="CLI Stack enabled (Fastfetch, Kitty, Zsh)."
                    fi
                    ;;
                6)
                    run_zram_menu
                    ;;
                7)
                    break
                    ;;
                8)
                    tui_leave_screen --force
                    echo "==> Setup aborted by user."
                    exit 0
                    ;;
            esac
        done

        tui_leave_screen
        echo ""

        REPO_MENU_DONE=1
        APPS_MENU_DONE=1
        if [ -n "${SELECTED_APPS:-}" ] || [ -n "${EXTRA_NATIVE_PKGS:-}" ] || [ -n "${EXTRA_FLATPAK_PKGS:-}" ]; then
            INSTALL_APPS="Y"
        else
            INSTALL_APPS="N"
        fi

        echo "=================================================="
        echo "         LINUX PROVISIONING CONFIGURATION         "
        echo "=================================================="
        echo "  Repositories : ${SELECTED_REPOS:-core only}"
        echo "  GPU Driver   : ${GPU_VENDOR:-none} (5060tune: ${NVD_TUNE:-N})"
        echo "  Desktop/GUI  : ${DE_CHOICE:-none}"
        echo "  Cockpit      : ${INSTALL_COCKPIT:-N}"
        echo "  Applications : ${SELECTED_APPS:-none}"
        [ -n "${EXTRA_NATIVE_PKGS:-}" ]  && echo "  Extra Native : ${EXTRA_NATIVE_PKGS}"
        [ -n "${EXTRA_FLATPAK_PKGS:-}" ] && echo "  Extra Flatpak: ${EXTRA_FLATPAK_PKGS}"
        echo "  CLI Stack    : ${INSTALL_CLI:-Y}"
        echo "  zRAM Swap    : ${ZRAM_SIZE:-skip}"
        echo "=================================================="
    else
        echo "=================================================="
        echo "         LINUX PROVISIONING SETUP MENU            "
        echo "=================================================="

        echo -e "\n[1/7] Configure Repositories:"
        source "$DISTRO_DIR/repo.sh" --menu

        echo -e "\n[2/7] Configure GPU Driver:"
        run_driver_menu

        echo -e "\n[3/7] Configure Desktop Environment / GUI:"
        run_de_menu

        echo -e "\n[4/7] Install Cockpit Web Console (Server Web UI on port 9090)?"
        if ! read -rp "Choice [y/N]: " INSTALL_COCKPIT; then
            INSTALL_COCKPIT="N"
        fi
        INSTALL_COCKPIT="${INSTALL_COCKPIT:-N}"

        echo -e "\n[5/7] Configure Applications (Native / AUR / Flatpak):"
        source "$DISTRO_DIR/apps.sh" --menu

        echo -e "\n[6/7] Configure CLI (Fastfetch, Kitty, Zsh)?"
        if ! read -rp "Choice [Y/n]: " INSTALL_CLI; then
            INSTALL_CLI="Y"
        fi
        INSTALL_CLI="${INSTALL_CLI:-Y}"

        echo -e "\n[7/7] Configure zRAM Swap (zstd compression):"
        run_zram_menu
    fi

    export SELECTED_REPOS REPO_MENU_DONE GPU_CHOICE GPU_VENDOR NVD_TUNE DE_CHOICE AUR_HELPER INSTALL_GNOME INSTALL_COCKPIT INSTALL_APPS SELECTED_APPS EXTRA_NATIVE_PKGS EXTRA_FLATPAK_PKGS APPS_MENU_DONE INSTALL_CLI ZRAM_CHOICE ZRAM_SIZE
}

run_setup_dashboard
