# Ionix theme for fish: syntax colours, the completion pager, fzf, and the
# Linux console's palette. ionixtheme links this file into
# ~/.config/fish/conf.d/ionix-theme.fish; a theme switch replaces the link and
# shells started after it pick the new one up. conf.d runs before config.fish,
# so anything set there wins over this.

status is-interactive; or return

# Syntax highlighting
set -g fish_color_normal ffffff
set -g fish_color_command 60cdff
set -g fish_color_keyword 4cc2ff
set -g fish_color_param e0e0e0
set -g fish_color_option e0e0e0
set -g fish_color_quote 6ccb5f
set -g fish_color_redirection 3a96dd
set -g fish_color_end 0078d4
set -g fish_color_operator 3a96dd
set -g fish_color_escape f7630c
set -g fish_color_error e81123
set -g fish_color_comment a0a0a0
set -g fish_color_autosuggestion a0a0a0
set -g fish_color_valid_path --underline
set -g fish_color_cancel e81123
set -g fish_color_selection --background=383838
set -g fish_color_search_match --background=383838
set -g fish_color_history_current --bold

# Prompt pieces (fish's own prompt; oh-my-posh draws its own)
set -g fish_color_cwd 60cdff
set -g fish_color_cwd_root e81123
set -g fish_color_user 4cc2ff
set -g fish_color_host e0e0e0
set -g fish_color_host_remote f7630c

# Completion pager
set -g fish_pager_color_prefix 60cdff --bold
set -g fish_pager_color_completion e0e0e0
set -g fish_pager_color_description a0a0a0
set -g fish_pager_color_progress 1b1b1b --background=0078d4
set -g fish_pager_color_selected_background --background=383838

# fzf, and everything built on it. bg:-1 keeps the terminal's background.
set -gx FZF_DEFAULT_OPTS "--color=fg:#e0e0e0,bg:-1,hl:#60cdff,fg+:#ffffff,bg+:#383838,hl+:#60cdff,info:#a0a0a0,prompt:#0078d4,pointer:#4cc2ff,marker:#6ccb5f,spinner:#4cc2ff,header:#3a96dd,border:#454545"

# The Linux console (a plain getty: the desktop's spare VTs, or the server's
# fallback when kmscon cannot start) has a 16-colour palette of its own, set
# per VT with OSC P: slot in hex, then RRGGBB. Existing cells keep their old
# background, so a login clears the screen once to repaint it.
if test "$TERM" = linux
    printf '\e]P00c0c0c\e]P1c50f1f\e]P213a10e\e]P3c19c00'
    printf '\e]P40037da\e]P5881798\e]P63a96dd\e]P7cccccc'
    printf '\e]P8767676\e]P9e74856\e]PA16c60c\e]PBf9f1a5'
    printf '\e]PC3b78ff\e]PDb4009e\e]PE61d6d6\e]PFf2f2f2'
    status is-login; and clear
end
