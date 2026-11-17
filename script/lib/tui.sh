#!/usr/bin/env bash

if [ -n "${_LINUXSETUP_TUI_LOADED:-}" ]; then
    return 0 2>/dev/null || true
fi
_LINUXSETUP_TUI_LOADED=1

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

app_verifies() {
    if [ "${APPS_MENU_DONE:-0}" = "1" ]; then
        app_enabled "$1"
    else
        return 0
    fi
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

repo_active_flag() {
    if "$@"; then
        printf '1'
    else
        printf '0'
    fi
}

_list_dnf_repos() {
    local mode="${1:-active}"
    local -a base_files=() override_files=()
    local f
    for f in /usr/share/dnf5/repos.d/*.repo /etc/distro.repos.d/*.repo /etc/yum.repos.d/*.repo; do
        [ -f "$f" ] && base_files+=("$f")
    done
    for f in /etc/dnf/repos.override.d/*.repo; do
        [ -f "$f" ] && override_files+=("$f")
    done

    if [ "${#base_files[@]}" -gt 0 ]; then
        awk -v base_count="${#base_files[@]}" -v mode="$mode" '
            FNR == 1 { file_idx++; is_override = (file_idx > base_count); sec = "" }
            { sub(/\r$/, "") }
            /^[[:space:]]*($|[#;])/ { next }
            /^[[:space:]]*\[[^]]+\][[:space:]]*$/ {
                sec = $0
                sub(/^[[:space:]]*\[/, "", sec)
                sub(/\][[:space:]]*$/, "", sec)
                if (!is_override) {
                    if (!(sec in state)) order[++n] = sec
                    state[sec] = 1
                }
                next
            }
            sec != "" {
                line = $0
                sub(/[[:space:]]*$/, "", line)
                if (tolower(line) ~ /^[[:space:]]*enabled[[:space:]]*=/) {
                    val = line
                    sub(/^[^=]*=[[:space:]]*/, "", val)
                    sub(/[[:space:]]*([#;].*)?$/, "", val)
                    val = tolower(val)
                    val_flag = (val == "1" || val == "true" || val == "yes") ? 1 : 0
                    if (!is_override || (sec in state)) {
                        state[sec] = val_flag
                    }
                }
            }
            END {
                for (i = 1; i <= n; i++) {
                    s = order[i]
                    if (mode == "all" || state[s] == 1) print s
                }
            }
        ' "${base_files[@]}" "${override_files[@]}"
        return 0
    fi

    if command -v dnf >/dev/null 2>&1; then
        local dnf_flag="--enabled"
        [ "$mode" = "all" ] && dnf_flag="--all"
        dnf -C repolist "$dnf_flag" -q 2>/dev/null | awk '$1 == "repo" && $2 == "id" {next} NF {print $1}'
    fi
}

is_dnf_repo_active() {
    _list_dnf_repos active | grep -qiE -- "$1"
}

is_dnf_repo_present() {
    _list_dnf_repos all | grep -qiE -- "$1"
}

set_dnf_repo_enabled() {
    local repo_id="$1" val="$2"
    local flag="--set-disabled"
    [ "$val" = "1" ] && flag="--set-enabled"
    sudo dnf config-manager setopt "${repo_id}.enabled=${val}" 2>/dev/null \
        || sudo dnf config-manager "$flag" "$repo_id" 2>/dev/null || true
}

set_matching_dnf_repos_enabled() {
    local pattern="$1" val="$2"
    local id
    while IFS= read -r id; do
        [ -n "$id" ] || continue
        set_dnf_repo_enabled "$id" "$val"
    done < <(_list_dnf_repos all | grep -iE -- "$pattern" || true)
}

_list_zypper_repos() {
    local mode="${1:-active}"
    local -a files=()
    local f
    for f in /etc/zypp/repos.d/*.repo; do
        [ -f "$f" ] && files+=("$f")
    done

    if [ "${#files[@]}" -gt 0 ]; then
        awk -v mode="$mode" '
            function flush() {
                if (sec != "" && (mode == "all" || enabled == 1)) {
                    print sec "|" name "|" baseurl
                }
            }
            FNR == 1 { flush(); sec = ""; name = ""; baseurl = ""; enabled = 1 }
            { sub(/\r$/, "") }
            /^[[:space:]]*($|[#;])/ { next }
            /^[[:space:]]*\[[^]]+\][[:space:]]*$/ {
                flush()
                sec = $0
                sub(/^[[:space:]]*\[/, "", sec)
                sub(/\][[:space:]]*$/, "", sec)
                name = ""; baseurl = ""; enabled = 1
                next
            }
            sec != "" {
                line = $0
                sub(/[[:space:]]*$/, "", line)
                low = tolower(line)
                if (low ~ /^[[:space:]]*enabled[[:space:]]*=/) {
                    val = line
                    sub(/^[^=]*=[[:space:]]*/, "", val)
                    sub(/[[:space:]]*([#;].*)?$/, "", val)
                    val = tolower(val)
                    enabled = (val == "1" || val == "true" || val == "yes") ? 1 : 0
                } else if (low ~ /^[[:space:]]*name[[:space:]]*=/) {
                    val = line; sub(/^[^=]*=[[:space:]]*/, "", val); name = val
                } else if (low ~ /^[[:space:]]*baseurl[[:space:]]*=/) {
                    val = line; sub(/^[^=]*=[[:space:]]*/, "", val); baseurl = val
                }
            }
            END { flush() }
        ' "${files[@]}"
        return 0
    fi

    if command -v zypper >/dev/null 2>&1; then
        zypper lr -u 2>/dev/null | awk -F'|' -v mode="$mode" '
            $1 ~ /^[[:space:]]*[0-9]+[[:space:]]*$/ {
                alias = $2; name = $3; en = tolower($4); uri = $NF
                gsub(/^[ \t]+|[ \t]+$/, "", alias)
                gsub(/^[ \t]+|[ \t]+$/, "", name)
                gsub(/^[ \t]+|[ \t]+$/, "", en)
                gsub(/^[ \t]+|[ \t]+$/, "", uri)
                if (mode == "all" || en == "yes" || en == "1" || en == "true") {
                    print alias "|" name "|" uri
                }
            }
        '
    fi
}

is_zypper_repo_active() {
    local inc="$1" exc="${2:-}"
    local lines
    lines="$(_list_zypper_repos active | grep -iE -- "$inc" || true)"
    if [ -n "$exc" ] && [ -n "$lines" ]; then
        lines="$(printf '%s\n' "$lines" | grep -viE -- "$exc" || true)"
    fi
    [ -n "$lines" ]
}

zypper_set_matching_repos_enabled() {
    local inc="$1" mode="$2" exc="${3:-}"
    local alias
    while IFS= read -r alias; do
        [ -n "$alias" ] || continue
        sudo zypper mr "-${mode}" "$alias" 2>/dev/null || true
    done < <(
        {
            if command -v zypper >/dev/null 2>&1; then
                zypper lr -u 2>/dev/null | awk -F'|' '
                    $1 ~ /^[[:space:]]*[0-9]+[[:space:]]*$/ {
                        alias = $2; name = $3; uri = $NF
                        gsub(/^[ \t]+|[ \t]+$/, "", alias)
                        gsub(/^[ \t]+|[ \t]+$/, "", name)
                        gsub(/^[ \t]+|[ \t]+$/, "", uri)
                        print alias "|" name "|" uri
                    }
                '
            else
                _list_zypper_repos all
            fi
        } | awk -F'|' -v inc="$inc" -v exc="$exc" '
            {
                low = tolower($0)
                if (low ~ tolower(inc) && (exc == "" || low !~ tolower(exc))) {
                    print $1
                }
            }
        '
    )
}

is_pacman_repo_active() {
    [ -f /etc/pacman.conf ] || return 1
    grep -qE "^[[:space:]]*\[(${1})\]([[:space:]]*(#.*)?)?$" /etc/pacman.conf
}

pacman_set_section_enabled() {
    local section_regex="$1" enable="$2"
    [ -f /etc/pacman.conf ] || return 0
    local tmp
    tmp="$(mktemp /tmp/pacman.conf.XXXXXX)"
    awk -v sec_re="$section_regex" -v enable="$enable" '
        BEGIN { in_sec = 0 }
        {
            line = $0
            if (line ~ "^[[:space:]]*#?[[:space:]]*\\[[[:space:]]*(" sec_re ")[[:space:]]*\\]([[:space:]]*(#.*)?)?$") {
                in_sec = 1
                if (enable == 1) {
                    sub(/^[[:space:]]*#[[:space:]]*/, "", line)
                } else if (line !~ /^[[:space:]]*#/) {
                    line = "#" line
                }
                print line
                next
            }
            if (in_sec == 1) {
                if (line ~ /^[[:space:]]*$/ || line ~ /^[[:space:]]*#?[[:space:]]*\[[^]]+\]/) {
                    in_sec = 0
                } else {
                    if (enable == 1) {
                        if (line ~ /^[[:space:]]*#[[:space:]]*(Include|SigLevel|Server|Usage|CacheServer)[[:space:]]*=/) {
                            sub(/^[[:space:]]*#[[:space:]]*/, "", line)
                        }
                    } else if (line !~ /^[[:space:]]*#/) {
                        line = "#" line
                    }
                    print line
                    next
                }
            }
            print line
        }
    ' /etc/pacman.conf > "$tmp"
    sudo tee /etc/pacman.conf > /dev/null < "$tmp"
    rm -f "$tmp"
}

_apt_list_active_entries() {
    local -a list_files=() source_files=()
    local f
    [ -f /etc/apt/sources.list ] && list_files+=(/etc/apt/sources.list)
    for f in /etc/apt/sources.list.d/*.list; do
        [ -f "$f" ] && list_files+=("$f")
    done
    for f in /etc/apt/sources.list.d/*.sources; do
        [ -f "$f" ] && source_files+=("$f")
    done

    if [ "${#list_files[@]}" -gt 0 ]; then
        awk '
            {
                sub(/\r$/, "")
                sub(/#.*$/, "")
                if ($0 ~ /^[[:space:]]*deb[[:space:]]+/) {
                    line = $0
                    sub(/^[[:space:]]*deb[[:space:]]+/, "", line)
                    if (line ~ /^\[/) {
                        sub(/^\[[^]]*\][[:space:]]*/, "", line)
                    }
                    n = split(line, f, /[[:space:]]+/)
                    if (n >= 2) {
                        uri = f[1]; suite = f[2]; comps = ""
                        if (suite !~ /\/$/) {
                            for (i = 3; i <= n; i++) {
                                if (f[i] != "") comps = (comps == "" ? f[i] : comps " " f[i])
                            }
                        }
                        print uri "\t" suite "\t" comps
                    }
                }
            }
        ' "${list_files[@]}"
    fi

    if [ "${#source_files[@]}" -gt 0 ]; then
        awk '
            BEGIN { RS = "" }
            {
                gsub(/\r/, "")
                # Remove full-line comments
                gsub(/(^|\n)[[:space:]]*#[^\n]*/, "")
                # Unfold DEB822 continuation lines
                gsub(/\n[ \t]+/, " ")
                types = ""; uris = ""; suites = ""; comps = ""; enabled = "yes"
                n = split($0, lines, /\n/)
                for (i = 1; i <= n; i++) {
                    l = lines[i]
                    if (l ~ /^[[:space:]]*$/) continue
                    idx = index(l, ":")
                    if (idx == 0) continue
                    key = tolower(substr(l, 1, idx - 1))
                    gsub(/^[ \t]+|[ \t]+$/, "", key)
                    val = substr(l, idx + 1)
                    gsub(/^[ \t]+|[ \t]+$/, "", val)
                    if (key == "types") types = val
                    else if (key == "uris") uris = val
                    else if (key == "suites") suites = val
                    else if (key == "components") comps = val
                    else if (key == "enabled") enabled = tolower(val)
                }
                if (enabled == "no" || enabled == "false" || enabled == "0") next
                if (types != "" && (" " types " ") !~ /[[:space:]]deb[[:space:]]/) next
                if (uris != "" || suites != "" || comps != "") {
                    print uris "\t" suites "\t" comps
                }
            }
        ' "${source_files[@]}"
    fi
}

is_apt_component_active() {
    local target="$1"
    _apt_list_active_entries | awk -F'\t' -v t="$target" '
        {
            n = split($3, c, /[[:space:]]+/)
            for (i = 1; i <= n; i++) {
                if (c[i] == t) { found = 1; exit 0 }
            }
        }
        END { exit(found ? 0 : 1) }
    '
}

is_apt_repo_active() {
    local pattern="$1"
    _apt_list_active_entries | awk -F'\t' -v pat="$pattern" '
        BEGIN { pat = tolower(pat) }
        {
            if (tolower($1 "\t" $2) ~ pat) { found = 1; exit 0 }
        }
        END { exit(found ? 0 : 1) }
    '
}

ensure_repo_context() {
    detect_linux_env
    if [ "${REPO_MENU_DONE:-0}" != "1" ] && [ -z "${SELECTED_REPOS+x}" ]; then
        if [ -f "$DISTRO_DIR/repo.sh" ]; then
            source "$DISTRO_DIR/repo.sh" --init-defaults
        fi
    fi
}

reset_repo_registry() {
    REPO_CORE=""
    REPO_IDS=()
    REPO_TAGS=()
    REPO_DESCS=()
    REPO_DEFAULTS=()
}

register_repo() {
    REPO_IDS+=("$1")
    REPO_TAGS+=("$2")
    REPO_DESCS+=("$3")
    REPO_DEFAULTS+=("$4")
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
    local input="" token="" idx="" partner="" j=""

    while true; do
        echo ""
        echo "========================================================================"
        echo "  REPOSITORY SELECTION MENU (${DISTRO^^} ${DISTRO_VER} | ${PKG})"
        echo "========================================================================"
        echo "  Always Enabled Core : ${REPO_CORE}"
        echo "------------------------------------------------------------------------"
        printf "  %-3s %-4s %-25s %-14s %s\n" "#" "Stat" "Repository" "Category" "Description"
        echo "------------------------------------------------------------------------"

        local i
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
        echo "            [d] Reset Detected (Active) | [Enter / c] Confirm & Continue"
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

    echo -e "\n==> Selected Repositories (${DISTRO}): ${SELECTED_REPOS:-none (core only)}"
}

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

    echo ""
    echo "========================================================================"
    echo "  GPU DRIVER SELECTION MENU (${DISTRO^^} | ${PKG})"
    echo "========================================================================"
    echo "  1) ${NVIDIA_LABEL}"
    echo "  2) ${AMD_LABEL}"
    echo "  3) ${INTEL_LABEL}"
    echo "  4) Skip"
    echo "------------------------------------------------------------------------"

    while true; do
        if ! read -rp "Choice [1-4, default 4]: " GPU_CHOICE; then
            GPU_CHOICE="4"
            break
        fi
        GPU_CHOICE="${GPU_CHOICE:-4}"
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
    if [ "$GPU_CHOICE" = "1" ] && [ "${NVIDIA_AVAILABLE:-1}" -eq 1 ]; then
        if ! read -rp "  -> Apply RTX 5060 power & clock limit (5060tune)? [y/N]: " NVD_TUNE; then
            NVD_TUNE="N"
        fi
        NVD_TUNE="${NVD_TUNE:-N}"
    fi

    export GPU_CHOICE GPU_VENDOR NVD_TUNE
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

    local choice=""
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

reset_app_registry() {
    APP_IDS=()
    APP_SOURCES=()
    APP_DESCS=()
    APP_DEFAULTS=()
}

register_app() {
    APP_IDS+=("$1")
    APP_SOURCES+=("$2")
    APP_DESCS+=("$3")
    APP_DEFAULTS+=("$4")
}

prompt_pick_search_results() {
    local mode="$1"
    local count="${#SEARCH_PKGS[@]}"
    if [ "$count" -eq 0 ]; then
        echo "  -> No matching packages found (in currently selected repositories)."
        return 0
    fi

    echo ""
    echo "------------------------------------------------------------------------"
    printf "  %-3s %-36s %s\n" "#" "Package / App ID" "Description"
    echo "------------------------------------------------------------------------"
    local i
    for ((i = 0; i < count; i++)); do
        printf "  %-3s %-36s %s\n" "$((i + 1))" "${SEARCH_PKGS[$i]}" "${SEARCH_DESCS[$i]}"
    done
    echo "------------------------------------------------------------------------"
    echo "  Enter number(s) to add (e.g. '1 3' or '2,4'), or [Enter] to cancel:"

    local pick="" token="" idx=""
    if ! read -rp "Add #> " pick; then
        pick=""
    fi
    pick="${pick//,/ }"
    for token in $pick; do
        if [[ "$token" =~ ^[0-9]+$ ]] && [ "$token" -ge 1 ] && [ "$token" -le "$count" ]; then
            idx=$((token - 1))
            if [ "$mode" = "flatpak" ]; then
                EXTRA_FLATPAK_PKGS="$(append_unique_tokens "${EXTRA_FLATPAK_PKGS:-}" "${SEARCH_PKGS[$idx]}")"
                echo "  + Added Flatpak: ${SEARCH_PKGS[$idx]}"
            else
                EXTRA_NATIVE_PKGS="$(append_unique_tokens "${EXTRA_NATIVE_PKGS:-}" "${SEARCH_PKGS[$idx]}")"
                echo "  + Added Native/AUR: ${SEARCH_PKGS[$idx]}"
            fi
        else
            echo "  -> Ignored invalid selection: '$token'"
        fi
    done
}

search_native_packages() {
    local query
    query="$(trim_whitespace "${1:-}")"
    SEARCH_PKGS=()
    SEARCH_DESCS=()

    if [ -z "$query" ]; then
        echo "  -> Please provide a search keyword (e.g. '/firefox' or 's neovim')."
        return 0
    fi

    echo "==> Searching enabled repositories for '$query' ($PKG | ${DISTRO})..."
    local line="" pkg_name="" pkg_desc=""

    case "$PKG" in
        apt)
            while IFS= read -r line; do
                [ -n "$line" ] || continue
                pkg_name="${line%% - *}"
                pkg_desc="${line#* - }"
                [ "$pkg_desc" = "$line" ] && pkg_desc=""
                SEARCH_PKGS+=("$pkg_name")
                SEARCH_DESCS+=("${pkg_desc:0:60}")
            done < <(apt-cache search --names-only "$query" 2>/dev/null | head -n 15 || true)

            if [ "${#SEARCH_PKGS[@]}" -eq 0 ]; then
                while IFS= read -r line; do
                    [ -n "$line" ] || continue
                    pkg_name="${line%% - *}"
                    pkg_desc="${line#* - }"
                    [ "$pkg_desc" = "$line" ] && pkg_desc=""
                    SEARCH_PKGS+=("$pkg_name")
                    SEARCH_DESCS+=("${pkg_desc:0:60}")
                done < <(apt-cache search "$query" 2>/dev/null | head -n 15 || true)
            fi
            ;;

        dnf)
            local -a dnf_disablerepos=()
            repo_enabled "rpmfusion-free"            || dnf_disablerepos+=("--disablerepo=rpmfusion-free*")
            repo_enabled "rpmfusion-nonfree"         || dnf_disablerepos+=("--disablerepo=rpmfusion-nonfree*")
            repo_enabled "rpmfusion-free-tainted"    || dnf_disablerepos+=("--disablerepo=rpmfusion-free-tainted*")
            repo_enabled "rpmfusion-nonfree-tainted" || dnf_disablerepos+=("--disablerepo=rpmfusion-nonfree-tainted*")
            repo_enabled "terra"                     || dnf_disablerepos+=("--disablerepo=terra*")
            repo_enabled "epel"                      || dnf_disablerepos+=("--disablerepo=epel*")
            repo_enabled "elrepo"                    || dnf_disablerepos+=("--disablerepo=elrepo*")
            repo_enabled "synergy"                   || dnf_disablerepos+=("--disablerepo=synergy*")
            repo_enabled "plus"                      || dnf_disablerepos+=("--disablerepo=plus*")
            repo_enabled "vscodium"                  || dnf_disablerepos+=("--disablerepo=vscodium*")
            repo_enabled "tailscale"                 || dnf_disablerepos+=("--disablerepo=tailscale*")
            repo_enabled "updates-testing"           || dnf_disablerepos+=("--disablerepo=*testing*")

            while IFS= read -r line; do
                [ -n "$line" ] || continue
                [[ "$line" == ===* ]] && continue
                [[ "$line" == Matched\ fields:* ]] && continue
                if [[ "$line" == *:* ]]; then
                    pkg_name="$(printf '%s' "${line%%:*}" | awk '{print $1}')"
                    pkg_name="${pkg_name%%.*}"
                    pkg_desc="${line#*: }"
                    [ -n "$pkg_name" ] || continue
                    SEARCH_PKGS+=("$pkg_name")
                    SEARCH_DESCS+=("${pkg_desc:0:60}")
                fi
            done < <(dnf search -q "${dnf_disablerepos[@]}" "$query" 2>/dev/null | head -n 25 || true)
            if [ "${#SEARCH_PKGS[@]}" -gt 15 ]; then
                SEARCH_PKGS=("${SEARCH_PKGS[@]:0:15}")
                SEARCH_DESCS=("${SEARCH_DESCS[@]:0:15}")
            fi
            ;;

        zypper)
            while IFS='|' read -r _status name summary _type; do
                name="$(trim_whitespace "$name")"
                summary="$(trim_whitespace "$summary")"
                [ -n "$name" ] || continue
                [ "$name" = "Name" ] && continue
                SEARCH_PKGS+=("$name")
                SEARCH_DESCS+=("${summary:0:60}")
            done < <(zypper --non-interactive search "$query" 2>/dev/null | grep '|' | head -n 16 || true)
            if [ "${#SEARCH_PKGS[@]}" -gt 15 ]; then
                SEARCH_PKGS=("${SEARCH_PKGS[@]:0:15}")
                SEARCH_DESCS=("${SEARCH_DESCS[@]:0:15}")
            fi
            ;;

        pacman)
            while IFS=$'\t' read -r pkg_name pkg_desc; do
                [ -n "$pkg_name" ] || continue
                SEARCH_PKGS+=("$pkg_name")
                SEARCH_DESCS+=("${pkg_desc:0:60}")
            done < <(pacman -Ss "$query" 2>/dev/null | awk '
                /^[^[:space:]]+\/[^[:space:]]+/ {
                    split($1, a, "/");
                    pkg = a[2];
                    repo = a[1];
                    getline desc;
                    gsub(/^[[:space:]]+/, "", desc);
                    print pkg "\t[" repo "] " desc;
                }
            ' | head -n 10 || true)

            local include_aur=0
            if repo_enabled "aur-paru" || repo_enabled "aur-yay"; then
                include_aur=1
            fi

            if [ "${#SEARCH_PKGS[@]}" -lt 15 ] && command -v curl >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
                while IFS=$'\t' read -r pkg_name pkg_desc; do
                    [ -n "$pkg_name" ] || continue
                    if [[ " ${SEARCH_PKGS[*]} " != *" $pkg_name "* ]]; then
                        SEARCH_PKGS+=("$pkg_name")
                        SEARCH_DESCS+=("${pkg_desc:0:60}")
                        [ "${#SEARCH_PKGS[@]}" -ge 15 ] && break
                    fi
                done < <(SEARCH_Q="$query" INCLUDE_AUR="$include_aur" python3 - <<'PYEOF' 2>/dev/null || true
import json, os, urllib.parse, urllib.request

q = os.environ.get("SEARCH_Q", "")
include_aur = os.environ.get("INCLUDE_AUR", "0") == "1"
enc = urllib.parse.quote(q)
seen = set()

def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "LinuxSetup/1.0"})
    with urllib.request.urlopen(req, timeout=5) as r:
        return json.loads(r.read().decode("utf-8", "ignore"))

try:
    data = fetch(f"https://archlinux.org/packages/search/json/?q={enc}")
    for res in data.get("results", [])[:8]:
        name = res.get("pkgname", "")
        repo = res.get("repo", "arch")
        desc = res.get("pkgdesc", "")
        if name and name not in seen:
            seen.add(name)
            print(f"{name}\t[{repo}] {desc}")
except Exception:
    pass

if include_aur:
    try:
        aur = fetch(f"https://aur.archlinux.org/rpc/?v=5&type=search&arg={enc}")
        for res in aur.get("results", [])[:8]:
            name = res.get("Name", "")
            desc = res.get("Description", "") or ""
            if name and name not in seen:
                seen.add(name)
                print(f"{name}\t[AUR] {desc}")
    except Exception:
        pass
PYEOF
)
            fi
            ;;
    esac

    prompt_pick_search_results "native"
}

run_apps_menu() {
    ensure_repo_context
    reset_app_registry
    distro_init_apps
    if declare -F init_flatpak_apps >/dev/null 2>&1; then
        init_flatpak_apps
    fi

    local count="${#APP_IDS[@]}"
    local -a state=("${APP_DEFAULTS[@]}")
    EXTRA_NATIVE_PKGS="${EXTRA_NATIVE_PKGS:-}"
    EXTRA_FLATPAK_PKGS="${EXTRA_FLATPAK_PKGS:-}"
    local flathub_on=0
    if repo_enabled "flathub"; then
        flathub_on=1
    fi
    local input="" token="" idx=""

    while true; do
        echo ""
        echo "========================================================================"
        echo "  APPLICATIONS SELECTION MENU (${DISTRO^^} | ${PKG})"
        echo "========================================================================"
        echo "  Active Repositories : ${SELECTED_REPOS:-core only}"
        echo "------------------------------------------------------------------------"
        printf "  %-3s %-4s %-15s %-25s %s\n" "#" "Stat" "Application" "From Repository" "Description"
        echo "------------------------------------------------------------------------"

        local i
        for ((i = 0; i < count; i++)); do
            local mark="[ ]"
            if [ "${state[$i]}" -eq 1 ]; then
                mark="[x]"
            fi
            printf "  %-3s %-4s %-15s %-25s %s\n" \
                "$((i + 1))" "$mark" "${APP_IDS[$i]}" "[${APP_SOURCES[$i]}]" "${APP_DESCS[$i]}"
        done

        echo "------------------------------------------------------------------------"
        echo "  Extra Native/AUR : ${EXTRA_NATIVE_PKGS:-none}"
        if [ "$flathub_on" -eq 1 ]; then
            echo "  Extra Flatpak    : ${EXTRA_FLATPAK_PKGS:-none}"
        else
            echo "  Extra Flatpak    : [disabled — Flathub repository was not selected]"
        fi
        echo "------------------------------------------------------------------------"
        echo "  Controls:"
        echo "    [1-${count}] Toggle preset (e.g. '1 8' or '2,5') | [a] All | [n] None | [d] Default"
        echo "    [/ <query>] or [s <query>]  Live search enabled Native/AUR repositories"
        echo "    [+ <pkg...>] / [- <pkg...>] Add or remove custom Native/AUR package(s)"
        if [ "$flathub_on" -eq 1 ]; then
            echo "    [sf <query>]                Live search Flathub online"
            echo "    [+f <id...>] / [-f <id...>] Add or remove custom Flatpak App ID(s)"
        fi
        echo "    [clear] Clear extra lists   | [Enter / c] Confirm & Continue"
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
                    state[$i]=1
                done
                ;;
            n|none)
                for ((i = 0; i < count; i++)); do
                    state[$i]=0
                done
                ;;
            clear)
                EXTRA_NATIVE_PKGS=""
                EXTRA_FLATPAK_PKGS=""
                ;;
            d|default)
                state=("${APP_DEFAULTS[@]}")
                ;;
            /*)
                search_native_packages "${input#/}"
                ;;
            s\ *)
                search_native_packages "${input:2}"
                ;;
            sf\ *)
                if declare -F search_flatpak_packages >/dev/null 2>&1; then
                    search_flatpak_packages "${input:3}"
                else
                    echo "  -> Flatpak helper is not loaded."
                fi
                ;;
            +f\ *)
                if [ "$flathub_on" -eq 1 ]; then
                    EXTRA_FLATPAK_PKGS="$(append_unique_tokens "$EXTRA_FLATPAK_PKGS" ${input:3})"
                else
                    echo "  -> Flathub repository was not selected in Repository Menu."
                fi
                ;;
            -f\ *)
                if [ "$flathub_on" -eq 1 ]; then
                    EXTRA_FLATPAK_PKGS="$(remove_tokens "$EXTRA_FLATPAK_PKGS" ${input:3})"
                else
                    echo "  -> Flathub repository was not selected in Repository Menu."
                fi
                ;;
            +\ *)
                EXTRA_NATIVE_PKGS="$(append_unique_tokens "$EXTRA_NATIVE_PKGS" ${input:2})"
                ;;
            -\ *)
                EXTRA_NATIVE_PKGS="$(remove_tokens "$EXTRA_NATIVE_PKGS" ${input:2})"
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
                        fi
                    else
                        echo "  -> Ignored invalid option: '$token'"
                    fi
                done
                ;;
        esac
    done

    SELECTED_APPS=""
    for ((i = 0; i < count; i++)); do
        if [ "${state[$i]}" -eq 1 ]; then
            SELECTED_APPS="${SELECTED_APPS:+$SELECTED_APPS }${APP_IDS[$i]}"
        fi
    done

    if [ -n "$SELECTED_APPS" ] || [ -n "$EXTRA_NATIVE_PKGS" ] || [ -n "$EXTRA_FLATPAK_PKGS" ]; then
        INSTALL_APPS="Y"
    else
        INSTALL_APPS="N"
    fi

    APPS_MENU_DONE=1
    export SELECTED_APPS EXTRA_NATIVE_PKGS EXTRA_FLATPAK_PKGS APPS_MENU_DONE INSTALL_APPS

    echo -e "\n==> Selected Preset Apps : ${SELECTED_APPS:-none}"
    if [ -n "$EXTRA_NATIVE_PKGS" ]; then
        echo "==> Extra Native/AUR     : $EXTRA_NATIVE_PKGS"
    fi
    if [ -n "$EXTRA_FLATPAK_PKGS" ]; then
        echo "==> Extra Flatpak        : $EXTRA_FLATPAK_PKGS"
    fi
}

ensure_vscodium_apt_repo() {
    if ! is_apt_repo_active "vscodium"; then
        echo "==> Adding VSCodium APT repository..."
        sudo mkdir -p /usr/share/keyrings
        curl -fsSL https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
            | gpg --dearmor --yes \
            | sudo tee /usr/share/keyrings/vscodium.gpg > /dev/null
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/vscodium.gpg] https://download.vscodium.com/debs vscodium main" \
            | sudo tee /etc/apt/sources.list.d/vscodium.list > /dev/null
        if [ "${1:-}" = "--update" ]; then
            sudo apt update -y
        fi
    fi
}

disable_vscodium_apt_repo() {
    if [ -f /etc/apt/sources.list.d/vscodium.list ] || [ -f /etc/apt/sources.list.d/vscodium.sources ]; then
        echo "==> Disabling VSCodium APT repository..."
        sudo rm -f /etc/apt/sources.list.d/vscodium.list /etc/apt/sources.list.d/vscodium.sources
    fi
}

ensure_vscodium_dnf_repo() {
    if [ ! -f /etc/yum.repos.d/vscodium.repo ]; then
        echo "==> Adding VSCodium RPM repository..."
        local tmp_key
        tmp_key="$(mktemp /tmp/vscodium.XXXXXX.gpg)"
        if curl -fsSL https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg -o "$tmp_key"; then
            sudo rpm --import "$tmp_key" 2>/dev/null || true
        fi
        rm -f "$tmp_key"
        sudo tee /etc/yum.repos.d/vscodium.repo > /dev/null <<'EOF'
[vscodium]
name=VSCodium
baseurl=https://download.vscodium.com/rpms/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg
metadata_expire=1h
EOF
    else
        sudo sed -i 's/^[[:space:]]*enabled[[:space:]]*=.*/enabled=1/' /etc/yum.repos.d/vscodium.repo 2>/dev/null || true
        set_dnf_repo_enabled "vscodium" 1
    fi
}

disable_vscodium_dnf_repo() {
    if is_dnf_repo_active '^vscodium' || [ -f /etc/yum.repos.d/vscodium.repo ]; then
        echo "==> Disabling VSCodium RPM repository..."
        set_dnf_repo_enabled "vscodium" 0
    fi
}

ensure_vscodium_zypper_repo() {
    if [ ! -f /etc/zypp/repos.d/vscodium.repo ]; then
        echo "==> Adding VSCodium Zypper repository..."
        local tmp_key
        tmp_key="$(mktemp /tmp/vscodium.XXXXXX.gpg)"
        if curl -fsSL https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg -o "$tmp_key"; then
            sudo rpm --import "$tmp_key" 2>/dev/null || true
        fi
        rm -f "$tmp_key"
        sudo tee /etc/zypp/repos.d/vscodium.repo > /dev/null <<'EOF'
[vscodium]
name=VSCodium
enabled=1
autorefresh=1
baseurl=https://download.vscodium.com/rpms/
type=rpm-md
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg
EOF
    else
        sudo zypper mr -e vscodium 2>/dev/null || zypper_set_matching_repos_enabled 'vscodium' e
    fi
    if [ "${1:-}" = "--refresh" ]; then
        sudo zypper --non-interactive --gpg-auto-import-keys refresh vscodium 2>/dev/null || true
    fi
}

disable_vscodium_zypper_repo() {
    if is_zypper_repo_active 'vscodium'; then
        echo "==> Disabling VSCodium Zypper repository..."
        zypper_set_matching_repos_enabled 'vscodium' d
    fi
}

ensure_tailscale_installed() {
    if app_enabled "tailscale" && ! command -v tailscale >/dev/null 2>&1; then
        echo "==> Installing Tailscale..."
        curl -fsSL https://tailscale.com/install.sh | sudo sh
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
