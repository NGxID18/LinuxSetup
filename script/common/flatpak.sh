#!/usr/bin/env bash

init_flatpak_apps() {
    if repo_enabled "flathub"; then
        register_app "steam"         "flathub" "Steam gaming platform (com.valvesoftware.Steam)" 1
        register_app "discord"       "flathub" "Discord voice & text chat (com.discordapp.Discord)" 1
        register_app "librewolf"     "flathub" "LibreWolf privacy-focused browser (io.gitlab.librewolf-community)" 1
        register_app "prismlauncher" "flathub" "Prism Launcher for Minecraft (org.prismlauncher.PrismLauncher)" 1
        register_app "zapzap"        "flathub" "ZapZap WhatsApp desktop client (com.rtosta.zapzap)" 1
        register_app "obs-studio"    "flathub" "OBS Studio recording & streaming (com.obsproject.Studio)" 1
    fi
}

setup_flathub_remote() {
    if repo_enabled "flathub" && command -v flatpak >/dev/null 2>&1; then
        echo "==> Adding Flathub stable remote..."
        sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
    fi
}

search_flatpak_packages() {
    if ! repo_enabled "flathub"; then
        echo "  -> Flathub repository was not selected in Repository Menu."
        return 0
    fi

    local query
    query="$(trim_whitespace "${1:-}")"
    SEARCH_PKGS=()
    SEARCH_DESCS=()

    if [ -z "$query" ]; then
        echo "  -> Please provide a search keyword (e.g. 'sf gimp')."
        return 0
    fi

    echo "==> Searching Flathub online for '$query'..."

    if command -v curl >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
        while IFS=$'\t' read -r app_id app_desc; do
            [ -n "$app_id" ] || continue
            SEARCH_PKGS+=("$app_id")
            SEARCH_DESCS+=("${app_desc:0:60}")
        done < <(SEARCH_Q="$query" python3 - <<'PYEOF' 2>/dev/null || true
import json, os, urllib.request

q = os.environ.get("SEARCH_Q", "")
payload = json.dumps({"query": q, "hits_per_page": 15}).encode("utf-8")
req = urllib.request.Request(
    "https://flathub.org/api/v2/search",
    data=payload,
    headers={"Content-Type": "application/json", "User-Agent": "LinuxSetup/1.0"},
    method="POST",
)
try:
    with urllib.request.urlopen(req, timeout=6) as r:
        data = json.loads(r.read().decode("utf-8", "ignore"))
    for hit in data.get("hits", [])[:15]:
        app_id = hit.get("app_id", "")
        name = hit.get("name", "")
        summary = hit.get("summary", "") or ""
        if app_id:
            print(f"{app_id}\t{name}: {summary}")
except Exception:
    pass
PYEOF
)
    fi

    if [ "${#SEARCH_PKGS[@]}" -eq 0 ] && command -v flatpak >/dev/null 2>&1; then
        while IFS=$'\t' read -r app_id app_name app_desc; do
            [ -n "$app_id" ] || continue
            SEARCH_PKGS+=("$app_id")
            SEARCH_DESCS+=("${app_name}: ${app_desc:0:45}")
        done < <(flatpak search --columns=application,name,description "$query" 2>/dev/null | head -n 15 || true)
    fi

    prompt_pick_search_results "flatpak"
}

install_selected_flatpaks() {
    if ! repo_enabled "flathub"; then
        return 0
    fi

    local -a flatpak_queue=()
    app_enabled "steam"         && flatpak_queue+=("com.valvesoftware.Steam") || true
    app_enabled "discord"       && flatpak_queue+=("com.discordapp.Discord") || true
    app_enabled "librewolf"     && flatpak_queue+=("io.gitlab.librewolf-community") || true
    app_enabled "prismlauncher" && flatpak_queue+=("org.prismlauncher.PrismLauncher") || true
    app_enabled "zapzap"        && flatpak_queue+=("com.rtosta.zapzap") || true
    app_enabled "obs-studio"    && flatpak_queue+=("com.obsproject.Studio") || true

    if app_enabled "flatseal" \
        && ! command -v flatseal >/dev/null 2>&1 \
        && ! rpm -q flatseal >/dev/null 2>&1 \
        && ! dpkg -s flatseal >/dev/null 2>&1 \
        && ! pacman -Qq flatseal >/dev/null 2>&1; then
        flatpak_queue+=("com.github.tchx84.Flatseal")
    fi

    if [ -n "${EXTRA_FLATPAK_PKGS:-}" ]; then
        local fp
        for fp in $EXTRA_FLATPAK_PKGS; do
            flatpak_queue+=("$fp")
        done
    fi

    [ "${#flatpak_queue[@]}" -gt 0 ] || return 0

    if ! command -v flatpak >/dev/null 2>&1; then
        echo "==> Installing Flatpak runtime..."
        install_pkg_list_with_fallback "$PKG" flatpak
    fi

    setup_flathub_remote

    echo "==> Installing selected Flatpak apps..."
    local app
    for app in "${flatpak_queue[@]}"; do
        echo "  -> Installing Flatpak: $app..."
        sudo flatpak install -y --noninteractive flathub "$app" 2>/dev/null || true
    done
}

verify_selected_flatpaks() {
    if ! repo_enabled "flathub"; then
        return 0
    fi

    if [ "${APPS_MENU_DONE:-0}" != "1" ]; then
        register_expected_flatpak \
            com.valvesoftware.Steam \
            com.discordapp.Discord \
            io.gitlab.librewolf-community \
            org.prismlauncher.PrismLauncher \
            com.rtosta.zapzap \
            com.obsproject.Studio
        return 0
    fi

    if app_enabled "steam";         then register_expected_flatpak "com.valvesoftware.Steam"; fi
    if app_enabled "discord";       then register_expected_flatpak "com.discordapp.Discord"; fi
    if app_enabled "librewolf";     then register_expected_flatpak "io.gitlab.librewolf-community"; fi
    if app_enabled "prismlauncher"; then register_expected_flatpak "org.prismlauncher.PrismLauncher"; fi
    if app_enabled "zapzap";        then register_expected_flatpak "com.rtosta.zapzap"; fi
    if app_enabled "obs-studio";    then register_expected_flatpak "com.obsproject.Studio"; fi

    if [ -n "${EXTRA_FLATPAK_PKGS:-}" ]; then
        local extra_fp
        for extra_fp in $EXTRA_FLATPAK_PKGS; do
            register_expected_flatpak "$extra_fp"
        done
    fi
}

verify_extra_and_flatpak_apps() {
    if [ -n "${EXTRA_NATIVE_PKGS:-}" ]; then
        local extra_pkg
        for extra_pkg in $EXTRA_NATIVE_PKGS; do
            register_expected_native "$extra_pkg"
        done
    fi
    verify_selected_flatpaks
}
