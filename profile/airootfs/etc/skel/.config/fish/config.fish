# Ionix Fish Configuration

set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/keyring/ssh"
# Auto-start the desktop session via UWSM on TTY1: the autologin and locked
# login modes land here (ionix-login-mode); the greeter starts it through greetd.
if status is-login; and test (tty) = /dev/tty1
    uwsm start hyprland-uwsm.desktop
end

# Initialize oh-my-posh with the Ionix theme
if type -q oh-my-posh
    oh-my-posh init fish --config ~/.config/ionix/ionix.omp.json | source
end

# Aliases
alias ls='ls --color=auto'
alias l='lsd'
alias ll='lsd -la'
alias la='lsd -lA'
alias vim='nvim'
alias update='sudo pacman -Syu'

zoxide init fish | source
alias cd='z'

# Custom greeting
function fish_greeting
    # echo ""
    # echo "  Welcome to Ionix"
    # echo ""
end

set -gx PATH "$HOME/.local/bin:$PATH"

# Environment
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx TERMINAL kitty
set -gx BROWSER google-chrome-stable