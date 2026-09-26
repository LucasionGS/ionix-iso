# Lock screen if not in live environment. Backgrounded, unlike the hyprlock
# call this replaced, so the wallpaper below is set behind the lock rather than
# after it — ionix-lock shows the Ionix default until awww answers.
[[ ! -d /run/archiso ]] && ionix-lock &
# Start awww-daemon, and set wallpaper on first login
sleep 1 && ! find ~/.cache/awww -type f -print -quit 2>/dev/null | grep -q . && awww img /usr/local/share/ionix/wallpaper.png
# Re-derive wallpaper colours if the active theme uses them. Unconditional, not
# gated on the first-login test above: the wallpaper may have changed from
# another session, and nothing persists the generated files across a reinstall.
# Backgrounded because a session start should never wait on it.
/usr/local/share/ionix/bin/ionix-adaptive-colors --quiet &