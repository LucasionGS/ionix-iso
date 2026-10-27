# Ionix theme for fish: syntax colours, the completion pager, fzf, and the
# Linux console's palette. ionixtheme links this file into
# ~/.config/fish/conf.d/ionix-theme.fish; a theme switch replaces the link and
# shells started after it pick the new one up. conf.d runs before config.fish,
# so anything set there wins over this.

status is-interactive; or return

# Syntax highlighting
set -g fish_color_normal ffffff
set -g fish_color_command ff2bd6
set -g fish_color_keyword 00f0ff
set -g fish_color_param e6d9ff
set -g fish_color_option e6d9ff
set -g fish_color_quote 00ff9f
set -g fish_color_redirection 00f0ff
set -g fish_color_end b026ff
set -g fish_color_operator 00f0ff
set -g fish_color_escape ffb800
set -g fish_color_error ff2b5e
set -g fish_color_comment 8a6bb8
set -g fish_color_autosuggestion 8a6bb8
set -g fish_color_valid_path --underline
set -g fish_color_cancel ff2b5e
set -g fish_color_selection --background=2a1350
set -g fish_color_search_match --background=2a1350
set -g fish_color_history_current --bold

# Prompt pieces (fish's own prompt; oh-my-posh draws its own)
set -g fish_color_cwd ff2bd6
set -g fish_color_cwd_root ff2b5e
set -g fish_color_user 00f0ff
set -g fish_color_host e6d9ff
set -g fish_color_host_remote ffb800

# Completion pager
set -g fish_pager_color_prefix ff2bd6 --bold
set -g fish_pager_color_completion e6d9ff
set -g fish_pager_color_description 8a6bb8
set -g fish_pager_color_progress 070312 --background=b026ff
set -g fish_pager_color_selected_background --background=2a1350

# fzf, and everything built on it. bg:-1 keeps the terminal's background.
set -gx FZF_DEFAULT_OPTS "--color=fg:#e6d9ff,bg:-1,hl:#ff2bd6,fg+:#ffffff,bg+:#2a1350,hl+:#ff2bd6,info:#8a6bb8,prompt:#b026ff,pointer:#00f0ff,marker:#00ff9f,spinner:#00f0ff,header:#00f0ff,border:#7c1fd4"

# The Linux console (a plain getty: the desktop's spare VTs, or the server's
# fallback when kmscon cannot start) has a 16-colour palette of its own, set
# per VT with OSC P: slot in hex, then RRGGBB. Existing cells keep their old
# background, so a login clears the screen once to repaint it.
if test "$TERM" = linux
    printf '\e]P00d0620\e]P1ff2b5e\e]P200ff9f\e]P3ffb800'
    printf '\e]P47c1fd4\e]P5b026ff\e]P600f0ff\e]P7e6d9ff'
    printf '\e]P82a1350\e]P9ff5c85\e]PA5cffc4\e]PBffd45c'
    printf '\e]PCa855f7\e]PDff2bd6\e]PE5cf7ff\e]PFffffff'
    status is-login; and clear
end
