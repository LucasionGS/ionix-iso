-- ╔══════════════════════════════════════════════════════════════╗
-- ║  dockix — menu bar and dock                                   ║
-- ║  Symlinked to ~/.config/hypr/theme.lua by `ionixtheme`.       ║
-- ╚══════════════════════════════════════════════════════════════╝

hl.config({
  general = {
    gaps_in = 4,
    gaps_out = 8,
    border_size = 1,

    col = {
      -- A hairline, not a frame: the accent stays off window edges.
      active_border = { colors = { "rgba(ffffff26)" } },
      inactive_border = { colors = { "rgba(ffffff14)" } },
    },
  },

  decoration = {
    -- Past 2 the corner stops being a circular arc and eases into the straight edge.
    rounding = 11,
    rounding_power = 3.2,

    inactive_opacity = 1.0,
    dim_inactive = false,

    -- Translucent surfaces are meant to pick up the colour behind them: vibrancy
    -- does that, and the brightness pulls it down enough to read white text over.
    blur = {
      enabled = true,
      size = 22,
      passes = 3,
      vibrancy = 0.45,
      vibrancy_darkness = 0.3,
      noise = 0.01,
      contrast = 1.0,
      brightness = 0.8,
      new_optimizations = true,
      popups = true,
    },

    -- A big soft drop, far heavier on the window that has focus: this is what says
    -- which one that is, since the border does not.
    shadow = {
      enabled = true,
      range = 56,
      render_power = 4,
      offset = "0 20",
      color = "rgba(00000080)",
      color_inactive = "rgba(00000040)",
    },

    glow = {
      enabled = false,
    },
  },
})

-- Fast out, long settle, no bounce.
hl.curve("dockixSettle", { type = "bezier", points = { { 0.32, 0.72 }, { 0.0, 1.0 } } })
hl.curve("dockixLeave", { type = "bezier", points = { { 0.4, 0.0 }, { 1.0, 1.0 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 3.5, bezier = "dockixSettle", style = "popin 86%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.6, bezier = "dockixLeave", style = "popin 92%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3.5, bezier = "dockixSettle" })
hl.animation({ leaf = "fade", enabled = true, speed = 2.5, bezier = "dockixSettle" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "dockixSettle", style = "slide" })

-- /etc/hypr/hyprland.lua sets `slide top` for the bar, which suits this one. The dock
-- comes up from the edge it lives on, and the all-apps overlay fades in by itself.
hl.layer_rule({ match = { namespace = "ionix-dock" }, animation = "slide bottom" })
hl.layer_rule({ match = { namespace = "ionix-appgrid" }, animation = "fade" })

-- Search on Super+Space. Floating moves over one modifier to make room for it.
hl.unbind("SUPER + Space")
hl.bind("SUPER + Space", hl.dsp.exec_cmd("ioexplorer-spotlight"))
hl.bind("SUPER + ALT + Space", hl.dsp.window.float({ action = "toggle" }))

-- ── hyprbars ──────────────────────────────────────────────────
-- Three plain coloured dots on the left, the title in the middle, and nothing drawn in
-- the dots: the base config applies this from `config.reloaded`, after this file is
-- parsed, so plain assignment is enough.
if ionix_bars then
  ionix_bars.height = 30
  ionix_bars.padding = 12
  ionix_bars.button_padding = 8
  ionix_bars.button_size = 12
  ionix_bars.text_font = "Dockix UI"
  ionix_bars.text_size = 10
  ionix_bars.text_weight = 600
  ionix_bars.text_align = "center"
  ionix_bars.buttons_align = "left"
  ionix_bars.button_order = { "close", "minimize", "maximize" }
  ionix_bars.icons = { close = "", maximize = "", minimize = "" }

  local c = ionix_bars.colors
  c.bar = "rgba(2c2c2eff)"
  c.text = "rgba(e5e5eaff)"
  c.close = "rgb(ff5f57)"
  c.minimize = "rgb(febc2e)"
  c.maximize = "rgb(28c840)"
  c.icon = "rgba(00000000)"
  c.inactive_button = "rgba(5a5a5eff)"
end
