# Lock screen if not in live environment. Backgrounded, unlike the hyprlock
# call this replaced, so the wallpaper below is set behind the lock rather than
# after it — ionix-lock shows the Ionix default until awww answers.
# The session is reached by tty autologin, so this lock is the password prompt;
# ionix-post-install drops skip-session-lock when "Log in automatically" was
# ticked in the installer.
[[ ! -d /run/archiso && ! -e /etc/ionix/skip-session-lock ]] && ionix-lock &
# Start awww-daemon, and set wallpaper on first login
sleep 1 && ! find ~/.cache/awww -type f -print -quit 2>/dev/null | grep -q . && awww img /usr/local/share/ionix/wallpaper.png
# Re-derive wallpaper colours if the active theme uses them. Unconditional, not
# gated on the first-login test above: the wallpaper may have changed from
# another session, and nothing persists the generated files across a reinstall.
# Backgrounded because a session start should never wait on it.
/usr/local/share/ionix/bin/ionix-adaptive-colors --quiet &

# Leave the login greeter a copy of this user's theme and wallpaper (once awww is
# up). A no-op where the greeter is not installed.
( sleep 4; ionix-greeter-sync --quiet ) >/dev/null 2>&1 &
