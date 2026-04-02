# Ionix Fish Configuration

set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/keyring/ssh"
# Auto-start Hyprland via UWSM on TTY1
if status is-login; and test (tty) = /dev/tty1
    # exec uwsm start -- Hyprland
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