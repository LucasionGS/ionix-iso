# Ionix Fish Configuration

# Initialize oh-my-posh with the blueish theme
if type -q oh-my-posh
    oh-my-posh init fish --config /usr/share/oh-my-posh/themes/blueish.omp.json | source
end

# Aliases
alias ls='ls --color=auto'
alias ll='ls -la'
alias vim='nvim'
alias update='sudo pacman -Syu'

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
