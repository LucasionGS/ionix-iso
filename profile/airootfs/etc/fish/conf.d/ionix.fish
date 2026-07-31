# Ionix system-wide fish configuration

# Add useful paths
if not contains /usr/local/bin $PATH
    set -gx PATH /usr/local/bin $PATH
end

if not contains /usr/local/share/ionix/bin $PATH
    set -gx PATH /usr/local/share/ionix/bin $PATH
end

if not contains /usr/local/share/ionix/styler/bin $PATH
    set -gx PATH /usr/local/share/ionix/styler/bin $PATH
end

# Disable default fish greeting system-wide (users set their own in config.fish)
set -g fish_greeting ""
