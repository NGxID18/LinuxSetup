#!/usr/bin/env bash

resolve_gpu_vendor() {
    if [ -n "${GPU_VENDOR:-}" ]; then
        printf '%s' "$GPU_VENDOR"
        return 0
    fi
    case "${GPU_CHOICE:-4}" in
        1) printf 'nvidia' ;;
        2) printf 'amd' ;;
        3) printf 'intel' ;;
        *) printf 'none' ;;
    esac
}

resolve_de_choice() {
    if [ -n "${DE_CHOICE:-}" ]; then
        printf '%s' "$DE_CHOICE"
        return 0
    fi
    if [[ "${INSTALL_GNOME:-Y}" =~ ^[Yy]$ ]]; then
        printf 'gnome'
    else
        printf 'none'
    fi
}

_get_gpu_lines() {
    if command -v lspci >/dev/null 2>&1; then
        lspci -nn 2>/dev/null | grep -iE 'vga compatible controller|3d controller|display controller' || true
    fi
}

_get_gpu_names() {
    _get_gpu_lines | sed -E 's/^[^:]+:[0-9a-fA-F.]+ [^:]+: //'
}

has_nvidia_gpu() {
    _get_gpu_names | grep -qiE '\bnvidia\b|\[10de:' && return 0
    grep -qi '0x10de' /sys/class/drm/card*/device/vendor 2>/dev/null && return 0
    return 1
}

has_amd_gpu() {
    _get_gpu_names | grep -qiE '\b(amd|advanced micro devices|ati|radeon)\b|\[1002:' && return 0
    grep -qi '0x1002' /sys/class/drm/card*/device/vendor 2>/dev/null && return 0
    return 1
}

has_intel_gpu() {
    _get_gpu_names | grep -qiE '\bintel\b|\[8086:' && return 0
    grep -qi '0x8086' /sys/class/drm/card*/device/vendor 2>/dev/null && return 0
    return 1
}

is_rtx_5060_present() {
    _get_gpu_lines | grep -qiE '5060|10de:2d05' && return 0
    if command -v nvidia-smi >/dev/null 2>&1; then
        nvidia-smi -L 2>/dev/null | grep -qi '5060' && return 0
    fi
    return 1
}

detect_gpu_summary() {
    local summary="" line=""
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        line="$(printf '%s' "$line" | sed -E 's/^[^:]+:[0-9a-fA-F.]+ [^:]+: //; s/ \(rev [^)]+\)$//')"
        summary="${summary:+${summary} + }${line}"
    done < <(_get_gpu_lines)

    if [ -n "$summary" ]; then
        printf '%s' "$summary"
        return 0
    fi

    local -a vendors=()
    has_nvidia_gpu && vendors+=("NVIDIA GPU")
    has_amd_gpu    && vendors+=("AMD GPU")
    has_intel_gpu  && vendors+=("Intel GPU")
    if [ "${#vendors[@]}" -gt 0 ]; then
        local IFS=" + "
        printf '%s' "${vendors[*]}"
    else
        printf '%s' "None / Virtual GPU"
    fi
}

_detect_recommended_zram() {
    local mem_kb=0 ram_mb=0 ram_gb=0
    _REC_ZRAM_CHOICE="5"
    _REC_ZRAM_SIZE=""
    _REC_ZRAM_RAM_LABEL="Unknown"

    if [ -r /proc/meminfo ]; then
        mem_kb="$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo 2>/dev/null || echo 0)"
    fi
    if [[ "$mem_kb" =~ ^[0-9]+$ ]] && [ "$mem_kb" -gt 0 ]; then
        ram_mb=$(( mem_kb / 1024 ))
        ram_gb=$(( (mem_kb + 524288) / 1048576 ))
        [ "$ram_gb" -lt 1 ] && ram_gb=1
        _REC_ZRAM_RAM_LABEL="~${ram_gb} GB (${ram_mb} MB)"
        if [ "$ram_gb" -ge 28 ]; then
            _REC_ZRAM_CHOICE="1"; _REC_ZRAM_SIZE=32768
        elif [ "$ram_gb" -ge 14 ]; then
            _REC_ZRAM_CHOICE="2"; _REC_ZRAM_SIZE=16384
        elif [ "$ram_gb" -ge 6 ]; then
            _REC_ZRAM_CHOICE="3"; _REC_ZRAM_SIZE=8192
        else
            _REC_ZRAM_CHOICE="4"; _REC_ZRAM_SIZE=4096
        fi
    fi
}
