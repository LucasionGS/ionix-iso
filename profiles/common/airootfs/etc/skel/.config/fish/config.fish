# Ionix Fish Configuration

# Initialize oh-my-posh. theme.omp.json is the active Ionix theme's prompt,
# linked by ionixtheme; ionix.omp.json is the stock one, and the place to start
# a prompt of your own (point this at it to keep it across theme switches).
if type -q oh-my-posh
    set -l prompt ~/.config/ionix/ionix.omp.json
    test -e ~/.config/ionix/theme.omp.json; and set prompt ~/.config/ionix/theme.omp.json
    oh-my-posh init fish --config $prompt | source
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