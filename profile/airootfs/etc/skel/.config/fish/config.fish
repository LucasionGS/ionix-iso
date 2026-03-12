# Ionix Fish Configuration

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
alias ll='ls -la'
alias vim='nvim'
alias update='sudo pacman -Syu'

zoxide init fish | source
alias cd='z'

# Custom greeting
function fish_greeting
    echo ""
    echo "  Welcome to Ionix"
    echo ""
end

# Environment
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx TERMINAL kitty
set -gx BROWSER google-chrome-stable
