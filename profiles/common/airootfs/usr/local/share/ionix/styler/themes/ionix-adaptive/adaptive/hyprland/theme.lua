-- ╔══════════════════════════════════════════════════════════════╗
-- ║  ionix-adaptive — Hyprland                                   ║
-- ║  Template. Rendered against the current wallpaper by          ║
-- ║  ionix-adaptive-colors; ../../hyprland/theme.lua is the same  ║
-- ║  file with the Ionix palette baked in, used as the fallback.  ║
-- ╚══════════════════════════════════════════════════════════════╝
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
      active_border = { colors = { "rgb({{accent.raw}})", "rgb({{accentDeep.raw}})" }, angle = 45 },
      inactive_border = { colors = { "rgb({{bgCard.raw}})" } },
    },
  },

  decoration = {
    shadow = {
      enabled = true,
      range = 15,
      render_power = 3,
      -- The deepest background rather than neutral black, so the shadow reads
      -- as more of the same surface instead of soot under the window.
      color = "rgba({{shadow.raw}}88)",
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
  c.bar  = "rgba({{bgWindow.raw}}e6)"
  c.text = "rgba({{textBright.raw}}ff)"

  -- Buttons on unfocused windows drop to the dim/border tone so only the
  -- focused window carries live colour.
  c.inactive_button = "rgba({{border.raw}}ff)"

  -- Close stays the semantic error red on every wallpaper: it is the one
  -- destructive control on the bar and must not be a colour swap away from the
  -- other two. Maximise and minimise take the bright and mid accents.
  c.close    = "rgb({{red.raw}})"
  c.maximize = "rgb({{accentBright.raw}})"
  c.minimize = "rgb({{accent.raw}})"

  -- Glyphs are punched out of the button in the deepest background.
  c.icon = "rgb({{bgDeep.raw}})"
end
