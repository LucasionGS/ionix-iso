-- ╔══════════════════════════════════════════════════════════════╗
-- ║  ionix-pro — neon cyber                                      ║
-- ║  Symlinked to ~/.config/hypr/theme.lua by `ionixtheme`.       ║
-- ╚══════════════════════════════════════════════════════════════╝

hl.config({
  general = {
    -- Slightly more air than base Ionix (2/2) so the glow below has room to read.
    gaps_in = 3,
    gaps_out = 4,
    border_size = 2,

    col = {
      -- Three stops rather than the base two: violet -> cyan -> magenta is the
      -- whole theme's identity in one line.
      active_border = { colors = { "rgb(b026ff)", "rgb(00f0ff)", "rgb(ff2bd6)" }, angle = 45 },
      inactive_border = { colors = { "rgb(1a0d33)" } },
    },
  },

  decoration = {
    rounding = 14,
    -- >2 flattens the corner curve toward a squircle; it keeps a 14px radius from
    -- looking as bulbous as plain rounding does at this size.
    rounding_power = 4,

    inactive_opacity = 0.94,
    -- dim_inactive = false,
    -- dim_strength = 0.18,

    blur = {
      enabled = true,
      size = 8,
      passes = 3,
      -- vibrancy saturates what shows through the glass, which is what keeps the
      -- wallpaper's colour behind a 0.55-opacity bar instead of washing it grey.
      vibrancy = 0.25,
      vibrancy_darkness = 0.4,
      noise = 0.015,
      contrast = 1.1,
      brightness = 0.9,
      new_optimizations = true,
      popups = true,
    },

    shadow = {
      enabled = true,
      range = 28,
      render_power = 4,
      color = "rgba(b026ff55)",
      color_inactive = "rgba(00000066)",
    },

    -- The actual neon. glow is a coloured bloom on the focused window only; the
    -- base theme does not use it at all. Fully transparent when inactive so only
    -- one window on screen is ever lit.
    glow = {
      enabled = true,
      range = 12,
      render_power = 3,
      color = "rgba(00f0ff66)",
      color_inactive = "rgba(00000000)",
    },
  },
})

-- Snappier than ionixSmooth, with a small overshoot at the end.
hl.curve("ionixProNeon", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 4, bezier = "ionixProNeon", style = "popin 88%" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "ionixProNeon", style = "slidefade 20%" })

-- Glassier terminal to match the bar. These re-declare rules the base config
-- already sets for the terminals; later window_rules win, so these are the ones that apply.
hl.window_rule({ match = { class = "kitty|ionterm" }, opacity = "0.72" })
hl.window_rule({ match = { class = "kitty|ionterm", focus = true }, opacity = "0.86" })

hl.window_rule({
  match = { float = true },
  opaque = true -- Avoid transparency on a floating window
})

-- ── hyprbars ──────────────────────────────────────────────────
-- /etc/hypr/hyprland.lua owns the geometry, the button glyphs and the actions;
-- this only repaints them. Assigning into `ionix_bars` is enough because the
-- base config applies the bar from `config.reloaded`, which fires after this
-- file has been parsed. Guarded so the theme still loads on a system whose
-- /etc/hypr predates that section.
if ionix_bars then
  local c = ionix_bars.colors

  -- bgCard at 0.8 rather than the base 0.9: this theme runs glassier
  -- everywhere (its shell bar sits at 0.55), and the blur.vibrancy 0.25 set
  -- above saturates what shows through instead of greying it out.
  c.bar  = "rgba(1a0d33cc)"
  c.text = "rgba(e6d9ffff)"

  -- The three buttons are the three stops of the active_border gradient, in
  -- the order the gradient runs them. That ties the bar into the frame rather
  -- than bolting it on — worth more here than the base config's rule of giving
  -- close a semantic red, because this theme's whole identity is that
  -- violet -> cyan -> magenta line.
  c.minimize = "rgb(b026ff)"
  c.maximize = "rgb(00f0ff)"
  c.close    = "rgb(ff2bd6)"

  -- Glyphs punched out in bgDeep; the neons are bright enough to carry a
  -- near-black cleanly at this size.
  c.icon = "rgb(070312)"

  -- `muted` is the palette's passive-icon role. Unfocused windows already lose
  -- their glow entirely in this theme, so the buttons go quiet along with it.
  c.inactive_button = "rgba(8a6bb8ff)"
end
