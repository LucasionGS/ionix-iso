# Ionix theme for fish: syntax colours, the completion pager, fzf, and the
# Linux console's palette. ionixtheme links this file into
# ~/.config/fish/conf.d/ionix-theme.fish; a theme switch replaces the link and
# shells started after it pick the new one up. conf.d runs before config.fish,
# so anything set there wins over this.

status is-interactive; or return

# Syntax highlighting
set -g fish_color_normal e2d9f3
set -g fish_color_command c084fc
set -g fish_color_keyword a855f7
set -g fish_color_param c4b5fd
set -g fish_color_option c4b5fd
set -g fish_color_quote 2ecc71
set -g fish_color_redirection 48dbfb
set -g fish_color_end 9b59b6
set -g fish_color_operator 48dbfb
set -g fish_color_escape f39c12
set -g fish_color_error e74c3c
set -g fish_color_comment 6b5f80
set -g fish_color_autosuggestion 6b5f80
set -g fish_color_valid_path --underline
set -g fish_color_cancel e74c3c
set -g fish_color_selection --background=3a2d50
set -g fish_color_search_match --background=3a2d50
set -g fish_color_history_current --bold

# Prompt pieces (fish's own prompt; oh-my-posh draws its own)
set -g fish_color_cwd c084fc
set -g fish_color_cwd_root e74c3c
set -g fish_color_user a855f7
set -g fish_color_host c4b5fd
set -g fish_color_host_remote f39c12

# Completion pager
set -g fish_pager_color_prefix c084fc --bold
set -g fish_pager_color_completion c4b5fd
set -g fish_pager_color_description 6b5f80
set -g fish_pager_color_progress 0f0a18 --background=9b59b6
set -g fish_pager_color_selected_background --background=3a2d50

# fzf, and everything built on it. bg:-1 keeps the terminal's background.
set -gx FZF_DEFAULT_OPTS "--color=fg:#c4b5fd,bg:-1,hl:#c084fc,fg+:#e2d9f3,bg+:#3a2d50,hl+:#c084fc,info:#6b5f80,prompt:#9b59b6,pointer:#a855f7,marker:#2ecc71,spinner:#a855f7,header:#48dbfb,border:#4a3d60"

# The Linux console (a plain getty: the desktop's spare VTs, or the server's
# fallback when kmscon cannot start) has a 16-colour palette of its own, set
# per VT with OSC P: slot in hex, then RRGGBB. Existing cells keep their old
# background, so a login clears the screen once to repaint it.
if test "$TERM" = linux
    printf '\e]P01a1025\e]P1e74c3c\e]P22ecc71\e]P3f39c12'
    printf '\e]P47c3aed\e]P59b59b6\e]P61abc9c\e]P7c4b5fd'
    printf '\e]P82d2d3f\e]P9ff6b6b\e]PA55efc4\e]PBfeca57'
    printf '\e]PCa855f7\e]PDc084fc\e]PE48dbfb\e]PFe2d9f3'
    status is-login; and clear
end
