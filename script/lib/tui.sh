#!/usr/bin/env bash

if [ -n "${_LINUXSETUP_TUI_LOADED:-}" ]; then
    return 0 2>/dev/null || true
fi
_LINUXSETUP_TUI_LOADED=1

_TUI_DEPTH=0
_TUI_ACTIVE=0
_TUI_SAVED_TRAP_EXIT=""
_TUI_SAVED_TRAP_INT=""
_TUI_SAVED_TRAP_TERM=""
_TUI_INPUT=""
_TUI_KEY=""
_TUI_STATUS_MSG=""

tui_is_interactive() {
    if [ "${TUI_FORCE_RAW:-0}" = "1" ]; then
        return 0
    fi
    [ -t 0 ] && [ -t 1 ]
}

tui_term_rows() {
    local r="${LINES:-}"
    if [ -z "$r" ] && [ -t 1 ] && command -v stty >/dev/null 2>&1; then
        r="$(stty size 2>/dev/null | awk '{print $1}' || true)"
    fi
    [[ "$r" =~ ^[0-9]+$ ]] && [ "$r" -gt 8 ] || r=24
    printf '%s' "$r"
}

tui_term_cols() {
    local c="${COLUMNS:-}"
    if [ -z "$c" ] && [ -t 1 ] && command -v stty >/dev/null 2>&1; then
        c="$(stty size 2>/dev/null | awk '{print $2}' || true)"
    fi
    [[ "$c" =~ ^[0-9]+$ ]] && [ "$c" -ge 40 ] || c=80
    printf '%s' "$c"
}

tui_truncate() {
    local s="${1:-}" max="${2:-60}"
    if [ "${#s}" -gt "$max" ] && [ "$max" -gt 3 ]; then
        printf '%s...' "${s:0:$((max - 3))}"
    else
        printf '%s' "${s:0:$max}"
    fi
}

_tui_cleanup_screen() {
    if [ "${_TUI_ACTIVE:-0}" -eq 1 ]; then
        printf '\e[?25h\e[?1049l'
        _TUI_ACTIVE=0
        _TUI_DEPTH=0
    fi
}

_tui_restore_traps() {
    trap - EXIT INT TERM
    [ -n "${_TUI_SAVED_TRAP_EXIT:-}" ] && eval "$_TUI_SAVED_TRAP_EXIT" || true
    [ -n "${_TUI_SAVED_TRAP_INT:-}" ]  && eval "$_TUI_SAVED_TRAP_INT"  || true
    [ -n "${_TUI_SAVED_TRAP_TERM:-}" ] && eval "$_TUI_SAVED_TRAP_TERM" || true
}

_tui_on_exit() {
    local rc=$?
    _tui_cleanup_screen
    if [ -n "${_TUI_SAVED_TRAP_EXIT:-}" ]; then
        eval "$_TUI_SAVED_TRAP_EXIT"
    fi
    return "$rc"
}

_tui_on_signal() {
    _tui_cleanup_screen
    _tui_restore_traps
    printf '\n==> Setup cancelled by user.\n' >&2
    exit 130
}

tui_enter_screen() {
    tui_is_interactive || return 0
    if [ "${_TUI_DEPTH:-0}" -eq 0 ]; then
        _TUI_SAVED_TRAP_EXIT="$(trap -p EXIT 2>/dev/null || true)"
        _TUI_SAVED_TRAP_INT="$(trap -p INT 2>/dev/null || true)"
        _TUI_SAVED_TRAP_TERM="$(trap -p TERM 2>/dev/null || true)"
        trap '_tui_on_exit' EXIT
        trap '_tui_on_signal' INT TERM
        _TUI_ACTIVE=1
        printf '\e[?1049h\e[?25l\e[2J\e[H'
    fi
    _TUI_DEPTH=$((_TUI_DEPTH + 1))
}

tui_leave_screen() {
    tui_is_interactive || return 0
    if [ "${1:-}" = "--force" ]; then
        _TUI_DEPTH=1
    fi
    if [ "${_TUI_DEPTH:-0}" -gt 0 ]; then
        _TUI_DEPTH=$((_TUI_DEPTH - 1))
    fi
    if [ "${_TUI_DEPTH:-0}" -eq 0 ] && [ "${_TUI_ACTIVE:-0}" -eq 1 ]; then
        _tui_cleanup_screen
        _tui_restore_traps
    fi
}

tui_read_key() {
    local key="" k1="" k2="" k3=""
    _TUI_KEY=""
    if ! IFS= read -rsn1 key; then
        _TUI_KEY="EOF"
        return 0
    fi
    if [ "$key" = $'\e' ]; then
        if IFS= read -rsn1 -t 0.05 k1 2>/dev/null; then
            if [ "$k1" = "[" ] || [ "$k1" = "O" ]; then
                if IFS= read -rsn1 -t 0.05 k2 2>/dev/null; then
                    case "$k2" in
                        A) _TUI_KEY="UP"; return 0 ;;
                        B) _TUI_KEY="DOWN"; return 0 ;;
                        C) _TUI_KEY="RIGHT"; return 0 ;;
                        D) _TUI_KEY="LEFT"; return 0 ;;
                        H) _TUI_KEY="HOME"; return 0 ;;
                        F) _TUI_KEY="END"; return 0 ;;
                        5)
                            IFS= read -rsn1 -t 0.05 k3 2>/dev/null || true
                            _TUI_KEY="PGUP"; return 0
                            ;;
                        6)
                            IFS= read -rsn1 -t 0.05 k3 2>/dev/null || true
                            _TUI_KEY="PGDN"; return 0
                            ;;
                        1|7)
                            IFS= read -rsn1 -t 0.05 k3 2>/dev/null || true
                            _TUI_KEY="HOME"; return 0
                            ;;
                        4|8)
                            IFS= read -rsn1 -t 0.05 k3 2>/dev/null || true
                            _TUI_KEY="END"; return 0
                            ;;
                    esac
                fi
            fi
            _TUI_KEY="ESC"
        else
            _TUI_KEY="ESC"
        fi
        return 0
    fi

    case "$key" in
        "")            _TUI_KEY="ENTER" ;;
        " ")           _TUI_KEY="SPACE" ;;
        $'\t')         _TUI_KEY="TAB" ;;
        $'\x7f'|$'\b') _TUI_KEY="BACKSPACE" ;;
        *)             _TUI_KEY="$key" ;;
    esac
}

tui_prompt_line() {
    local prompt="${1:-Input: }"
    _TUI_INPUT=""
    printf '\e[K\n\e[1;36m  %s\e[0m\e[?25h' "$prompt"
    if [ -t 0 ]; then
        read -rep "" _TUI_INPUT || _TUI_INPUT=""
    else
        read -r _TUI_INPUT || _TUI_INPUT=""
    fi
    printf '\e[?25l'
    _TUI_INPUT="$(trim_whitespace "$_TUI_INPUT")"
}

tui_show_help_modal() {
    local ctx="${1:-dashboard}"
    tui_is_interactive || return 0
    tui_enter_screen

    printf '\e[H'
    printf '\e[1;36m========================================================================\e[0m\e[K\n'
    printf '\e[1;37m  PANDUAN PENGGUNAAN INSTALLER (%s)\e[0m\e[K\n' "${ctx^^}"
    printf '\e[1;36m========================================================================\e[0m\e[K\n'
    printf '  \e[1;33mNavigasi Dasar:\e[0m\e[K\n'
    printf '    - Panah Atas / Bawah (atau k / j) : Geser sorotan pilihan\e[K\n'
    printf '    - Spasi (Space)                   : Centang [x] / Lepas [ ] / Toggle\e[K\n'
    printf '    - Enter                           : Buka sub-menu atau simpan pilihan\e[K\n'
    printf '    - Angka [1-9]                     : Lompat & pilih baris secara cepat\e[K\n'
    printf '    - [q] atau [ESC]                  : Kembali / batalkan\e[K\n'
    printf '\e[90m------------------------------------------------------------------------\e[0m\e[K\n'

    case "$ctx" in
        repo)
            printf '  \e[1;33mPanduan Menu Repository:\e[0m\e[K\n'
            printf '    - Awalnya installer mendeteksi repo yang SUDAH AKTIF di distro Anda.\e[K\n'
            printf '    - Bingung memilih? Tekan [r] untuk mengaktifkan semua repo (*Rec)\e[K\n'
            printf '      yang dibutuhkan driver GPU, codec multimedia, & aplikasi Flathub.\e[K\n'
            printf '    - Jika repo [x] Anda matikan menjadi [ ], sistem menonaktifkannya.\e[K\n'
            printf '    - Tekan [d] kapan saja untuk mereset ke kondisi awal sistem Anda.\e[K\n'
            ;;
        driver)
            printf '  \e[1;33mPanduan Menu Driver GPU:\e[0m\e[K\n'
            printf '    - Pilihan bertanda (Recommended — Detected) sudah dicocokkan\e[K\n'
            printf '      otomatis dengan kartu grafis yang terpasang di perangkat Anda.\e[K\n'
            printf '    - Jika NVIDIA bertanda [DISABLED], aktifkan repo non-free/RPM Fusion\e[K\n'
            printf '      terlebih dahulu di Menu #1 (Repositories) lalu tekan [r].\e[K\n'
            ;;
        de)
            printf '  \e[1;33mPanduan Menu Desktop / GUI:\e[0m\e[K\n'
            printf '    - Pilih GNOME jika ini instalasi minimal/baru untuk penggunaan desktop.\e[K\n'
            printf '    - Pilih Skip jika Anda memakai server tanpa layar atau sudah punya GUI.\e[K\n'
            ;;
        apps)
            printf '  \e[1;33mPanduan Menu Aplikasi:\e[0m\e[K\n'
            printf '    - Gunakan [Space] untuk mencentang/melepas aplikasi preset.\e[K\n'
            printf '    - Tekan [/] untuk mencari paket tambahan di repo distro/AUR,\e[K\n'
            printf '      atau [f] untuk mencari aplikasi tambahan di Flathub.\e[K\n'
            printf '    - Tekan [+] / [F] untuk mengetik nama paket/Flatpak ID langsung.\e[K\n'
            ;;
        zram)
            printf '  \e[1;33mPanduan Menu zRAM Swap:\e[0m\e[K\n'
            printf '    - zRAM membuat ruang swap terkompresi (zstd) di dalam RAM.\e[K\n'
            printf '    - Ukuran (Recommended) sudah disesuaikan otomatis dengan RAM fisik.\e[K\n'
            ;;
        *)
            printf '  \e[1;33mAlur Cepat untuk Pemula:\e[0m\e[K\n'
            printf '    1. Tekan [r] di Dashboard utama -> otomatis aktifkan semua setelan\e[K\n'
            printf '       rekomendasi (Repo populer, Driver GPU, GNOME, Apps, CLI, zRAM).\e[K\n'
            printf '    2. Periksa ringkasan pada baris 1 s/d 7 (ubah seperlunya).\e[K\n'
            printf '    3. Tekan [i] atau pilih #8 (Start Installation) untuk mulai!\e[K\n'
            printf '    4. Di akhir proses, verify.sh memeriksa semua paket terpasang.\e[K\n'
            ;;
    esac

    printf '\e[90m------------------------------------------------------------------------\e[0m\e[K\n'
    printf '  \e[1;32mTekan tombol apa saja untuk menutup panduan ini...\e[0m\e[K\n'
    printf '\e[1;36m========================================================================\e[0m\e[J'

    tui_read_key
    tui_leave_screen
}

_TUI_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_TUI_LIB_DIR/env.sh"
source "$_TUI_LIB_DIR/hardware.sh"
source "$_TUI_LIB_DIR/repo-detect.sh"
source "$_TUI_LIB_DIR/menu-repo.sh"
source "$_TUI_LIB_DIR/menu-system.sh"
source "$_TUI_LIB_DIR/menu-apps.sh"
