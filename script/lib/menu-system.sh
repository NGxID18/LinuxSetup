#!/usr/bin/env bash

_driver_item_help() {
    case "$1" in
        0) printf '%s' "Driver khusus GPU NVIDIA (+ CUDA/Open Kernel). Jika masih [DISABLED], aktifkan repo yg diminta." ;;
        1) printf '%s' "Driver open-source Mesa Vulkan & akselerasi video VA-API untuk GPU AMD Radeon." ;;
        2) printf '%s' "Driver open-source Mesa Vulkan & Media VA-API untuk iGPU Intel / Intel Arc." ;;
        *) printf '%s' "Lewati pemasangan driver GPU (cocok untuk Virtual Machine atau pertahankan driver saat ini)." ;;
    esac
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
        local -a opts=(
            "${NVIDIA_LABEL}${nv_suffix}"
            "${AMD_LABEL}${amd_suffix}"
            "${INTEL_LABEL}${intel_suffix}"
            "Skip (Keep Current / No GPU Driver)"
        )
        local cursor=$((default_gpu - 1))
        if [[ "${GPU_CHOICE:-}" =~ ^[1-4]$ ]]; then
            if [ "$GPU_CHOICE" != "1" ] || [ "${NVIDIA_AVAILABLE:-1}" -eq 1 ]; then
                cursor=$((GPU_CHOICE - 1))
            fi
        fi

        local status_msg="" i
        while true; do
            printf '\e[H'
            printf '\e[1;36m========================================================================\e[0m\e[K\n'
            printf '\e[1;37m  GPU DRIVER SELECTION MENU (%s | %s)\e[0m\e[K\n' "${DISTRO^^}" "${PKG}"
            printf '\e[1;36m========================================================================\e[0m\e[K\n'
            printf '  Detected GPU : \e[36m%s\e[0m\e[K\n' "$(tui_truncate "$gpu_summary" 58)"
            if has_nvidia_gpu && [ "${NVIDIA_AVAILABLE:-1}" -eq 0 ]; then
                printf '  \e[1;33mNotice       : GPU NVIDIA terdeteksi, aktifkan repo di menu Repository terlebih dulu.\e[0m\e[K\n'
            fi
            printf '\e[90m------------------------------------------------------------------------\e[0m\e[K\n'

            for ((i = 0; i < 4; i++)); do
                if [ "$i" -eq "$cursor" ]; then
                    printf '\e[7;1m> %d) %s\e[0m\e[K\n' "$((i + 1))" "${opts[$i]}"
                else
                    if [ "$i" -eq 0 ] && [ "${NVIDIA_AVAILABLE:-1}" -eq 0 ]; then
                        printf '  \e[90m%d) %s\e[0m\e[K\n' "$((i + 1))" "${opts[$i]}"
                    else
                        printf '  %d) %s\e[K\n' "$((i + 1))" "${opts[$i]}"
                    fi
                fi
            done

            printf '\e[90m------------------------------------------------------------------------\e[0m\e[K\n'
            printf '  \e[1;36mINFO :\e[0m %s\e[K\n' "$(tui_truncate "$(_driver_item_help "$cursor")" 64)"
            if [ -n "$status_msg" ]; then
                printf '  \e[1;31m%s\e[0m\e[K\n' "$status_msg"
            else
                printf '\e[K\n'
            fi
            printf '  [↑/↓/j/k] Pilih   [1-4] Pilih #   [Enter/Space] Simpan   [?] Bantuan   [q/ESC] Kembali\e[K\n'
            printf '\e[1;36m========================================================================\e[0m\e[J'

            status_msg=""
            tui_read_key
            case "$_TUI_KEY" in
                UP|k|K)   cursor=$(( (cursor - 1 + 4) % 4 )) ;;
                DOWN|j|J) cursor=$(( (cursor + 1) % 4 )) ;;
                HOME)     cursor=0 ;;
                END)      cursor=3 ;;
                \?|h|H)   tui_show_help_modal "driver" ;;
                [1-4])
                    cursor=$((_TUI_KEY - 1))
                    if [ "$cursor" -eq 0 ] && [ "${NVIDIA_AVAILABLE:-1}" -eq 0 ]; then
                        status_msg="[DISABLED] ${NVIDIA_BLOCKED_REASON:-Required repository for NVIDIA is not enabled.}"
                    else
                        GPU_CHOICE="$((cursor + 1))"
                        break
                    fi
                    ;;
                ENTER|SPACE)
                    if [ "$cursor" -eq 0 ] && [ "${NVIDIA_AVAILABLE:-1}" -eq 0 ]; then
                        status_msg="[DISABLED] ${NVIDIA_BLOCKED_REASON:-Required repository for NVIDIA is not enabled.}"
                    else
                        GPU_CHOICE="$((cursor + 1))"
                        break
                    fi
                    ;;
                q|Q|ESC|EOF)
                    GPU_CHOICE="${GPU_CHOICE:-$default_gpu}"
                    if [ "$GPU_CHOICE" = "1" ] && [ "${NVIDIA_AVAILABLE:-1}" -eq 0 ]; then
                        GPU_CHOICE="4"
                    fi
                    break
                    ;;
            esac
        done

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
        tui_enter_screen
        local -a opts=(
            "32 GB (32768 MB)${r1}"
            "16 GB (16384 MB)${r2}"
            "8 GB  (8192 MB)${r3}"
            "4 GB  (4096 MB)${r4}"
            "Skip (No zRAM swap)"
        )
        local cursor=$((default_zram - 1))
        if [[ "${ZRAM_CHOICE:-}" =~ ^[1-5]$ ]]; then
            cursor=$((ZRAM_CHOICE - 1))
        fi

        local i info_zram
        while true; do
            if [ "$cursor" -eq 4 ]; then
                info_zram="Lewati pembuatan swap zRAM (pilih jika Anda sudah mengatur swap sendiri)."
            else
                info_zram="Swap terkompresi (zstd) di RAM: cepat, hemat SSD, & direkomendasikan sesuai kapasitas RAM."
            fi

            printf '\e[H'
            printf '\e[1;36m========================================================================\e[0m\e[K\n'
            printf '\e[1;37m  ZRAM SWAP CONFIGURATION MENU (zstd compression)\e[0m\e[K\n'
            printf '\e[1;36m========================================================================\e[0m\e[K\n'
            printf '  Detected System RAM : \e[36m%s\e[0m\e[K\n' "$ram_label"
            printf '\e[90m------------------------------------------------------------------------\e[0m\e[K\n'
            for ((i = 0; i < 5; i++)); do
                if [ "$i" -eq "$cursor" ]; then
                    printf '\e[7;1m> %d) %s\e[0m\e[K\n' "$((i + 1))" "${opts[$i]}"
                else
                    printf '  %d) %s\e[K\n' "$((i + 1))" "${opts[$i]}"
                fi
            done
            printf '\e[90m------------------------------------------------------------------------\e[0m\e[K\n'
            printf '  \e[1;36mINFO :\e[0m %s\e[K\n' "$(tui_truncate "$info_zram" 64)"
            printf '  [↑/↓/j/k] Pilih   [1-5] Pilih #   [Enter/Space] Simpan   [?] Bantuan   [q/ESC] Kembali\e[K\n'
            printf '\e[1;36m========================================================================\e[0m\e[J'

            tui_read_key
            case "$_TUI_KEY" in
                UP|k|K)   cursor=$(( (cursor - 1 + 5) % 5 )) ;;
                DOWN|j|J) cursor=$(( (cursor + 1) % 5 )) ;;
                HOME)     cursor=0 ;;
                END)      cursor=4 ;;
                \?|h|H)   tui_show_help_modal "zram" ;;
                [1-5])
                    cursor=$((_TUI_KEY - 1))
                    ZRAM_CHOICE="$((cursor + 1))"
                    break
                    ;;
                ENTER|SPACE)
                    ZRAM_CHOICE="$((cursor + 1))"
                    break
                    ;;
                q|Q|ESC|EOF)
                    ZRAM_CHOICE="${ZRAM_CHOICE:-$default_zram}"
                    break
                    ;;
            esac
        done
        tui_leave_screen
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
        tui_enter_screen
        local cursor=0 i info_de=""
        if [ "${DE_CHOICE:-}" = "none" ]; then
            cursor=$((skip_idx - 1))
        elif [ -n "${DE_CHOICE:-}" ]; then
            for ((i = 0; i < count; i++)); do
                [ "${de_ids[$i]}" = "$DE_CHOICE" ] && { cursor="$i"; break; }
            done
        fi

        while true; do
            if [ "$cursor" -eq "$((skip_idx - 1))" ]; then
                info_de="Lewati instalasi tampilan grafis (cocok untuk server/CLI atau sudah punya DE sendiri)."
            else
                info_de="Instal antarmuka desktop grafis (${de_ids[$cursor]}) minimal beserta login manager & tema."
            fi

            printf '\e[H'
            printf '\e[1;36m========================================================================\e[0m\e[K\n'
            printf '\e[1;37m  DESKTOP ENVIRONMENT / GUI MENU (%s | %s)\e[0m\e[K\n' "${DISTRO^^}" "${PKG}"
            printf '\e[1;36m========================================================================\e[0m\e[K\n'
            for ((i = 0; i < count; i++)); do
                if [ "$i" -eq "$cursor" ]; then
                    printf '\e[7;1m> %d) %s\e[0m\e[K\n' "$((i + 1))" "${de_labels[$i]}"
                else
                    printf '  %d) %s\e[K\n' "$((i + 1))" "${de_labels[$i]}"
                fi
            done
            if [ "$((skip_idx - 1))" -eq "$cursor" ]; then
                printf '\e[7;1m> %d) Skip (No Desktop Environment / Keep Current)\e[0m\e[K\n' "$skip_idx"
            else
                printf '  %d) Skip (No Desktop Environment / Keep Current)\e[K\n' "$skip_idx"
            fi
            printf '\e[90m------------------------------------------------------------------------\e[0m\e[K\n'
            printf '  \e[1;36mINFO :\e[0m %s\e[K\n' "$(tui_truncate "$info_de" 64)"
            printf '  [↑/↓/j/k] Pilih   [1-%d] Pilih #   [Enter/Space] Simpan   [?] Bantuan   [q/ESC] Kembali\e[K\n' "$skip_idx"
            printf '\e[1;36m========================================================================\e[0m\e[J'

            tui_read_key
            case "$_TUI_KEY" in
                UP|k|K)   cursor=$(( (cursor - 1 + skip_idx) % skip_idx )) ;;
                DOWN|j|J) cursor=$(( (cursor + 1) % skip_idx )) ;;
                HOME)     cursor=0 ;;
                END)      cursor=$((skip_idx - 1)) ;;
                \?|h|H)   tui_show_help_modal "de" ;;
                [1-9])
                    if [ "$_TUI_KEY" -le "$skip_idx" ]; then
                        cursor=$((_TUI_KEY - 1))
                        choice="$_TUI_KEY"
                        break
                    fi
                    ;;
                ENTER|SPACE)
                    choice=$((cursor + 1))
                    break
                    ;;
                q|Q|ESC|EOF)
                    if [ "${DE_CHOICE:-}" = "none" ]; then
                        choice="$skip_idx"
                    else
                        choice="1"
                        for ((i = 0; i < count; i++)); do
                            [ "${de_ids[$i]}" = "${DE_CHOICE:-}" ] && { choice="$((i + 1))"; break; }
                        done
                    fi
                    break
                    ;;
            esac
        done
        tui_leave_screen
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
