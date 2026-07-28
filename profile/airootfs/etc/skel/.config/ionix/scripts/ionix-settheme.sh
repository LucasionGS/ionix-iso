#!/usr/bin/env bash
# ionix-settheme — Switch Ionix desktop theme
# Usage: ionix-settheme <theme-name>
#        ionix-settheme --list
#        ionix-settheme --current

set -euo pipefail

THEME_BASE_DIR="$HOME/.config"
CURRENT_THEME_FILE="$HOME/.config/ionix/current-theme"

# ── Helpers ─────────────────────────────────────────────────

msg()  { printf '\033[1;35m[ionix]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[ionix]\033[0m %s\n' "$*" >&2; }
ok()   { printf '\033[1;32m[ionix]\033[0m %s\n' "$*"; }

usage() {
    cat <<EOF
Usage: ionix-settheme <theme-name>
       ionix-settheme --list
       ionix-settheme --current

Switch the active Ionix desktop theme.

Options:
  --list      List available themes
  --current   Show the current theme
  -h, --help  Show this help message
EOF
}

# Return the list of available theme names by scanning theme directories.
# A theme is considered available if it exists in at least one section.
list_themes() {
    local -A themes=()
    for section_func in $(declare -F | awk '{print $3}' | grep '^apply_'); do
        local section="${section_func#apply_}"
        local dir
        dir="$(get_theme_dir "$section")"
        if [[ -d "$dir" ]]; then
            for d in "$dir"/*/; do
                [[ -d "$d" ]] || continue
                themes["$(basename "$d")"]=1
            done
        fi
    done
    printf '%s\n' "${!themes[@]}" | sort
}

get_current_theme() {
    if [[ -f "$CURRENT_THEME_FILE" ]]; then
        cat "$CURRENT_THEME_FILE"
    else
        echo "ionix"
    fi
}

save_current_theme() {
    mkdir -p "$(dirname "$CURRENT_THEME_FILE")"
    printf '%s\n' "$1" > "$CURRENT_THEME_FILE"
}

# ── Section: waybar ─────────────────────────────────────────
# Theme dir: ~/.config/waybar/themes/<theme>/
# Symlinks:  ~/.config/waybar/config  -> themes/<theme>/config
#            ~/.config/waybar/style.css -> themes/<theme>/style.css

get_theme_dir_waybar() { echo "$THEME_BASE_DIR/waybar/themes"; }

apply_waybar() {
    local theme="$1"
    local theme_dir="$THEME_BASE_DIR/waybar/themes/$theme"
    local target_dir="$THEME_BASE_DIR/waybar"

    if [[ ! -d "$theme_dir" ]]; then
        msg "waybar: no theme '$theme' found, skipping"
        return 0
    fi

    local files=("config" "style.css")
    for file in "${files[@]}"; do
        local src="$theme_dir/$file"
        local dst="$target_dir/$file"

        if [[ ! -f "$src" ]]; then
            msg "waybar: theme '$theme' missing $file, skipping"
            continue
        fi

        # Remove existing file/symlink
        rm -f "$dst"
        ln -s "themes/$theme/$file" "$dst"
    done

    ok "waybar: applied theme '$theme'"
}

# ── Section: quickshell (ionix-quickshell) ──────────────────
# Theme dir: ~/.config/quickshell/ionix/themes/<theme>/theme.json
# Symlink:   ~/.config/quickshell/ionix/theme.json -> themes/<theme>/theme.json
#
# The shell watches theme.json and restyles live, so no reload is needed. It is a
# separate file from the user's own config.json so switching themes never
# overwrites personal tweaks — config.json wins over theme.json.

get_theme_dir_quickshell() { echo "$THEME_BASE_DIR/quickshell/ionix/themes"; }

apply_quickshell() {
    local theme="$1"
    local theme_dir="$THEME_BASE_DIR/quickshell/ionix/themes/$theme"
    local target_dir="$THEME_BASE_DIR/quickshell/ionix"
    local src="$theme_dir/theme.json"
    local dst="$target_dir/theme.json"

    if [[ ! -f "$src" ]]; then
        msg "quickshell: no theme '$theme' found, skipping"
        return 0
    fi

    mkdir -p "$target_dir"
    rm -f "$dst"
    ln -s "themes/$theme/theme.json" "$dst"

    ok "quickshell: applied theme '$theme'"
}

# ── Section helpers ─────────────────────────────────────────
# get_theme_dir returns the themes directory for a given section name.
get_theme_dir() {
    local section="$1"
    local func="get_theme_dir_${section}"
    if declare -F "$func" &>/dev/null; then
        "$func"
    fi
}

# Collect all apply_ functions as the list of sections.
get_sections() {
    declare -F | awk '{print $3}' | grep '^apply_' | sed 's/^apply_//' | sort
}

# ── Reload running services after theme switch ─────────────

reload_services() {
    # Waybar
    if pgrep -x waybar &>/dev/null; then
        killall -SIGUSR2 waybar 2>/dev/null && msg "waybar: reloaded" || true
    fi

    # ionix-quickshell. It already watches theme.json and restyles itself, so this
    # is belt-and-braces for the case where the file was replaced rather than
    # written in place and the watch didn't fire.
    if command -v qs &>/dev/null; then
        qs -c ionix ipc call theme reload &>/dev/null && msg "quickshell: reloaded" || true
    fi
}

# ── Main ────────────────────────────────────────────────────

main() {
    if [[ $# -lt 1 ]]; then
        usage
        exit 1
    fi

    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --list)
            list_themes
            exit 0
            ;;
        --current)
            get_current_theme
            exit 0
            ;;
        -*)
            err "Unknown option: $1"
            usage
            exit 1
            ;;
    esac

    local theme="$1"

    msg "Switching to theme: $theme"

    local sections
    sections="$(get_sections)"

    local any_applied=false
    for section in $sections; do
        "apply_${section}" "$theme" && any_applied=true
    done

    if [[ "$any_applied" == false ]]; then
        err "No sections found theme '$theme'"
        exit 1
    fi

    save_current_theme "$theme"
    reload_services

    ok "Theme switched to '$theme'"
}

main "$@"
