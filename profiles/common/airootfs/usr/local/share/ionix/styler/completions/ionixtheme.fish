# fish completion for ionixtheme
# Drop this file into ~/.config/fish/completions/ionixtheme.fish to enable
# completions automatically (fish loads it on demand, out of the box).

# Disable file completion for ionixtheme.
complete -c ionixtheme -f

# Complete theme names and options only for the first argument.
complete -c ionixtheme -n __fish_is_first_arg -a '(ionixtheme --list 2>/dev/null)' -d Theme
complete -c ionixtheme -n __fish_is_first_arg -l list    -d 'List available themes'
complete -c ionixtheme -n __fish_is_first_arg -l current -d 'Show the current theme'
complete -c ionixtheme -n __fish_is_first_arg -s h -l help -d 'Show this help message'
