-- ╔══════════════════════════════════════════════════════════════╗
-- ║  ionix-adaptive — Hyprland — static fallback                 ║
-- ╚══════════════════════════════════════════════════════════════╝
--
-- GENERATED from ../adaptive/hyprland/theme.lua with the base Ionix palette.
-- Installed when there is no wallpaper to read, no matugen, or a template that
-- failed to render. Edit the template and re-render rather than editing here,
-- or the two drift.
--
-- Hyprland writes colours as rgb(rrggbb)/rgba(rrggbbaa) with no leading '#',
-- which is what the .raw token form is for. Alpha is written here rather than
-- carried by the token, so each surface keeps its own opacity.
--
-- Geometry is deliberately absent: /etc/hypr/hyprland.lua already has the Ionix
-- shape, and this theme is about colour only. Everything below repaints.

hl.config({
  general = {
    col = {
      -- The base config's accent gradient, in the wallpaper's hue.
      active_border = { colors = { "rgb(9b59b6)", "rgb(7c3aed)" }, angle = 45 },
      inactive_border = { colors = { "rgb(2d2d3f)" } },
    },
  },

  decoration = {
    shadow = {
      enabled = true,
      range = 15,
      render_power = 3,
      -- The deepest background rather than neutral black, so the shadow reads
      -- as more of the same surface instead of soot under the window.
      color = "rgba(0f0a1888)",
    },
  },
})

-- ── hyprbars ──────────────────────────────────────────────────
-- Geometry, glyphs and actions stay with /etc/hypr/hyprland.lua; this only
-- repaints. The base config applies the bar from `config.reloaded`, which
-- fires after this file is parsed, so plain assignment is enough.
if ionix_bars then
  local c = ionix_bars.colors

  -- Heavy glass (~90%) over the window background, per the Ionix surface
  -- convention: translucent enough for decoration.blur to carry the wallpaper
  -- through, opaque enough to read a title against.
  c.bar  = "rgba(1a1025e6)"
  c.text = "rgba(e2d9f3ff)"

  -- Buttons on unfocused windows drop to the dim/border tone so only the
  -- focused window carries live colour.
  c.inactive_button = "rgba(4a3d60ff)"

  -- Close stays the semantic error red on every wallpaper: it is the one
  -- destructive control on the bar and must not be a colour swap away from the
  -- other two. Maximise and minimise take the bright and mid accents.
  c.close    = "rgb(e74c3c)"
  c.maximize = "rgb(a855f7)"
  c.minimize = "rgb(9b59b6)"

  -- Glyphs are punched out of the button in the deepest background.
  c.icon = "rgb(0f0a18)"
end
