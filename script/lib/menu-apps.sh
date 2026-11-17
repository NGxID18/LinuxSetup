#!/usr/bin/env bash

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

_TUI_STATUS_MSG=""

prompt_pick_search_results() {
    local mode="$1"
    local count="${#SEARCH_PKGS[@]}"
    if [ "$count" -eq 0 ]; then
        if [ "${_TUI_ACTIVE:-0}" -eq 1 ]; then
            _TUI_STATUS_MSG="Paket tidak ditemukan di repository yang aktif saat ini."
        else
            echo "  -> No matching packages found (in currently selected repositories)."
        fi
        return 0
    fi

    if tui_is_interactive; then
        tui_enter_screen
        local -a picked=()
        local i cursor=0 scroll_top=0 term_rows max_vis end_idx
        for ((i = 0; i < count; i++)); do
            picked[$i]=0
        done

        local cancel_pick=0
        while true; do
            term_rows="$(tui_term_rows)"
            max_vis=$((term_rows - 10))
            [ "$max_vis" -lt 5 ] && max_vis=5
            [ "$cursor" -lt "$scroll_top" ] && scroll_top="$cursor"
            if [ "$cursor" -ge $((scroll_top + max_vis)) ]; then
                scroll_top=$((cursor - max_vis + 1))
            fi
            end_idx=$((scroll_top + max_vis))
            [ "$end_idx" -gt "$count" ] && end_idx="$count"

            printf '\e[H'
            printf '\e[1;36m========================================================================\e[0m\e[K\n'
            printf '\e[1;37m  HASIL PENCARIAN (%s | %d ditemukan)\e[0m\e[K\n' "${mode^^}" "$count"
            printf '\e[1;36m========================================================================\e[0m\e[K\n'
            printf '    %-3s %-4s %-34s %s\e[K\n' "#" "Pick" "Package / App ID" "Description"
            printf '\e[90m------------------------------------------------------------------------\e[0m\e[K\n'

            for ((i = scroll_top; i < end_idx; i++)); do
                local mark="[ ]" mark_col="\e[90m"
                if [ "${picked[$i]}" -eq 1 ]; then
                    mark="[+]"
                    mark_col="\e[1;32m"
                fi
                if [ "$i" -eq "$cursor" ]; then
                    printf '\e[7;1m> %-3s %-4s %-34s %s\e[0m\e[K\n' \
                        "$((i + 1))" "$mark" "$(tui_truncate "${SEARCH_PKGS[$i]}" 34)" "$(tui_truncate "${SEARCH_DESCS[$i]}" 32)"
                else
                    printf '  %-3s %b%-4s\e[0m %-34s %s\e[K\n' \
                        "$((i + 1))" "$mark_col" "$mark" "$(tui_truncate "${SEARCH_PKGS[$i]}" 34)" "$(tui_truncate "${SEARCH_DESCS[$i]}" 32)"
                fi
            done

            printf '\e[90m------------------------------------------------------------------------\e[0m\e[K\n'
            printf '  [↑/↓/j/k] Pilih   [Space] Tandai [+]   [a] Tandai Semua\e[K\n'
            printf '  [Enter] Tambahkan paket bertanda (atau yg disorot)   [q/ESC] Batal\e[K\n'
            printf '\e[1;36m========================================================================\e[0m\e[J'

            tui_read_key
            case "$_TUI_KEY" in
                UP|k|K)   cursor=$(( (cursor - 1 + count) % count )) ;;
                DOWN|j|J) cursor=$(( (cursor + 1) % count )) ;;
                HOME)     cursor=0 ;;
                END)      cursor=$((count - 1)) ;;
                SPACE)
                    if [ "${picked[$cursor]}" -eq 1 ]; then
                        picked[$cursor]=0
                    else
                        picked[$cursor]=1
                    fi
                    ;;
                a|A)
                    for ((i = 0; i < count; i++)); do picked[$i]=1; done
                    ;;
                ENTER)
                    break
                    ;;
                q|Q|ESC|EOF)
                    cancel_pick=1
                    break
                    ;;
            esac
        done
        tui_leave_screen

        if [ "$cancel_pick" -eq 1 ]; then
            _TUI_STATUS_MSG="Pencarian dibatalkan."
            return 0
        fi

        local -a chosen=()
        for ((i = 0; i < count; i++)); do
            [ "${picked[$i]}" -eq 1 ] && chosen+=("${SEARCH_PKGS[$i]}")
        done
        if [ "${#chosen[@]}" -eq 0 ]; then
            chosen+=("${SEARCH_PKGS[$cursor]}")
        fi

        local pkg_item added_list=""
        for pkg_item in "${chosen[@]}"; do
            if [ "$mode" = "flatpak" ]; then
                EXTRA_FLATPAK_PKGS="$(append_unique_tokens "${EXTRA_FLATPAK_PKGS:-}" "$pkg_item")"
            else
                EXTRA_NATIVE_PKGS="$(append_unique_tokens "${EXTRA_NATIVE_PKGS:-}" "$pkg_item")"
            fi
            added_list="${added_list:+${added_list}, }${pkg_item}"
        done
        _TUI_STATUS_MSG="Ditambahkan (${mode}): ${added_list}"
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

_populate_default_apps_registry() {
    ensure_repo_context
    if ! declare -F distro_init_apps >/dev/null 2>&1 && [ -f "$DISTRO_DIR/apps.sh" ]; then
        source "$DISTRO_DIR/apps.sh" ""
    fi

    reset_app_registry
    if declare -F distro_init_apps >/dev/null 2>&1; then
        distro_init_apps
    fi
    if declare -F init_flatpak_apps >/dev/null 2>&1; then
        init_flatpak_apps
    fi
}

_finalize_selected_apps() {
    local -a flags=("$@")
    local count="${#APP_IDS[@]}"
    local i
    SELECTED_APPS=""
    for ((i = 0; i < count; i++)); do
        if [ "${flags[$i]:-0}" -eq 1 ]; then
            SELECTED_APPS="${SELECTED_APPS:+$SELECTED_APPS }${APP_IDS[$i]}"
        fi
    done

    EXTRA_NATIVE_PKGS="${EXTRA_NATIVE_PKGS:-}"
    EXTRA_FLATPAK_PKGS="${EXTRA_FLATPAK_PKGS:-}"
    if [ -n "$SELECTED_APPS" ] || [ -n "$EXTRA_NATIVE_PKGS" ] || [ -n "$EXTRA_FLATPAK_PKGS" ]; then
        INSTALL_APPS="Y"
    else
        INSTALL_APPS="N"
    fi
    export SELECTED_APPS EXTRA_NATIVE_PKGS EXTRA_FLATPAK_PKGS INSTALL_APPS
}

init_default_apps() {
    _populate_default_apps_registry
    _finalize_selected_apps "${APP_DEFAULTS[@]}"
}

_apps_toggle_idx() {
    local idx="$1"
    if [ "${state[$idx]}" -eq 1 ]; then
        state[$idx]=0
    else
        state[$idx]=1
    fi
}

_apps_apply_preset() {
    local preset="$1"
    local count="${#APP_IDS[@]}"
    local i
    case "$preset" in
        all)
            for ((i = 0; i < count; i++)); do state[$i]=1; done
            status_msg="Semua aplikasi preset dipilih."
            ;;
        none)
            for ((i = 0; i < count; i++)); do state[$i]=0; done
            status_msg="Semua aplikasi preset dikosongkan."
            ;;
        default)
            state=("${APP_DEFAULTS[@]}")
            status_msg="Aplikasi preset dikembalikan ke setelan default."
            ;;
        clear)
            EXTRA_NATIVE_PKGS=""
            EXTRA_FLATPAK_PKGS=""
            status_msg="Daftar aplikasi custom (Extra) dikosongkan."
            ;;
    esac
}

run_apps_menu() {
    _populate_default_apps_registry

    local count="${#APP_IDS[@]}"
    local -a state=("${APP_DEFAULTS[@]}")
    if [ "${APPS_MENU_DONE:-0}" = "1" ] && [ -n "${SELECTED_APPS+x}" ]; then
        local idx_init
        for ((idx_init = 0; idx_init < count; idx_init++)); do
            if app_enabled "${APP_IDS[$idx_init]}"; then
                state[$idx_init]=1
            else
                state[$idx_init]=0
            fi
        done
    fi

    EXTRA_NATIVE_PKGS="${EXTRA_NATIVE_PKGS:-}"
    EXTRA_FLATPAK_PKGS="${EXTRA_FLATPAK_PKGS:-}"
    local flathub_on=0
    if repo_enabled "flathub"; then
        flathub_on=1
    fi
    local i status_msg=""

    if tui_is_interactive; then
        tui_enter_screen
        local cursor=0 scroll_top=0 term_rows max_vis end_idx

        while true; do
            term_rows="$(tui_term_rows)"
            max_vis=$((term_rows - 16))
            [ "$max_vis" -lt 5 ] && max_vis=5
            if [ "$count" -gt 0 ]; then
                [ "$cursor" -ge "$count" ] && cursor=$((count - 1))
                [ "$cursor" -lt "$scroll_top" ] && scroll_top="$cursor"
                if [ "$cursor" -ge $((scroll_top + max_vis)) ]; then
                    scroll_top=$((cursor - max_vis + 1))
                fi
                end_idx=$((scroll_top + max_vis))
                [ "$end_idx" -gt "$count" ] && end_idx="$count"
            else
                scroll_top=0
                end_idx=0
            fi

            printf '\e[H'
            printf '\e[1;36m========================================================================\e[0m\e[K\n'
            printf '\e[1;37m  APPLICATIONS SELECTION MENU (%s | %s)\e[0m\e[K\n' "${DISTRO^^}" "${PKG}"
            printf '\e[1;36m========================================================================\e[0m\e[K\n'
            printf '  Panduan : \e[1;32m[Space]\e[0m Centang/Lepas  \e[1;32m[/]\e[0m Cari Paket  \e[1;32m[Enter]\e[0m Simpan\e[K\n'
            printf '  Repo    : \e[36m%s\e[0m\e[K\n' "$(tui_truncate "${SELECTED_REPOS:-core only}" 58)"
            printf '\e[90m------------------------------------------------------------------------\e[0m\e[K\n'
            printf '    %-3s %-4s %-15s %-22s %s\e[K\n' "#" "Stat" "Application" "From Repository" "Description"
            printf '\e[90m------------------------------------------------------------------------\e[0m\e[K\n'

            for ((i = scroll_top; i < end_idx; i++)); do
                local mark="[ ]" mark_col="\e[90m"
                if [ "${state[$i]}" -eq 1 ]; then
                    mark="[x]"
                    mark_col="\e[1;32m"
                fi
                if [ "$i" -eq "$cursor" ]; then
                    printf '\e[7;1m> %-3s %-4s %-15s %-22s %s\e[0m\e[K\n' \
                        "$((i + 1))" "$mark" "${APP_IDS[$i]}" "[${APP_SOURCES[$i]}]" "$(tui_truncate "${APP_DESCS[$i]}" 38)"
                else
                    printf '  %-3s %b%-4s\e[0m %-15s \e[33m%-22s\e[0m %s\e[K\n' \
                        "$((i + 1))" "$mark_col" "$mark" "${APP_IDS[$i]}" "[${APP_SOURCES[$i]}]" "$(tui_truncate "${APP_DESCS[$i]}" 38)"
                fi
            done

            printf '\e[90m------------------------------------------------------------------------\e[0m\e[K\n'
            if [ "$count" -gt 0 ]; then
                printf '  \e[1;36mINFO :\e[0m \e[1m%s\e[0m [%s] — %s\e[K\n' \
                    "${APP_IDS[$cursor]}" "${APP_SOURCES[$cursor]}" "$(tui_truncate "${APP_DESCS[$cursor]}" 48)"
            fi
            printf '  Extra Native/AUR : %s\e[K\n' "$(tui_truncate "${EXTRA_NATIVE_PKGS:-none}" 54)"
            if [ "$flathub_on" -eq 1 ]; then
                printf '  Extra Flatpak    : %s\e[K\n' "$(tui_truncate "${EXTRA_FLATPAK_PKGS:-none}" 54)"
            else
                printf '  Extra Flatpak    : \e[90m[nonaktif — aktifkan repo Flathub terlebih dulu]\e[0m\e[K\n'
            fi
            if [ -n "$status_msg" ]; then
                printf '  \e[1;33m%s\e[0m\e[K\n' "$status_msg"
            else
                printf '\e[K\n'
            fi
            printf '  [↑/↓/j/k] Pilih  [Space] Centang  [a] Semua  [n] Kosong  [d] Default  [x] Hapus Extra\e[K\n'
            if [ "$flathub_on" -eq 1 ]; then
                printf '  [/ or s] Cari Repo  [f] Cari Flathub  [+] Tambah Native  [F] Tambah Flatpak\e[K\n'
                printf '  [-] Hapus Custom    [?] Bantuan       [Enter/c/q] Simpan & Kembali\e[K\n'
            else
                printf '  [/ or s] Cari Repo  [+] Tambah Native [-] Hapus Custom   [?] Bantuan\e[K\n'
                printf '  [Enter/c/q] Simpan & Kembali\e[K\n'
            fi
            printf '\e[1;36m========================================================================\e[0m\e[J'

            status_msg=""
            tui_read_key
            case "$_TUI_KEY" in
                UP|k|K)
                    [ "$count" -gt 0 ] && cursor=$(( (cursor - 1 + count) % count ))
                    ;;
                DOWN|j|J)
                    [ "$count" -gt 0 ] && cursor=$(( (cursor + 1) % count ))
                    ;;
                PGUP)
                    cursor=$((cursor - max_vis))
                    [ "$cursor" -lt 0 ] && cursor=0
                    ;;
                PGDN)
                    cursor=$((cursor + max_vis))
                    [ "$cursor" -ge "$count" ] && cursor=$((count - 1))
                    [ "$cursor" -lt 0 ] && cursor=0
                    ;;
                HOME)
                    cursor=0
                    ;;
                END)
                    [ "$count" -gt 0 ] && cursor=$((count - 1))
                    ;;
                \?|h|H)
                    tui_show_help_modal "apps"
                    ;;
                SPACE)
                    [ "$count" -gt 0 ] && _apps_toggle_idx "$cursor"
                    ;;
                [1-9])
                    if [ "$_TUI_KEY" -le "$count" ]; then
                        cursor=$((_TUI_KEY - 1))
                        _apps_toggle_idx "$cursor"
                    fi
                    ;;
                a|A) _apps_apply_preset "all" ;;
                n|N) _apps_apply_preset "none" ;;
                d|D) _apps_apply_preset "default" ;;
                x|X) _apps_apply_preset "clear" ;;
                /|s|S)
                    tui_prompt_line "Cari paket di repo Native/AUR (contoh: firefox): "
                    if [ -n "$_TUI_INPUT" ]; then
                        _TUI_STATUS_MSG=""
                        printf '\e[H\e[2J\e[1;36m==> Mencari "%s" di repository aktif...\e[0m\n' "$_TUI_INPUT"
                        search_native_packages "$_TUI_INPUT"
                        status_msg="${_TUI_STATUS_MSG:-}"
                    fi
                    ;;
                f)
                    if [ "$flathub_on" -eq 1 ]; then
                        tui_prompt_line "Cari aplikasi di Flathub (contoh: gimp): "
                        if [ -n "$_TUI_INPUT" ]; then
                            _TUI_STATUS_MSG=""
                            printf '\e[H\e[2J\e[1;36m==> Mencari "%s" di Flathub online...\e[0m\n' "$_TUI_INPUT"
                            if declare -F search_flatpak_packages >/dev/null 2>&1; then
                                search_flatpak_packages "$_TUI_INPUT"
                                status_msg="${_TUI_STATUS_MSG:-}"
                            else
                                status_msg="Helper Flatpak belum dimuat."
                            fi
                        fi
                    else
                        status_msg="Repository Flathub belum diaktifkan di Menu Repository."
                    fi
                    ;;
                +)
                    tui_prompt_line "Tambah nama paket Native/AUR (pisahkan dengan spasi): "
                    if [ -n "$_TUI_INPUT" ]; then
                        EXTRA_NATIVE_PKGS="$(append_unique_tokens "$EXTRA_NATIVE_PKGS" $_TUI_INPUT)"
                        status_msg="Daftar Extra Native/AUR diperbarui."
                    fi
                    ;;
                F)
                    if [ "$flathub_on" -eq 1 ]; then
                        tui_prompt_line "Tambah Flatpak App ID (contoh: org.gimp.GIMP): "
                        if [ -n "$_TUI_INPUT" ]; then
                            EXTRA_FLATPAK_PKGS="$(append_unique_tokens "$EXTRA_FLATPAK_PKGS" $_TUI_INPUT)"
                            status_msg="Daftar Extra Flatpak diperbarui."
                        fi
                    else
                        status_msg="Repository Flathub belum diaktifkan di Menu Repository."
                    fi
                    ;;
                -)
                    tui_prompt_line "Hapus paket custom Native/AUR atau Flatpak: "
                    if [ -n "$_TUI_INPUT" ]; then
                        EXTRA_NATIVE_PKGS="$(remove_tokens "$EXTRA_NATIVE_PKGS" $_TUI_INPUT)"
                        EXTRA_FLATPAK_PKGS="$(remove_tokens "$EXTRA_FLATPAK_PKGS" $_TUI_INPUT)"
                        status_msg="Menghapus '$_TUI_INPUT' dari daftar custom."
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
            echo "  APPLICATIONS SELECTION MENU (${DISTRO^^} | ${PKG})"
            echo "========================================================================"
            echo "  Active Repositories : ${SELECTED_REPOS:-core only}"
            echo "------------------------------------------------------------------------"
            printf "  %-3s %-4s %-15s %-25s %s\n" "#" "Stat" "Application" "From Repository" "Description"
            echo "------------------------------------------------------------------------"

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
                a|all)     _apps_apply_preset "all" ;;
                n|none)    _apps_apply_preset "none" ;;
                clear)     _apps_apply_preset "clear" ;;
                d|default) _apps_apply_preset "default" ;;
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
                            _apps_toggle_idx "$((token - 1))"
                        else
                            echo "  -> Ignored invalid option: '$token'"
                        fi
                    done
                    ;;
            esac
        done
    fi

    _finalize_selected_apps "${state[@]}"

    _APPS_CUSTOMIZED=1
    APPS_MENU_DONE=1
    export APPS_MENU_DONE

    if [ "${_TUI_DEPTH:-0}" -eq 0 ]; then
        echo -e "\n==> Selected Preset Apps : ${SELECTED_APPS:-none}"
        if [ -n "$EXTRA_NATIVE_PKGS" ]; then
            echo "==> Extra Native/AUR     : $EXTRA_NATIVE_PKGS"
        fi
        if [ -n "$EXTRA_FLATPAK_PKGS" ]; then
            echo "==> Extra Flatpak        : $EXTRA_FLATPAK_PKGS"
        fi
    fi
}
