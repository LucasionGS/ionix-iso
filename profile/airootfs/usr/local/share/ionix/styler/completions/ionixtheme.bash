# bash completion for ionixtheme
# Source this file or drop it into a bash-completion directory
# (e.g. /usr/share/bash-completion/completions/ionixtheme).

_settheme() {
    local cur
    cur="${COMP_WORDS[COMP_CWORD]}"

    # Only complete the first positional argument.
    if [[ $COMP_CWORD -ne 1 ]]; then
        return 0
    fi

    local options="--list --current --help -h"
    local themes
    themes="$(ionixtheme --list 2>/dev/null)"

    COMPREPLY=($(compgen -W "${themes} ${options}" -- "${cur}"))
}

complete -F _settheme ionixtheme
