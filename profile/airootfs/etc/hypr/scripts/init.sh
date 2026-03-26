# Lock screen if not in live environment
[[ ! -d /run/archiso ]] && hyprlock -c /etc/hypr/hyprlock.conf
# Start awww-daemon, and set wallpaper on first login
sleep 1 && [ ! -d ~/.cache/awww ] && awww img /usr/local/share/ionix/wallpaper.png