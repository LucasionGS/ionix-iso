-- ╔══════════════════════════════════════════════════════════════╗
-- ║  winix — Windows 11                                          ║
-- ║  Symlinked to ~/.config/hypr/theme.lua by `ionixtheme`.       ║
-- ╚══════════════════════════════════════════════════════════════╝

hl.config({
  general = {
    -- Windows snap layouts leave a small gutter rather than none at all, and a
    -- little outer gap is what stops a maximised window looking bezel-less.
    gaps_in = 3,
    gaps_out = 6,
    -- 1px. Windows draws a hairline stroke, not the 2px frame the other themes use.
    border_size = 1,

    col = {
      -- One stop, not a gradient: a Windows window border is a flat accent line.
      active_border = { colors = { "rgb(4cc2ff)" } },
      inactive_border = { colors = { "rgb(3a3a3a)" } },
    },
  },

  decoration = {
    rounding = 8,
    -- 2 = a true circular arc. ionix-pro raises this to flatten the curve toward a
    -- squircle; Windows corners are plain radii, so leave it at the round default.
    rounding_power = 2,

    -- Windows does not fade or dim what you are not looking at. Both of these are
    -- set explicitly rather than left off, because they are the single most
    -- noticeable difference from ionix-pro.
    inactive_opacity = 1.0,
    dim_inactive = false,

    blur = {
      enabled = true,
      size = 6,
      passes = 3,
      -- Acrylic *desaturates* what shows through it — the opposite of the vibrancy
      -- ionix-pro leans on. The low value plus the noise grain is what makes the
      -- taskbar read as Windows glass rather than a coloured pane.
      vibrancy = 0.1,
      vibrancy_darkness = 0.2,
      noise = 0.02,
      contrast = 1.0,
      brightness = 0.9,
      new_optimizations = true,
      popups = true,
    },

    shadow = {
      enabled = true,
      range = 20,
      render_power = 3,
      -- Neutral black. Windows shadows carry no hue.
      color = "rgba(00000066)",
      color_inactive = "rgba(00000040)",
    },

    -- /etc/hypr never enables glow, so this is already the default — but say it, so
    -- it is obvious this theme is deliberately not ionix-pro.
    glow = {
      enabled = false,
    },
  },
})

-- Approximates Fluent's decelerate curve: leaves immediately, settles softly, and
-- never overshoots. Windows motion is short and calm.
hl.curve("winixFluent", { type = "bezier", points = { { 0.1, 0.9 }, { 0.2, 1.0 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "winixFluent", style = "popin 96%" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "winixFluent", style = "slidefade 15%" })

-- The bar lives at the bottom in this theme, so it has to come in from the bottom.
-- /etc/hypr/hyprland.lua sets `slide top` for this namespace; this rule is parsed
-- later and wins.
hl.layer_rule({ match = { namespace = "ionix-bar" }, animation = "slide bottom" })

-- Near-opaque terminal — Windows Terminal ships opaque, and the base config's 0.8/0.9
-- terminal rules would otherwise stay in force. These multiply with the terminal's own
-- background_opacity (0.94), landing around 0.90 unfocused and 0.94 focused.
hl.window_rule({ match = { class = "kitty|ionterm" }, opacity = "0.96" })
hl.window_rule({ match = { class = "kitty|ionterm", focus = true }, opacity = "1.0" })

-- ── hyprbars ──────────────────────────────────────────────────
-- Geometry, glyphs and actions stay with /etc/hypr/hyprland.lua; this only
-- repaints. The base config applies the bar from `config.reloaded`, which
-- fires after this file is parsed, so plain assignment is enough.
if ionix_bars then
  local c = ionix_bars.colors

  -- bgWindow at 0.78 — the same alpha this theme gives its shell bar, so the
  -- title bar reads as the same acrylic rather than the heavier glass the
  -- other themes use.
  c.bar  = "rgba(202020c7)"
  c.text = "rgba(e0e0e0ff)"

  -- Windows leaves minimise and maximise as neutral chrome and colours only
  -- close, so these two are deliberately the same border grey: the glyph, not
  -- the colour, is what distinguishes them. The red is the actual Windows
  -- close-button red.
  c.minimize = "rgb(454545)"
  c.maximize = "rgb(454545)"
  c.close    = "rgb(e81123)"

  -- Inverted against the other themes — light glyphs on dark buttons. A bgDeep
  -- glyph would be unreadable on #454545, and white-on-red is what the real
  -- close button does.
  c.icon = "rgb(ffffff)"

  -- 0x00000000 reads as "unset" to hyprbars, which leaves buttons at their own
  -- colours when the window loses focus. That is the point: this theme sets
  -- inactive_opacity 1.0 and dim_inactive false because Windows does not fade
  -- what you are not looking at, and dimmed buttons would contradict it.
  c.inactive_button = "rgba(00000000)"
end
