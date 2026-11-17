#!/usr/bin/env bash

reset_repo_registry() {
    REPO_CORE=""
    REPO_IDS=()
    REPO_TAGS=()
    REPO_DESCS=()
    REPO_DEFAULTS=()
    REPO_RECOMMENDED=()
}

register_repo() {
    REPO_IDS+=("$1")
    REPO_TAGS+=("$2")
    REPO_DESCS+=("$3")
    REPO_DEFAULTS+=("$4")
    REPO_RECOMMENDED+=("${5:-0}")
}

init_default_repos() {
    detect_linux_env
    if [ "${REPO_MENU_DONE:-0}" = "1" ]; then
        return 0
    fi

    reset_repo_registry
    distro_init_repos

    SELECTED_REPOS=""
    local i count="${#REPO_IDS[@]}"
    for ((i = 0; i < count; i++)); do
        if [ "${REPO_DEFAULTS[$i]}" -eq 1 ]; then
            SELECTED_REPOS="${SELECTED_REPOS:+$SELECTED_REPOS }${REPO_IDS[$i]}"
        fi
    done

    if [ -z "${AUR_HELPER:-}" ]; then
        if repo_enabled "aur-yay"; then
            AUR_HELPER="yay"
        elif repo_enabled "aur-paru"; then
            AUR_HELPER="paru"
        else
            AUR_HELPER=""
        fi
    fi

    export SELECTED_REPOS AUR_HELPER
}

apply_recommended_repos() {
    detect_linux_env
    reset_repo_registry
    distro_init_repos

    SELECTED_REPOS=""
    local i count="${#REPO_IDS[@]}"
    for ((i = 0; i < count; i++)); do
        if [ "${REPO_RECOMMENDED[$i]:-0}" -eq 1 ]; then
            SELECTED_REPOS="${SELECTED_REPOS:+$SELECTED_REPOS }${REPO_IDS[$i]}"
        fi
    done

    if repo_enabled "aur-yay"; then
        AUR_HELPER="yay"
    elif repo_enabled "aur-paru"; then
        AUR_HELPER="paru"
    else
        AUR_HELPER=""
    fi

    REPO_MENU_DONE=1
    export SELECTED_REPOS REPO_MENU_DONE AUR_HELPER
}

_repo_mutual_partner() {
    case "$1" in
        aur-paru)           echo "aur-yay" ;;
        aur-yay)            echo "aur-paru" ;;
        packman-essentials) echo "packman-full" ;;
        packman-full)       echo "packman-essentials" ;;
        *)                  echo "" ;;
    esac
}

run_repo_menu() {
    detect_linux_env
    reset_repo_registry
    distro_init_repos

    local count="${#REPO_IDS[@]}"
    local -a state=("${REPO_DEFAULTS[@]}")
    if [ "${REPO_MENU_DONE:-0}" = "1" ] && [ -n "${SELECTED_REPOS+x}" ]; then
        local idx_init
        for ((idx_init = 0; idx_init < count; idx_init++)); do
            if repo_enabled "${REPO_IDS[$idx_init]}"; then
                state[$idx_init]=1
            else
                state[$idx_init]=0
            fi
        done
    fi

    local i partner="" j=""

    if tui_is_interactive; then
        tui_enter_screen
        local cursor=0 status_msg=""

        while true; do
            printf '\e[H'
            printf '\e[1;36m========================================================================\e[0m\e[K\n'
            printf '\e[1;37m  REPOSITORY SELECTION MENU (%s %s | %s)\e[0m\e[K\n' "${DISTRO^^}" "${DISTRO_VER}" "${PKG}"
            printf '\e[1;36m========================================================================\e[0m\e[K\n'
            printf '  Legend : \e[1;32m[x]\e[0m Aktif  \e[90m[ ]\e[0m Nonaktif  \e[1;32m*Rec\e[0m Rekomendasi Pemula\e[K\n'
            printf '  Core   : \e[36m%s\e[0m (selalu aktif)\e[K\n' "${REPO_CORE}"
            printf '\e[90m------------------------------------------------------------------------\e[0m\e[K\n'
            printf '    %-3s %-4s %-4s %-25s %-13s %s\e[K\n' "#" "Stat" "Rec" "Repository" "Category" "Description"
            printf '\e[90m------------------------------------------------------------------------\e[0m\e[K\n'

            for ((i = 0; i < count; i++)); do
                local mark="[ ]" mark_col="\e[90m" rec_tag="    " rec_col="\e[90m"
                if [ "${state[$i]}" -eq 1 ]; then
                    mark="[x]"
                    mark_col="\e[1;32m"
                fi
                if [ "${REPO_RECOMMENDED[$i]:-0}" -eq 1 ]; then
                    rec_tag="*Rec"
                    rec_col="\e[1;32m"
                fi
                if [ "$i" -eq "$cursor" ]; then
                    printf '\e[7;1m> %-3s %-4s %-4s %-25s %-13s %s\e[0m\e[K\n' \
                        "$((i + 1))" "$mark" "$rec_tag" "${REPO_IDS[$i]}" "[${REPO_TAGS[$i]}]" "$(tui_truncate "${REPO_DESCS[$i]}" 26)"
                else
                    printf '  %-3s %b%-4s\e[0m %b%-4s\e[0m %-25s \e[33m%-13s\e[0m %s\e[K\n' \
                        "$((i + 1))" "$mark_col" "$mark" "$rec_col" "$rec_tag" "${REPO_IDS[$i]}" "[${REPO_TAGS[$i]}]" "$(tui_truncate "${REPO_DESCS[$i]}" 26)"
                fi
            done

            printf '\e[90m------------------------------------------------------------------------\e[0m\e[K\n'
            printf '  \e[1;36mINFO :\e[0m \e[1m%s\e[0m [%s] — %s\e[K\n' \
                "${REPO_IDS[$cursor]}" "${REPO_TAGS[$cursor]}" "$(tui_truncate "${REPO_DESCS[$cursor]}" 52)"
            if [ -n "$status_msg" ]; then
                printf '  \e[1;33m%s\e[0m\e[K\n' "$status_msg"
            else
                printf '\e[K\n'
            fi
            printf '  [↑/↓/j/k] Pilih  [Space] Centang/Lepas  [r] Rekomendasi Pemula\e[K\n'
            printf '  [d] Reset Sistem [a] Semua  [n] Kosong  [?] Bantuan  [Enter/c] Simpan\e[K\n'
            printf '\e[1;36m========================================================================\e[0m\e[J'

            status_msg=""
            tui_read_key
            case "$_TUI_KEY" in
                UP|k|K)   cursor=$(( (cursor - 1 + count) % count )) ;;
                DOWN|j|J) cursor=$(( (cursor + 1) % count )) ;;
                HOME)     cursor=0 ;;
                END)      cursor=$((count - 1)) ;;
                SPACE)
                    if [ "${state[$cursor]}" -eq 1 ]; then
                        state[$cursor]=0
                    else
                        state[$cursor]=1
                        partner="$(_repo_mutual_partner "${REPO_IDS[$cursor]}")"
                        if [ -n "$partner" ]; then
                            for ((j = 0; j < count; j++)); do
                                [ "${REPO_IDS[$j]}" = "$partner" ] && state[$j]=0
                            done
                        fi
                    fi
                    ;;
                a|A)
                    for ((i = 0; i < count; i++)); do
                        case "${REPO_IDS[$i]}" in
                            aur-yay|packman-essentials) state[$i]=0 ;;
                            *)                          state[$i]=1 ;;
                        esac
                    done
                    status_msg="Semua repository diaktifkan."
                    ;;
                n|N)
                    for ((i = 0; i < count; i++)); do
                        state[$i]=0
                    done
                    status_msg="Semua repository tambahan dinonaktifkan."
                    ;;
                r|R)
                    state=("${REPO_RECOMMENDED[@]}")
                    status_msg="Setelan Rekomendasi Pemula (*Rec) diterapkan!"
                    ;;
                d|D)
                    state=("${REPO_DEFAULTS[@]}")
                    status_msg="Direset kembali ke repository aktif di sistem Anda."
                    ;;
                \?|h|H)
                    tui_show_help_modal "repo"
                    ;;
                [1-9])
                    if [ "$_TUI_KEY" -le "$count" ]; then
                        cursor=$((_TUI_KEY - 1))
                        if [ "${state[$cursor]}" -eq 1 ]; then
                            state[$cursor]=0
                        else
                            state[$cursor]=1
                            partner="$(_repo_mutual_partner "${REPO_IDS[$cursor]}")"
                            if [ -n "$partner" ]; then
                                for ((j = 0; j < count; j++)); do
                                    [ "${REPO_IDS[$j]}" = "$partner" ] && state[$j]=0
                                done
                            fi
                        fi
                    fi
                    ;;
                ENTER|c|C|q|Q|ESC|EOF)
                    break
                    ;;
            esac
        done
        tui_leave_screen
    else
        local input="" token="" idx=""
        while true; do
            echo ""
            echo "========================================================================"
            echo "  REPOSITORY SELECTION MENU (${DISTRO^^} ${DISTRO_VER} | ${PKG})"
            echo "========================================================================"
            echo "  Always Enabled Core : ${REPO_CORE}"
            echo "------------------------------------------------------------------------"
            printf "  %-3s %-4s %-25s %-14s %s\n" "#" "Stat" "Repository" "Category" "Description"
            echo "------------------------------------------------------------------------"

            for ((i = 0; i < count; i++)); do
                local mark="[ ]"
                if [ "${state[$i]}" -eq 1 ]; then
                    mark="[x]"
                fi
                printf "  %-3s %-4s %-25s %-14s %s\n" \
                    "$((i + 1))" "$mark" "${REPO_IDS[$i]}" "[${REPO_TAGS[$i]}]" "${REPO_DESCS[$i]}"
            done

            echo "------------------------------------------------------------------------"
            echo "  Controls: [1-${count}] Toggle (e.g. '1 3' or '2,4') | [a] All | [n] None"
            echo "            [r] Recommended | [d] Reset Detected (Active) | [Enter / c] Confirm"
            echo "========================================================================"

            if ! read -rp "Action [Enter to confirm]: " input; then
                input=""
            fi
            input="$(trim_whitespace "$input")"

            case "${input,,}" in
                ""|c|confirm)
                    break
                    ;;
                a|all)
                    for ((i = 0; i < count; i++)); do
                        case "${REPO_IDS[$i]}" in
                            aur-yay|packman-essentials) state[$i]=0 ;;
                            *)                          state[$i]=1 ;;
                        esac
                    done
                    ;;
                n|none)
                    for ((i = 0; i < count; i++)); do
                        state[$i]=0
                    done
                    ;;
                r|rec|recommended)
                    state=("${REPO_RECOMMENDED[@]}")
                    ;;
                d|default)
                    state=("${REPO_DEFAULTS[@]}")
                    ;;
                *)
                    local normalized="${input//,/ }"
                    for token in $normalized; do
                        if [[ "$token" =~ ^[0-9]+$ ]] && [ "$token" -ge 1 ] && [ "$token" -le "$count" ]; then
                            idx=$((token - 1))
                            if [ "${state[$idx]}" -eq 1 ]; then
                                state[$idx]=0
                            else
                                state[$idx]=1
                                partner="$(_repo_mutual_partner "${REPO_IDS[$idx]}")"
                                if [ -n "$partner" ]; then
                                    for ((j = 0; j < count; j++)); do
                                        if [ "${REPO_IDS[$j]}" = "$partner" ]; then
                                            state[$j]=0
                                        fi
                                    done
                                fi
                            fi
                        else
                            echo "  -> Ignored invalid option: '$token'"
                        fi
                    done
                    ;;
            esac
        done
    fi

    SELECTED_REPOS=""
    for ((i = 0; i < count; i++)); do
        if [ "${state[$i]}" -eq 1 ]; then
            SELECTED_REPOS="${SELECTED_REPOS:+$SELECTED_REPOS }${REPO_IDS[$i]}"
        fi
    done

    if repo_enabled "aur-yay"; then
        AUR_HELPER="yay"
    elif repo_enabled "aur-paru"; then
        AUR_HELPER="paru"
    else
        AUR_HELPER=""
    fi

    REPO_MENU_DONE=1
    export SELECTED_REPOS REPO_MENU_DONE AUR_HELPER

    if [ "${_TUI_DEPTH:-0}" -eq 0 ]; then
        echo -e "\n==> Selected Repositories (${DISTRO}): ${SELECTED_REPOS:-none (core only)}"
    fi
}
