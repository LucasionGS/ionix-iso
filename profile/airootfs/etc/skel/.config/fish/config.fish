# Ionix Fish Configuration

set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/keyring/ssh"
# Auto-start desktop session via UWSM on TTY1
if status is-login; and test (tty) = /dev/tty1
    # Read session from kernel cmdline (set by GRUB: ionix.desktop=hyprland|gnome)
    set session (string match -r 'ionix\.desktop=(\S+)' < /proc/cmdline | tail -1)

    if test -z "$session"
        set session hyprland
    end

    switch $session
        case gnome
            set -gx XDG_SESSION_TYPE wayland
            set -gx XDG_CURRENT_DESKTOP GNOME
            set -gx XDG_SESSION_DESKTOP gnome
            set -gx GNOME_SHELL_SESSION_MODE gnome
            set -gx MOZ_ENABLE_WAYLAND 1

            set -gx LIBVA_DRIVER_NAME nvidia
            set -gx GBM_BACKEND nvidia-drm
            set -gx __GLX_VENDOR_LIBRARY_NAME nvidia
            set -gx WLR_NO_HARDWARE_CURSORS 1
            
            sudo /usr/bin/systemctl start gdm.service
        case '*'
            uwsm start hyprland-uwsm.desktop
    end
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