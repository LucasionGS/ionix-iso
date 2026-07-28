-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Ionix - System Hyprland Configuration                       ║
-- ║  /etc/hypr/hyprland.lua                                      ║
-- ║                                                              ║
-- ║  User overrides: ~/.config/hypr/hyprland.lua                 ║
-- ║  This file provides sensible defaults. Users source this     ║
-- ║  file and add overrides in their own config.                 ║
-- ╚══════════════════════════════════════════════════════════════╝


-- ── Monitors ──────────────────────────────────────────────────
-- Auto-detect and use preferred resolution
hl.monitor({
  output = "",
  mode = "preferred",
  position = "auto",
  scale = "1",
})

-- ── Input ─────────────────────────────────────────────────────
hl.config({
  input = {
    kb_layout = "dk",
    follow_mouse = 1,
    sensitivity = 0,

    touchpad = {
      natural_scroll = true,
      tap_to_click = true,
      disable_while_typing = true,
    },
  },

  binds = {
    scroll_event_delay = 10,
  },
})


-- ── Gestures ──────────────────────────────────────────────────
hl.gesture({ fingers = 2, direction = "pinch", action = "resize" })
hl.gesture({ fingers = 4, direction = "down", action = "close" })
-- ── General ───────────────────────────────────────────────────
hl.config({
  general = {
    gaps_in = 2,
    gaps_out = 2,
    border_size = 2,
    col = {
      active_border = { colors = { "rgb(9b59b6)", "rgb(7c3aed)" }, angle = 45 },
      inactive_border = { colors = { "rgb(2d2d3f)" } },
    },
    layout = "dwindle",
    allow_tearing = true,
  },

  decoration = {
    rounding = 12,

    blur = {
      enabled = true,
      size = 6,
      passes = 2,
      new_optimizations = true,
      xray = false,
    },

    shadow = {
      enabled = true,
      range = 15,
      render_power = 3,
      color = "rgba(1a1a2e88)",
    },
  },

  animations = {
    enabled = true,
  },
})

hl.curve("ionixSmooth", { type = "bezier", points = { { 0.25, 0.1 }, { 0.25, 1.0 } } })
hl.curve("ionixSnap", { type = "bezier", points = { { 0.4, 0.0 }, { 0.2, 1.0 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "ionixSmooth", style = "slide" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 5, bezier = "ionixSmooth", style = "popin 80%" })
hl.animation({ leaf = "fade", enabled = true, speed = 4, bezier = "ionixSmooth" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "ionixSnap", style = "slidefade 50%" })
hl.animation({ leaf = "layers", enabled = true, speed = 3, bezier = "ionixSmooth", style = "fade" })


-- ── Layouts ───────────────────────────────────────────────────
hl.config({
  dwindle = {
    preserve_split = true,
    smart_split = false,
  },

  master = {
    new_status = "master",
  },
})


-- ── Misc ──────────────────────────────────────────────────────
hl.config({
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    force_default_wallpaper = 0,
    vrr = 1,
  },
})


-- ── Environment ───────────────────────────────────────────────
hl.env("XCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Adwaita")
hl.env("GTK_THEME", "Adwaita:dark")
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("CHROME_EXECUTABLE", "/usr/bin/google-chrome-stable")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")


-- ══════════════════════════════════════════════════════════════
-- ║  Key Bindings                                              ║
-- ══════════════════════════════════════════════════════════════

-- Keep this global so user overrides can reuse the old $mainMod equivalent.
mainMod = "SUPER"

local function bind_exec(keys, command, options)
  hl.bind(keys, hl.dsp.exec_cmd(command), options)
end

local function bind_workspace(keys, workspace)
  hl.bind(keys, hl.dsp.focus({ workspace = workspace }))
end

local function bind_move_to_workspace(keys, workspace, follow)
  hl.bind(keys, hl.dsp.window.move({ workspace = workspace, follow = follow }))
end

local function bind_resize_active(keys, x_delta, y_delta)
  hl.bind(keys, hl.dsp.window.resize({ x = x_delta, y = y_delta, relative = true }), { repeating = true })
end

-- ── Applications ──────────────────────────────────────────────
bind_exec(mainMod .. " + T", "kitty")
bind_exec("CTRL + ALT + T", "tabby")
bind_exec(mainMod .. " + W", "google-chrome-stable")
bind_exec(mainMod .. " + E", "ioexplorer")
bind_exec(mainMod .. " + B", "kitty btop")
bind_exec(mainMod .. " + SUPER_L", "ioexplorer-start --top --center")
bind_exec("ALT + Space", "ioexplorer-spotlight")
bind_exec(mainMod .. " + R", "ags request -i ionix-shell \"command-palette\"")
bind_exec(mainMod .. " + V", "copyq toggle")
bind_exec(mainMod .. " + period", "gnome-characters")
bind_exec(mainMod .. " + L", "hyprlock -c /etc/hypr/hyprlock.conf --grace 2")
bind_exec("CTRL + " .. mainMod .. " + R", "hyprctl reload")

-- ── Shell ─────────────────────────────────────────────────────
bind_exec(mainMod .. " + SHIFT + B", "systemctl --user restart ionix-quickshell")
-- Escape hatch: bring up waybar if the Quickshell bar is misbehaving.
bind_exec("CTRL + " .. mainMod .. " + SHIFT + B", "waybar")

-- # ── Notifications ─────────────────────────────────────────────────
-- The notification server is ionix-quickshell itself; swaync is still installed
-- but must not run, because only one process can own org.freedesktop.Notifications.
bind_exec(mainMod .. " + N", "qs -c ionix ipc call notifications toggle")
bind_exec(mainMod .. " + SHIFT + N", "qs -c ionix ipc call notifications dnd")

-- ── Wallpaper ─────────────────────────────────────────────────
bind_exec("CTRL + " .. mainMod .. " + W", "bash ~/.config/ionix/scripts/promptwallpaper.sh")
bind_exec(mainMod .. " + ALT + W", "bash ~/.config/ionix/cron/cycle-wallpaper.sh")

-- ── Window Management ─────────────────────────────────────────
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + Space", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mainMod .. " + D", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind(mainMod .. " + ALT + F", hl.dsp.window.fullscreen_state({ internal = 0, client = 3, action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pin())

-- ── Window Groups ─────────────────────────────────────────────
hl.bind(mainMod .. " + G", hl.dsp.group.toggle())
hl.bind(mainMod .. " + SHIFT + G", hl.dsp.group.lock_active({ action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + mouse_up", hl.dsp.group.next())
hl.bind(mainMod .. " + SHIFT + mouse_down", hl.dsp.group.prev())
hl.bind(mainMod .. " + CTRL + Tab", hl.dsp.group.next())
hl.bind(mainMod .. " + SHIFT + CTRL + Tab", hl.dsp.group.prev())

-- ── Focus ─────────────────────────────────────────────────────
hl.bind(mainMod .. " + Left", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + Right", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + Up", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + Down", hl.dsp.focus({ direction = "d" }))
hl.bind(mainMod .. " + BracketLeft", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + BracketRight", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + U", hl.dsp.focus({ urgent_or_last = true }))

-- ── Move Windows ──────────────────────────────────────────────
hl.bind(mainMod .. " + SHIFT + Left", hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + Right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + Up", hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + Down", hl.dsp.window.move({ direction = "d" }))
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ── Resize Windows ────────────────────────────────────────────
bind_resize_active(mainMod .. " + ALT + Left", -20, 0)
bind_resize_active(mainMod .. " + ALT + Right", 20, 0)
bind_resize_active(mainMod .. " + ALT + Up", 0, -20)
bind_resize_active(mainMod .. " + ALT + Down", 0, 20)
bind_resize_active(mainMod .. " + ALT + SHIFT + Left", -2, 0)
bind_resize_active(mainMod .. " + ALT + SHIFT + Right", 2, 0)
bind_resize_active(mainMod .. " + ALT + SHIFT + Up", 0, -2)
bind_resize_active(mainMod .. " + ALT + SHIFT + Down", 0, 2)

-- ── Workspace Layouts ─────────────────────────────────────────
bind_exec(mainMod .. " + code:90", "ionix-arrange-workspace 0")
bind_exec(mainMod .. " + code:87", "ionix-arrange-workspace 1")
bind_exec(mainMod .. " + code:88", "ionix-arrange-workspace 2")
bind_exec(mainMod .. " + code:89", "ionix-arrange-workspace 3")
bind_exec(mainMod .. " + code:83", "ionix-arrange-workspace 4")
bind_exec(mainMod .. " + code:84", "ionix-arrange-workspace 5")
bind_exec(mainMod .. " + code:85", "ionix-arrange-workspace 6")
bind_exec(mainMod .. " + code:79", "ionix-arrange-workspace 7")
bind_exec(mainMod .. " + code:80", "ionix-arrange-workspace 8")
bind_exec(mainMod .. " + code:81", "ionix-arrange-workspace 9")

-- ── Workspaces ────────────────────────────────────────────────
bind_workspace(mainMod .. " + 1", 1)
bind_workspace(mainMod .. " + 2", 2)
bind_workspace(mainMod .. " + 3", 3)
bind_workspace(mainMod .. " + 4", 4)
bind_workspace(mainMod .. " + 5", 5)
bind_workspace(mainMod .. " + 6", 6)
bind_workspace(mainMod .. " + 7", 7)
bind_workspace(mainMod .. " + 8", 8)
bind_workspace(mainMod .. " + 9", 9)
bind_workspace(mainMod .. " + 0", 10)

bind_workspace("CTRL + " .. mainMod .. " + Right", "r+1")
bind_workspace("CTRL + " .. mainMod .. " + Left", "r-1")
bind_workspace("CTRL + " .. mainMod .. " + ALT + Right", "m+1")
bind_workspace("CTRL + " .. mainMod .. " + ALT + Left", "m-1")
bind_workspace(mainMod .. " + Page_Down", "r-1")
bind_workspace(mainMod .. " + Page_Up", "r+1")
bind_workspace("CTRL + " .. mainMod .. " + Page_Down", "r-5")
bind_workspace("CTRL + " .. mainMod .. " + Page_Up", "r+5")
bind_workspace(mainMod .. " + mouse_up", "r+1")
bind_workspace(mainMod .. " + mouse_down", "r-1")

-- ── Move to Workspace ─────────────────────────────────────────
bind_move_to_workspace(mainMod .. " + ALT + 1", 1, false)
bind_move_to_workspace(mainMod .. " + ALT + 2", 2, false)
bind_move_to_workspace(mainMod .. " + ALT + 3", 3, false)
bind_move_to_workspace(mainMod .. " + ALT + 4", 4, false)
bind_move_to_workspace(mainMod .. " + ALT + 5", 5, false)
bind_move_to_workspace(mainMod .. " + ALT + 6", 6, false)
bind_move_to_workspace(mainMod .. " + ALT + 7", 7, false)
bind_move_to_workspace(mainMod .. " + ALT + 8", 8, false)
bind_move_to_workspace(mainMod .. " + ALT + 9", 9, false)
bind_move_to_workspace(mainMod .. " + ALT + 0", 10, false)

bind_move_to_workspace("CTRL + " .. mainMod .. " + SHIFT + 1", 1, true)
bind_move_to_workspace("CTRL + " .. mainMod .. " + SHIFT + 2", 2, true)
bind_move_to_workspace("CTRL + " .. mainMod .. " + SHIFT + 3", 3, true)
bind_move_to_workspace("CTRL + " .. mainMod .. " + SHIFT + 4", 4, true)
bind_move_to_workspace("CTRL + " .. mainMod .. " + SHIFT + 5", 5, true)
bind_move_to_workspace("CTRL + " .. mainMod .. " + SHIFT + 6", 6, true)
bind_move_to_workspace("CTRL + " .. mainMod .. " + SHIFT + 7", 7, true)
bind_move_to_workspace("CTRL + " .. mainMod .. " + SHIFT + 8", 8, true)
bind_move_to_workspace("CTRL + " .. mainMod .. " + SHIFT + 9", 9, true)
bind_move_to_workspace("CTRL + " .. mainMod .. " + SHIFT + 0", 10, true)

bind_move_to_workspace("CTRL + " .. mainMod .. " + SHIFT + Right", "r+1", true)
bind_move_to_workspace("CTRL + " .. mainMod .. " + SHIFT + Left", "r-1", true)
bind_move_to_workspace(mainMod .. " + SHIFT + Page_Down", "r-1", true)
bind_move_to_workspace(mainMod .. " + SHIFT + Page_Up", "r+1", true)

-- ── Special Workspace ─────────────────────────────────────────
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special(""))
bind_move_to_workspace(mainMod .. " + SHIFT + S", "special", true)

-- ── Overview ──────────────────────────────────────────────────
-- hl.bind(mainMod .. " + Tab", ...)

-- ── Navigation ────────────────────────────────────────────────
hl.bind("ALT + Left", hl.dsp.send_shortcut({ mods = "", key = "XF86Back", window = "activewindow" }))
hl.bind("ALT + Right", hl.dsp.send_shortcut({ mods = "", key = "XF86Forward", window = "activewindow" }))

-- ── Zoom ──────────────────────────────────────────────────────
bind_exec("CTRL + " .. mainMod .. " + mouse_down", [[hyprctl -q keyword cursor:zoom_factor $(hyprctl getoption cursor:zoom_factor -j | jq '.float * 1.1')]])
bind_exec("CTRL + " .. mainMod .. " + mouse_up", [[hyprctl -q keyword cursor:zoom_factor $(hyprctl getoption cursor:zoom_factor -j | jq '(.float * 0.9) | if . < 1 then 1 else . end')]])
bind_exec("CTRL + " .. mainMod .. " + ALT + 0", "hyprctl -q keyword cursor:zoom_factor 1")

-- ── Media Keys ────────────────────────────────────────────────
-- Volume and brightness go through the shell's IPC so the on-screen display gets
-- the exact new value instead of polling for it. Each falls back to the original
-- command with `||`, so the keys still work when the shell isn't running.
bind_exec("XF86AudioRaiseVolume", "qs -c ionix ipc call audio increase || wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 && wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+", { locked = true, repeating = true })
bind_exec("XF86AudioLowerVolume", "qs -c ionix ipc call audio decrease || wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 && wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-", { locked = true, repeating = true })
bind_exec("XF86AudioMute", "qs -c ionix ipc call audio mute || wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
bind_exec("XF86AudioMicMute", "qs -c ionix ipc call audio micMute || wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")
bind_exec("XF86AudioPlay", "playerctl play-pause")
bind_exec("XF86AudioNext", "playerctl next")
bind_exec("XF86AudioPrev", "playerctl previous")
bind_exec("XF86AudioStop", "playerctl stop")
bind_exec("XF86MonBrightnessUp", "qs -c ionix ipc call brightness increase || brightnessctl set '12.75+'", { locked = true, repeating = true })
bind_exec("XF86MonBrightnessDown", "qs -c ionix ipc call brightness decrease || brightnessctl set '12.75-'", { locked = true, repeating = true })

-- ── Screenshot ────────────────────────────────────────────────
bind_exec("Print", "hyprshot -m region --freeze --clipboard-only && paplay /usr/share/sounds/freedesktop/stereo/bell.oga --volume 32768")
bind_exec("CTRL + Print", "hyprshot -m output --freeze --clipboard-only && paplay /usr/share/sounds/freedesktop/stereo/bell.oga --volume 32768")
bind_exec(mainMod .. " + Print", [[hyprshot -m region --freeze -o ~/Pictures -f "screenshot-$(date +%Y%m%d-%H%M%S).png" && paplay /usr/share/sounds/freedesktop/stereo/bell.oga --volume 32768]])
bind_exec("CTRL + " .. mainMod .. " + Print", "grim /tmp/fullscreen_screenshot.png && cat /tmp/fullscreen_screenshot.png | wl-copy && rm /tmp/fullscreen_screenshot.png && paplay /usr/share/sounds/freedesktop/stereo/bell.oga --volume 32768")


-- ══════════════════════════════════════════════════════════════
-- ║  Window Rules                                              ║
-- ══════════════════════════════════════════════════════════════

-- Center all floating windows
hl.window_rule({ match = { float = true }, center = true })

-- Picture in Picture
hl.window_rule({ match = { title = "(Picture in picture)" }, float = true })
hl.window_rule({ match = { title = "(Picture in picture)" }, pin = true })

-- Kitty transparency
hl.window_rule({ match = { class = "kitty" }, opacity = "0.8" })
hl.window_rule({ match = { class = "kitty", focus = true }, opacity = "0.9" })

-- System dialogs
hl.window_rule({ match = { class = "blueman-manager" }, float = true })
hl.window_rule({ match = { class = "blueman-manager" }, center = true })
hl.window_rule({ match = { class = "blueman-manager" }, size = { 800, 500 } })
hl.window_rule({ match = { class = "nm-connection-editor" }, float = true })
hl.window_rule({ match = { class = "pavucontrol" }, float = true })
hl.window_rule({ match = { title = "File Operation Progress" }, float = true })
hl.window_rule({ match = { title = "Confirm to replace files" }, float = true })

-- CopyQ
hl.window_rule({ match = { class = "com.github.hluk.copyq" }, float = true })
hl.window_rule({ match = { class = "com.github.hluk.copyq" }, size = { 622, 652 } })
hl.window_rule({ match = { class = "com.github.hluk.copyq" }, center = true })

-- Alt-tab switcher
hl.window_rule({ match = { class = "alttab" }, no_anim = true })
hl.window_rule({ match = { class = "alttab" }, stay_focused = true })
hl.window_rule({ match = { class = "alttab" }, workspace = "special:alttab" })
hl.window_rule({ match = { class = "alttab" }, border_size = 0 })

-- Gaming - bypass compositor effects for performance
hl.window_rule({ match = { class = "gamescope" }, immediate = true })
hl.window_rule({ match = { class = "steam_app_.*" }, immediate = true })
hl.window_rule({ match = { class = "gamescope" }, no_blur = true })
hl.window_rule({ match = { class = "steam_app_.*" }, no_blur = true })
hl.window_rule({ match = { class = "gamescope" }, no_shadow = true })
hl.window_rule({ match = { class = "steam_app_.*" }, no_shadow = true })
hl.window_rule({ match = { class = "gamescope" }, fullscreen = true })
hl.window_rule({ match = { class = "steam_app_.*", fullscreen = true }, no_anim = true })


-- ══════════════════════════════════════════════════════════════
-- ║  Layer Rules — ionix-quickshell surfaces                    ║
-- ══════════════════════════════════════════════════════════════

-- The shell namespaces every surface with an `ionix-` prefix (ionix-bar,
-- ionix-osd), so one regex covers all of them.
--
-- blur_popups matters as much as blur: the popouts are xdg-popups of the bar
-- surface, not layer surfaces of their own, so they are not covered by `blur`.
--
-- ignore_alpha keeps the blur from bleeding out of the bar's rounded corners into
-- the fully transparent margin around it. (There is no `ignore_zero` field in the
-- Lua API — ignore_alpha subsumes it.)
hl.layer_rule({ match = { namespace = "ionix-.*" }, blur = true, blur_popups = true, ignore_alpha = 0.2 })
hl.layer_rule({ match = { namespace = "ionix-bar" }, animation = "slide top" })
hl.layer_rule({ match = { namespace = "ionix-osd" }, animation = "fade" })


-- ══════════════════════════════════════════════════════════════
-- ║  Alt-Tab                                                   ║
-- ══════════════════════════════════════════════════════════════

-- Tab/Shift+Tab cycle through windows while Alt is held
bind_exec("ALT + Tab", "ags request -i ionix-shell window-switcher next", { repeating = true })
bind_exec("SHIFT + ALT + Tab", "ags request -i ionix-shell window-switcher prev", { repeating = true })

-- Releasing Alt confirms and focuses the selected window
bind_exec("ALT + Alt_L", "ags request -i ionix-shell window-switcher confirm", { release = true, transparent = true })
hl.bind("ALT + Alt_L", hl.dsp.submap("reset"), { release = true, transparent = true })


-- ══════════════════════════════════════════════════════════════
-- ║  Autostart                                                 ║
-- ══════════════════════════════════════════════════════════════

hl.on("hyprland.start", function()
  hl.exec_cmd("awww-daemon")
  hl.exec_cmd("bash /etc/hypr/scripts/init.sh")
  hl.exec_cmd("hyprpolkitagent")
  -- swaync is deliberately not started: ionix-quickshell owns
  -- org.freedesktop.Notifications now, and two servers on that name means
  -- whichever loses the race silently stops working. Dropping this line is not
  -- enough on its own — swaync ships a D-Bus activation file for that same name,
  -- so /etc/systemd/user/swaync.service is masked to /dev/null as well. Undo both
  -- (and drop the shell's NotificationServer) to go back to swaync.
  -- The bar is ionix-quickshell, started by its systemd user unit (pre-enabled in
  -- /etc/skel) so it restarts itself on failure. waybar stays installed as a
  -- manual fallback but is deliberately not launched here.
  hl.exec_cmd("ioexplorer-spotlight --server")
  hl.exec_cmd("blueman-applet")
  hl.exec_cmd("gnome-keyring-daemon --start --components=secrets,pkcs11,ssh")
  hl.exec_cmd("copyq")
  hl.exec_cmd("foot --server")
  hl.exec_cmd("ioexplorer-start --server")
  hl.exec_cmd("ionix-first-login")
end)