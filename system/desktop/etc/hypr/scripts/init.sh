# Lock screen if not in live environment. Backgrounded, unlike the hyprlock
# call this replaced, so the wallpaper below is set behind the lock rather than
# after it — ionix-lock shows the Ionix default until awww answers.
# The session is reached by tty autologin, so this lock is the password prompt;
# ionix-post-install drops skip-session-lock when "Log in automatically" was
# ticked in the installer.
[[ ! -d /run/archiso && ! -e /etc/ionix/skip-session-lock ]] && IONIX_LOCK_SILENT=1 ionix-lock &
# Set the wallpaper on first login. hyprland.lua starts awww-daemon alongside
# this script, so wait until it answers rather than for a fixed time: under
# software rendering (a VM, no GPU driver yet) it takes longer than a second,
# and an `awww img` sent before then fails silently and leaves a black screen.
for _ in {1..40}; do awww query &>/dev/null && break; sleep 0.25; done
! find ~/.cache/awww -type f -print -quit 2>/dev/null | grep -q . && awww img /usr/share/ionix/wallpaper.png
# Re-derive wallpaper colours if the active theme uses them. Unconditional, not
# gated on the first-login test above: the wallpaper may have changed from
# another session, and nothing persists the generated files across a reinstall.
# Backgrounded because a session start should never wait on it.
/usr/share/ionix/bin/ionix-adaptive-colors --quiet &

# Per-user steps of Ionix upgrades. The greeter starts the session without a
# login shell, so the one in fish's ionix.fish does not cover it.
ionix-migrate user --quiet &

# Leave the login greeter a copy of this user's theme and wallpaper (once awww is
# up). A no-op where the greeter is not installed.
( sleep 4; ionix-greeter-sync --quiet ) >/dev/null 2>&1 &
