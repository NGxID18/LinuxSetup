#!/usr/bin/env bash

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
                gsub(/(^|\n)[[:space:]]*#[^\n]*/, "")
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
