-- ╔══════════════════════════════════════════════════════════════╗
-- ║  winix-experimental — Windows 11                              ║
-- ║  Symlinked to ~/.config/hypr/theme.lua by `ionixtheme`.       ║
-- ╚══════════════════════════════════════════════════════════════╝

hl.config({
  general = {
    gaps_in = 3,
    gaps_out = 6,
    border_size = 1,

    col = {
      -- Windows 11 draws a neutral hairline; the accent stays off window frames
      -- unless the user asks for it in Settings, and by default they do not.
      active_border = { colors = { "rgba(ffffff2e)" } },
      inactive_border = { colors = { "rgba(ffffff14)" } },
    },
  },

  decoration = {
    -- OverlayCornerRadius, and a true circular arc: Fluent corners are plain radii.
    rounding = 8,
    rounding_power = 2,

    inactive_opacity = 1.0,
    dim_inactive = false,

    blur = {
      enabled = true,
      size = 12,
      passes = 3,
      -- Acrylic and Mica desaturate what shows through them, and the grain is
      -- what stops a large flat panel banding.
      vibrancy = 0.1,
      vibrancy_darkness = 0.2,
      noise = 0.02,
      contrast = 1.0,
      brightness = 0.85,
      new_optimizations = true,
      popups = true,
    },

    -- Windows' elevation shadow: wide, soft, neutral, heavier on what has focus.
    shadow = {
      enabled = true,
      range = 32,
      render_power = 3,
      offset = "0 8",
      color = "rgba(00000080)",
      color_inactive = "rgba(00000050)",
    },

    glow = {
      enabled = false,
    },
  },
})

-- Fluent's decelerate curve, with its 250ms/167ms durations: leaves at once, settles
-- softly, never overshoots.
hl.curve("fluentDecelerate", { type = "bezier", points = { { 0.1, 0.9 }, { 0.2, 1.0 } } })
hl.curve("fluentAccelerate", { type = "bezier", points = { { 0.7, 0.0 }, { 1.0, 0.5 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 2.5, bezier = "fluentDecelerate", style = "popin 92%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.7, bezier = "fluentAccelerate", style = "popin 92%" })
hl.animation({ leaf = "fade", enabled = true, speed = 2, bezier = "fluentDecelerate" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "fluentDecelerate", style = "slidefade 10%" })

-- /etc/hypr/hyprland.lua sets `slide top` for the bar; this one lives at the bottom.
hl.layer_rule({ match = { namespace = "ionix-bar" }, animation = "slide bottom" })

-- Windows Terminal ships opaque; the base config's terminal rules would keep it glassy.
hl.window_rule({ match = { class = "kitty|ionterm" }, opacity = "1.0" })
hl.window_rule({ match = { class = "kitty|ionterm", focus = true }, opacity = "1.0" })

-- Windows' own shortcut for what this theme's bar opens. Super+Tab is in the base config.
hl.bind("SUPER + A", hl.dsp.exec_cmd("qs -c ionix ipc call popout toggle quicksettings"))

-- ── hyprbars ──────────────────────────────────────────────────
-- Windows' caption: title on the left, 32px bar, flat glyphs and no button shapes.
-- The base config applies this from `config.reloaded`, after this file is parsed,
-- so plain assignment is enough. hyprbars itself can only draw round buttons with a
-- fill, so "flat" is a transparent fill; there is no red hover on Close without
-- changing the plugin.
if ionix_bars then
  ionix_bars.height = 32
  ionix_bars.padding = 12
  ionix_bars.button_padding = 22
  ionix_bars.button_size = 12
  ionix_bars.text_font = "Winix UI"
  ionix_bars.text_size = 10
  ionix_bars.text_weight = 400
  ionix_bars.text_align = "left"
  ionix_bars.icons = { close = "✕", maximize = "□", minimize = "—" }

  local c = ionix_bars.colors
  c.bar = "rgba(202020ff)"
  c.text = "rgba(ffffffff)"
  c.minimize = "rgba(00000000)"
  c.maximize = "rgba(00000000)"
  c.close = "rgba(00000000)"
  c.icon = "rgb(ffffff)"
  c.inactive_button = "rgba(00000000)"
end
