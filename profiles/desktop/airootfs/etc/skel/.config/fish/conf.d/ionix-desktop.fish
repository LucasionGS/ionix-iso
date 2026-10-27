# Ionix desktop session. conf.d runs before config.fish, so the session started
# below already has these in its environment.

set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/keyring/ssh"
set -gx TERMINAL ionterm
set -gx BROWSER google-chrome-stable

# Auto-start the desktop session via UWSM on TTY1: the autologin and locked
# login modes land here (ionix-login-mode); the greeter starts it through greetd.
if status is-login; and test (tty) = /dev/tty1
    uwsm start hyprland-uwsm.desktop
end
