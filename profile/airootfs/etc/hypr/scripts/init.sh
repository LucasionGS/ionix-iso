# Lock screen if not in live environment
[[ ! -d /run/archiso ]] && hyprlock -c /etc/hypr/hyprlock.conf
# Start awww-daemon, and set wallpaper on first login
sleep 1 && ! find ~/.cache/awww -type f -print -quit 2>/dev/null | grep -q . && awww img /usr/local/share/ionix/wallpaper.png
# Re-derive wallpaper colours if the active theme uses them. Unconditional, not
# gated on the first-login test above: the wallpaper may have changed from
# another session, and nothing persists the generated files across a reinstall.
# Backgrounded because a session start should never wait on it.
/usr/local/share/ionix/bin/ionix-adaptive-colors --quiet &