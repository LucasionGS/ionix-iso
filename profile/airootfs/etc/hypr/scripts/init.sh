# Lock screen if not in live environment
[[ ! -d /run/archiso ]] && hyprlock -c /etc/hypr/hyprlock.conf
# Start awww-daemon, and set wallpaper on first login
sleep 1 && ! find ~/.cache/awww -type f -print -quit 2>/dev/null | grep -q . && awww img /usr/local/share/ionix/wallpaper.png