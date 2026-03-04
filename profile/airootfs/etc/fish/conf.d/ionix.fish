# Ionix system-wide fish configuration

# Add useful paths
if not contains /usr/local/bin $PATH
    set -gx PATH /usr/local/bin $PATH
end

# Disable default fish greeting system-wide (users set their own in config.fish)
set -g fish_greeting ""
