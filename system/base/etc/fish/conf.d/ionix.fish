# Ionix system-wide fish configuration

# Add useful paths
if not contains /usr/local/bin $PATH
    set -gx PATH /usr/local/bin $PATH
end

if not contains /usr/share/ionix/bin $PATH
    set -gx PATH /usr/share/ionix/bin $PATH
end

if not contains /usr/share/ionix/styler/bin $PATH
    set -gx PATH /usr/share/ionix/styler/bin $PATH
end

# Disable default fish greeting system-wide (users set their own in config.fish)
set -g fish_greeting ""

# Per-user steps of Ionix upgrades (see ionix-migrate). Once per login, and
# cheap when nothing is pending.
if status is-login; and command -q ionix-migrate; and test (id -u) -ne 0
    ionix-migrate user --quiet
end
