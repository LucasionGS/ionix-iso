#!/usr/bin/env bash
# Waybar exec script for the Toxen music player integration.
# Outputs a JSON object consumed by waybar's custom module return-type: json.
# Classes: playing | paused | inactive

# Waybar is started by the compositor / systemd and may not inherit
# XDG_RUNTIME_DIR.  Derive it the standard way (systemd uses /run/user/$UID).
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

status=$(toxen-mini -s status 2>/dev/null)

if [ -z "$status" ]; then
    printf '{"text":"󰝚","class":"inactive","tooltip":"Toxen not running"}\n'
    exit 0
fi

artist=$(toxen-mini -s artist 2>/dev/null)
title=$(toxen-mini -s title 2>/dev/null)

[ "$status" = "playing" ] && icon="󰎆" || icon="󰏤"

# Minimal JSON escaping: backslash then double-quote.
esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

printf '{"text":"%s  %s","tooltip":"%s","class":"%s"}\n' \
    "$icon" "$(esc "${artist:-Unknown}")" "$(esc "${title:-}")" "$status"
