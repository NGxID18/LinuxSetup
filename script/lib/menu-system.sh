#!/usr/bin/env bash

_driver_item_help() {
    case "$1" in
        0) printf '%s' "Driver khusus GPU NVIDIA (+ CUDA/Open Kernel). Jika masih [DISABLED], aktifkan repo yg diminta." ;;
        1) printf '%s' "Driver open-source Mesa Vulkan & akselerasi video VA-API untuk GPU AMD Radeon." ;;
        2) printf '%s' "Driver open-source Mesa Vulkan & Media VA-API untuk iGPU Intel / Intel Arc." ;;
        *) printf '%s' "Lewati pemasangan driver GPU (cocok untuk Virtual Machine atau pertahankan driver saat ini)." ;;
    esac
}

_tui_select_single() {
    local title="$1"
    local help_topic="$2"
    local cursor="$3"
    local cancel_idx="$4"
    local count="${#_SINGLE_OPTS[@]}"
    local status_msg="" i line

    tui_enter_screen
    while true; do
        printf '\e[H'
        printf '\e[1;36m========================================================================\e[0m\e[K\n'
        printf '\e[1;37m  %s\e[0m\e[K\n' "$title"
        printf '\e[1;36m========================================================================\e[0m\e[K\n'
        for line in "${_SINGLE_SUBTITLES[@]}"; do
            printf '%b\e[K\n' "$line"
        done
        if [ "${#_SINGLE_SUBTITLES[@]}" -gt 0 ]; then
            printf '\e[90m------------------------------------------------------------------------\e[0m\e[K\n'
        fi

        for ((i = 0; i < count; i++)); do
            if [ "$i" -eq "$cursor" ]; then
                printf '\e[7;1m> %d) %s\e[0m\e[K\n' "$((i + 1))" "${_SINGLE_OPTS[$i]}"
            elif [ -n "${_SINGLE_DISABLED[$i]:-}" ]; then
                printf '  \e[90m%d) %s\e[0m\e[K\n' "$((i + 1))" "${_SINGLE_OPTS[$i]}"
            else
                printf '  %d) %s\e[K\n' "$((i + 1))" "${_SINGLE_OPTS[$i]}"
            fi
        done

        printf '\e[90m------------------------------------------------------------------------\e[0m\e[K\n'
        printf '  \e[1;36mINFO :\e[0m %s\e[K\n' "$(tui_truncate "${_SINGLE_INFOS[$cursor]:-}" 64)"
        if [ -n "$status_msg" ]; then
            printf '  \e[1;31m%s\e[0m\e[K\n' "$status_msg"
        else
            printf '\e[K\n'
        fi
        printf '  [↑/↓/j/k] Pilih   [1-%d] Pilih #   [Enter/Space] Simpan   [?] Bantuan   [q/ESC] Kembali\e[K\n' "$count"
        printf '\e[1;36m========================================================================\e[0m\e[J'

        status_msg=""
        tui_read_key
        case "$_TUI_KEY" in
            UP|k|K)   cursor=$(( (cursor - 1 + count) % count )) ;;
            DOWN|j|J) cursor=$(( (cursor + 1) % count )) ;;
            HOME)     cursor=0 ;;
            END)      cursor=$((count - 1)) ;;
            \?|h|H)   tui_show_help_modal "$help_topic" ;;
            [1-9])
                if [ "$_TUI_KEY" -le "$count" ]; then
                    cursor=$((_TUI_KEY - 1))
                    if [ -n "${_SINGLE_DISABLED[$cursor]:-}" ]; then
                        status_msg="[DISABLED] ${_SINGLE_DISABLED[$cursor]}"
                    else
                        _TUI_SELECTED_IDX="$cursor"
                        break
                    fi
                fi
                ;;
            ENTER|SPACE)
                if [ -n "${_SINGLE_DISABLED[$cursor]:-}" ]; then
                    status_msg="[DISABLED] ${_SINGLE_DISABLED[$cursor]}"
                else
                    _TUI_SELECTED_IDX="$cursor"
                    break
                fi
                ;;
            q|Q|ESC|EOF)
                _TUI_SELECTED_IDX="$cancel_idx"
                break
                ;;
        esac
    done
    tui_leave_screen
}

run_driver_menu() {
    ensure_repo_context

    NVIDIA_AVAILABLE=1
    NVIDIA_LABEL="NVIDIA"
    AMD_LABEL="AMD"
    INTEL_LABEL="Intel"
    NVIDIA_BLOCKED_REASON=""

    [ -f "$DISTRO_DIR/driver/nvidia.sh" ] && source "$DISTRO_DIR/driver/nvidia.sh" --info
    [ -f "$DISTRO_DIR/driver/amd.sh" ]    && source "$DISTRO_DIR/driver/amd.sh" --info
    [ -f "$DISTRO_DIR/driver/intel.sh" ]  && source "$DISTRO_DIR/driver/intel.sh" --info

    local default_gpu="4"
    if has_nvidia_gpu && [ "${NVIDIA_AVAILABLE:-1}" -eq 1 ]; then
        default_gpu="1"
    elif has_amd_gpu; then
        default_gpu="2"
    elif has_intel_gpu; then
        default_gpu="3"
    fi

    local nv_suffix="" amd_suffix="" intel_suffix=""
    case "$default_gpu" in
        1) nv_suffix=" (Recommended — Detected)" ;;
        2) amd_suffix=" (Recommended — Detected)" ;;
        3) intel_suffix=" (Recommended — Detected)" ;;
    esac

    local gpu_summary
    gpu_summary="$(detect_gpu_summary)"

    if tui_is_interactive; then
        tui_enter_screen
        local init_cursor=$((default_gpu - 1))
        if [[ "${GPU_CHOICE:-}" =~ ^[1-4]$ ]]; then
            if [ "$GPU_CHOICE" != "1" ] || [ "${NVIDIA_AVAILABLE:-1}" -eq 1 ]; then
                init_cursor=$((GPU_CHOICE - 1))
            fi
        fi

        local -a _SINGLE_OPTS=(
            "${NVIDIA_LABEL}${nv_suffix}"
            "${AMD_LABEL}${amd_suffix}"
            "${INTEL_LABEL}${intel_suffix}"
            "Skip (Keep Current / No GPU Driver)"
        )
        local -a _SINGLE_SUBTITLES=("  Detected GPU : \e[36m$(tui_truncate "$gpu_summary" 58)\e[0m")
        if has_nvidia_gpu && [ "${NVIDIA_AVAILABLE:-1}" -eq 0 ]; then
            _SINGLE_SUBTITLES+=("  \e[1;33mNotice       : GPU NVIDIA terdeteksi, aktifkan repo di menu Repository terlebih dulu.\e[0m")
        fi
        local -a _SINGLE_INFOS=(
            "$(_driver_item_help 0)"
            "$(_driver_item_help 1)"
            "$(_driver_item_help 2)"
            "$(_driver_item_help 3)"
        )
        local -a _SINGLE_DISABLED=("" "" "" "")
        if [ "${NVIDIA_AVAILABLE:-1}" -eq 0 ]; then
            _SINGLE_DISABLED[0]="${NVIDIA_BLOCKED_REASON:-Required repository for NVIDIA is not enabled.}"
        fi

        local _TUI_SELECTED_IDX="$init_cursor"
        _tui_select_single "GPU DRIVER SELECTION MENU (${DISTRO^^} | ${PKG})" "driver" "$init_cursor" "$init_cursor"
        GPU_CHOICE="$((_TUI_SELECTED_IDX + 1))"

        case "$GPU_CHOICE" in
            1) GPU_VENDOR="nvidia" ;;
            2) GPU_VENDOR="amd" ;;
            3) GPU_VENDOR="intel" ;;
            *) GPU_VENDOR="none" ;;
        esac

        if [ "$GPU_CHOICE" = "1" ] && [ "${NVIDIA_AVAILABLE:-1}" -eq 1 ] && is_rtx_5060_present; then
            local tune_idx=1
            [[ "${NVD_TUNE:-N}" =~ ^[Yy]$ ]] && tune_idx=0
            while true; do
                printf '\e[H'
                printf '\e[1;36m========================================================================\e[0m\e[K\n'
                printf '\e[1;37m  NVIDIA RTX 5060 TUNING OPTION\e[0m\e[K\n'
                printf '\e[1;36m========================================================================\e[0m\e[K\n'
                printf '  RTX 5060 terdeteksi! Terapkan batas daya & clock (5060tune)?\e[K\n'
                printf '  \e[90m(Opsional: membantu menjaga suhu & konsumsi daya tetap efisien)\e[0m\e[K\n'
                printf '\e[90m------------------------------------------------------------------------\e[0m\e[K\n'
                if [ "$tune_idx" -eq 0 ]; then
                    printf '\e[7;1m> [Yes] Aktifkan batas daya & clock 5060tune\e[0m\e[K\n'
                    printf '  [No]  Gunakan setelan standar NVIDIA (Recommended)\e[K\n'
                else
                    printf '  [Yes] Aktifkan batas daya & clock 5060tune\e[K\n'
                    printf '\e[7;1m> [No]  Gunakan setelan standar NVIDIA (Recommended)\e[0m\e[K\n'
                fi
                printf '\e[90m------------------------------------------------------------------------\e[0m\e[K\n'
                printf '  [↑/↓/←/→] Ganti   [y/n] Pilih Cepat   [Enter] Konfirmasi\e[K\n'
                printf '\e[1;36m========================================================================\e[0m\e[J'

                tui_read_key
                case "$_TUI_KEY" in
                    UP|DOWN|LEFT|RIGHT|SPACE|j|k) tune_idx=$((1 - tune_idx)) ;;
                    y|Y) NVD_TUNE="Y"; break ;;
                    n|N|ESC|q|Q|EOF) NVD_TUNE="N"; break ;;
                    ENTER)
                        [ "$tune_idx" -eq 0 ] && NVD_TUNE="Y" || NVD_TUNE="N"
                        break
                        ;;
                esac
            done
        else
            NVD_TUNE="N"
        fi
        tui_leave_screen
    else
        echo ""
        echo "========================================================================"
        echo "  GPU DRIVER SELECTION MENU (${DISTRO^^} | ${PKG})"
        echo "========================================================================"
        echo "  Detected GPU : ${gpu_summary}"
        if has_nvidia_gpu && [ "${NVIDIA_AVAILABLE:-1}" -eq 0 ]; then
            echo "  Notice       : NVIDIA GPU detected, but required repo is not enabled."
        fi
        echo "------------------------------------------------------------------------"
        echo "  1) ${NVIDIA_LABEL}${nv_suffix}"
        echo "  2) ${AMD_LABEL}${amd_suffix}"
        echo "  3) ${INTEL_LABEL}${intel_suffix}"
        echo "  4) Skip"
        echo "------------------------------------------------------------------------"

        while true; do
            if ! read -rp "Choice [1-4, default ${default_gpu}]: " GPU_CHOICE; then
                GPU_CHOICE="$default_gpu"
                break
            fi
            GPU_CHOICE="${GPU_CHOICE:-$default_gpu}"
            case "$GPU_CHOICE" in
                1)
                    if [ "${NVIDIA_AVAILABLE:-1}" -eq 0 ]; then
                        echo "  -> [DISABLED] ${NVIDIA_BLOCKED_REASON:-Required repository for NVIDIA is not enabled in Repository Menu.}"
                        echo "     Please choose 2 (AMD), 3 (Intel), or 4 (Skip)."
                        continue
                    fi
                    break
                    ;;
                2|3|4)
                    break
                    ;;
                *)
                    echo "  -> Invalid input. Please enter 1, 2, 3, or 4."
                    ;;
            esac
        done

        case "$GPU_CHOICE" in
            1) GPU_VENDOR="nvidia" ;;
            2) GPU_VENDOR="amd" ;;
            3) GPU_VENDOR="intel" ;;
            *) GPU_VENDOR="none" ;;
        esac

        NVD_TUNE="N"
        if [ "$GPU_CHOICE" = "1" ] && [ "${NVIDIA_AVAILABLE:-1}" -eq 1 ] && is_rtx_5060_present; then
            if ! read -rp "  -> RTX 5060 detected! Apply power & clock limit (5060tune)? [y/N]: " NVD_TUNE; then
                NVD_TUNE="N"
            fi
            NVD_TUNE="${NVD_TUNE:-N}"
        fi
    fi

    _GPU_USER_SET=1
    export GPU_CHOICE GPU_VENDOR NVD_TUNE
}

run_zram_menu() {
    _detect_recommended_zram
    local default_zram="$_REC_ZRAM_CHOICE"
    local ram_label="$_REC_ZRAM_RAM_LABEL"

    local r1="" r2="" r3="" r4=""
    case "$default_zram" in
        1) r1=" (Recommended)" ;;
        2) r2=" (Recommended)" ;;
        3) r3=" (Recommended)" ;;
        4) r4=" (Recommended)" ;;
    esac

    if tui_is_interactive; then
        local zram_msg="Swap terkompresi (zstd) di RAM: cepat, hemat SSD, & direkomendasikan sesuai kapasitas RAM."
        local -a _SINGLE_OPTS=(
            "32 GB (32768 MB)${r1}"
            "16 GB (16384 MB)${r2}"
            "8 GB  (8192 MB)${r3}"
            "4 GB  (4096 MB)${r4}"
            "Skip (No zRAM swap)"
        )
        local -a _SINGLE_SUBTITLES=("  Detected System RAM : \e[36m${ram_label}\e[0m")
        local -a _SINGLE_INFOS=(
            "$zram_msg" "$zram_msg" "$zram_msg" "$zram_msg"
            "Lewati pembuatan swap zRAM (pilih jika Anda sudah mengatur swap sendiri)."
        )
        local -a _SINGLE_DISABLED=("" "" "" "" "")

        local init_cursor=$((default_zram - 1))
        if [[ "${ZRAM_CHOICE:-}" =~ ^[1-5]$ ]]; then
            init_cursor=$((ZRAM_CHOICE - 1))
        fi

        local _TUI_SELECTED_IDX="$init_cursor"
        _tui_select_single "ZRAM SWAP CONFIGURATION MENU (zstd compression)" "zram" "$init_cursor" "$init_cursor"
        ZRAM_CHOICE="$((_TUI_SELECTED_IDX + 1))"
    else
        echo ""
        echo "========================================================================"
        echo "  ZRAM SWAP CONFIGURATION MENU (zstd compression)"
        echo "========================================================================"
        echo "  Detected System RAM : ${ram_label}"
        echo "------------------------------------------------------------------------"
        echo "  1) 32 GB (32768 MB)${r1}"
        echo "  2) 16 GB (16384 MB)${r2}"
        echo "  3) 8 GB  (8192 MB)${r3}"
        echo "  4) 4 GB  (4096 MB)${r4}"
        echo "  5) Skip"
        echo "------------------------------------------------------------------------"

        while true; do
            if ! read -rp "Choice [1-5, default ${default_zram}]: " ZRAM_CHOICE; then
                ZRAM_CHOICE="$default_zram"
            fi
            ZRAM_CHOICE="${ZRAM_CHOICE:-$default_zram}"
            case "$ZRAM_CHOICE" in
                1|2|3|4|5) break ;;
                *) echo "  -> Invalid input. Please enter 1, 2, 3, 4, or 5." ;;
            esac
        done
    fi

    case "$ZRAM_CHOICE" in
        1) ZRAM_SIZE=32768 ;;
        2) ZRAM_SIZE=16384 ;;
        3) ZRAM_SIZE=8192 ;;
        4) ZRAM_SIZE=4096 ;;
        5|*) ZRAM_CHOICE="5"; ZRAM_SIZE="" ;;
    esac

    export ZRAM_CHOICE ZRAM_SIZE
}

run_de_menu() {
    detect_linux_env
    local -a de_ids=() de_labels=() de_files=()
    local f de_id

    if [ -f "$DISTRO_DIR/de/gnome.sh" ]; then
        de_files+=("$DISTRO_DIR/de/gnome.sh")
    fi
    for f in "$DISTRO_DIR"/de/*.sh; do
        [ -f "$f" ] || continue
        [ "$(basename "$f")" = "gnome.sh" ] && continue
        de_files+=("$f")
    done

    for f in "${de_files[@]}"; do
        de_id="$(basename "$f" .sh)"
        DE_LABEL="${de_id^^}"
        source "$f" --info
        de_ids+=("$de_id")
        de_labels+=("$DE_LABEL")
    done

    local count="${#de_ids[@]}"
    local skip_idx=$((count + 1))
    local choice="1"

    if tui_is_interactive; then
        local init_cursor=0 i
        if [ "${DE_CHOICE:-}" = "none" ]; then
            init_cursor=$((skip_idx - 1))
        elif [ -n "${DE_CHOICE:-}" ]; then
            for ((i = 0; i < count; i++)); do
                [ "${de_ids[$i]}" = "$DE_CHOICE" ] && { init_cursor="$i"; break; }
            done
        fi

        local -a _SINGLE_OPTS=() _SINGLE_SUBTITLES=() _SINGLE_INFOS=() _SINGLE_DISABLED=()
        for ((i = 0; i < count; i++)); do
            _SINGLE_OPTS+=("${de_labels[$i]}")
            _SINGLE_INFOS+=("Instal antarmuka desktop grafis (${de_ids[$i]}) minimal beserta login manager & tema.")
            _SINGLE_DISABLED+=("")
        done
        _SINGLE_OPTS+=("Skip (No Desktop Environment / Keep Current)")
        _SINGLE_INFOS+=("Lewati instalasi tampilan grafis (cocok untuk server/CLI atau sudah punya DE sendiri).")
        _SINGLE_DISABLED+=("")

        local _TUI_SELECTED_IDX="$init_cursor"
        _tui_select_single "DESKTOP ENVIRONMENT / GUI MENU (${DISTRO^^} | ${PKG})" "de" "$init_cursor" "$init_cursor"
        choice="$((_TUI_SELECTED_IDX + 1))"
    else
        echo ""
        echo "========================================================================"
        echo "  DESKTOP ENVIRONMENT / GUI MENU (${DISTRO^^} | ${PKG})"
        echo "========================================================================"
        local i
        for ((i = 0; i < count; i++)); do
            echo "  $((i + 1))) ${de_labels[$i]}"
        done
        echo "  ${skip_idx}) Skip (No Desktop Environment / Keep Current)"
        echo "------------------------------------------------------------------------"

        while true; do
            if ! read -rp "Choice [1-${skip_idx}, default 1]: " choice; then
                choice="1"
                break
            fi
            choice="${choice:-1}"
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$skip_idx" ]; then
                break
            fi
            echo "  -> Invalid input. Please enter a number between 1 and ${skip_idx}."
        done
    fi

    if [ "$choice" -eq "$skip_idx" ] || [ "$count" -eq 0 ]; then
        DE_CHOICE="none"
        INSTALL_GNOME="N"
    else
        DE_CHOICE="${de_ids[$((choice - 1))]}"
        if [ "$DE_CHOICE" = "gnome" ]; then
            INSTALL_GNOME="Y"
        else
            INSTALL_GNOME="N"
        fi
    fi

    export DE_CHOICE INSTALL_GNOME
}
