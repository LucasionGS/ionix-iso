# Ionix theme for fish: syntax colours, the completion pager, fzf, and the
# Linux console's palette. ionixtheme links this file into
# ~/.config/fish/conf.d/ionix-theme.fish; a theme switch replaces the link and
# shells started after it pick the new one up. conf.d runs before config.fish,
# so anything set there wins over this.

status is-interactive; or return

# Syntax highlighting
set -g fish_color_normal {{textBright.raw}}
set -g fish_color_command {{accentLight.raw}}
set -g fish_color_keyword {{accentBright.raw}}
set -g fish_color_param {{text.raw}}
set -g fish_color_option {{text.raw}}
set -g fish_color_quote {{green.raw}}
set -g fish_color_redirection {{cyan.raw}}
set -g fish_color_end {{accent.raw}}
set -g fish_color_operator {{cyan.raw}}
set -g fish_color_escape {{orange.raw}}
set -g fish_color_error {{red.raw}}
set -g fish_color_comment {{muted.raw}}
set -g fish_color_autosuggestion {{muted.raw}}
set -g fish_color_valid_path --underline
set -g fish_color_cancel {{red.raw}}
set -g fish_color_selection --background={{hover.raw}}
set -g fish_color_search_match --background={{hover.raw}}
set -g fish_color_history_current --bold

# Prompt pieces (fish's own prompt; oh-my-posh draws its own)
set -g fish_color_cwd {{accentLight.raw}}
set -g fish_color_cwd_root {{red.raw}}
set -g fish_color_user {{accentBright.raw}}
set -g fish_color_host {{text.raw}}
set -g fish_color_host_remote {{orange.raw}}

# Completion pager
set -g fish_pager_color_prefix {{accentLight.raw}} --bold
set -g fish_pager_color_completion {{text.raw}}
set -g fish_pager_color_description {{muted.raw}}
set -g fish_pager_color_progress {{bgDeep.raw}} --background={{accent.raw}}
set -g fish_pager_color_selected_background --background={{hover.raw}}

# fzf, and everything built on it. bg:-1 keeps the terminal's background.
set -gx FZF_DEFAULT_OPTS "--color=fg:{{text}},bg:-1,hl:{{accentLight}},fg+:{{textBright}},bg+:{{hover}},hl+:{{accentLight}},info:{{muted}},prompt:{{accent}},pointer:{{accentBright}},marker:{{green}},spinner:{{accentBright}},header:{{cyan}},border:{{border}}"

# The Linux console (a plain getty: the desktop's spare VTs, or the server's
# fallback when kmscon cannot start) has a 16-colour palette of its own, set
# per VT with OSC P: slot in hex, then RRGGBB. Existing cells keep their old
# background, so a login clears the screen once to repaint it.
if test "$TERM" = linux
    printf '\e]P0{{ansi0.raw}}\e]P1{{ansi1.raw}}\e]P2{{ansi2.raw}}\e]P3{{ansi3.raw}}'
    printf '\e]P4{{ansi4.raw}}\e]P5{{ansi5.raw}}\e]P6{{ansi6.raw}}\e]P7{{ansi7.raw}}'
    printf '\e]P8{{ansi8.raw}}\e]P9{{ansi9.raw}}\e]PA{{ansi10.raw}}\e]PB{{ansi11.raw}}'
    printf '\e]PC{{ansi12.raw}}\e]PD{{ansi13.raw}}\e]PE{{ansi14.raw}}\e]PF{{ansi15.raw}}'
    status is-login; and clear
end
