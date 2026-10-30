#!/usr/bin/env python3
# Builds the "Winix UI" family in system/desktop/usr/share/fonts/winix/: Microsoft's
# Selawik (OFL; metric-compatible with Segoe UI, which cannot be redistributed) with
# Fluent System Icons (MIT) merged in under the codepoints ionix-quickshell's
# Icons.qml already uses. A theme naming this family then gets Segoe-shaped text and
# Fluent icons in every panel with no change to the shell. One family rather than a
# fallback list because Qt takes font.family as a single name; a glyph not mapped
# here still falls through to the system's fallback, the Nerd Font.
#
# The results are committed, so a build needs neither this script nor its sources.
# Re-run it when the shell gains a glyph worth mapping, from a directory with
# Selawik's release (selawk.ttf and friends, https://github.com/microsoft/Selawik/releases)
# and https://github.com/microsoft/fluentui-system-icons/tree/main/fonts:
#   build-icon-font.py <selawik-dir> FluentSystemIcons-Regular.ttf FluentSystemIcons-Regular.json <out-dir>

import json
import os
import sys
import tempfile

from fontTools import merge, subset
from fontTools.ttLib import TTFont
from fontTools.ttLib.scaleUpem import scale_upem
from fontTools.ttLib.tables._c_m_a_p import CmapSubtable

# Nerd Font codepoint -> Fluent icon name, in Icons.qml's order of appearance.
MAP = {
  0xF0004: "person", 0xF0009: "person_circle", 0xF0026: "warning", 0xF003B: "apps",
  0xF0054: "arrow_right",
  # Battery ramp, empty to full
  0xF008E: "battery_0", 0xF0079: "battery_10", 0xF007A: "battery_1", 0xF007B: "battery_2",
  0xF007C: "battery_3", 0xF007D: "battery_4", 0xF007E: "battery_5", 0xF007F: "battery_6",
  0xF0080: "battery_7", 0xF0081: "battery_8", 0xF0082: "battery_9", 0xF0084: "battery_charge",
  0xF009A: "alert", 0xF009B: "alert_off", 0xF009E: "alert_on",
  0xF00AF: "bluetooth", 0xF00B1: "bluetooth_connected", 0xF00B2: "bluetooth_disabled",
  0xF00DF: "brightness_high", 0xF00ED: "calendar", 0xF00EE: "calendar_empty",
  0xF00EF: "calendar_checkmark", 0xF00F0: "calendar_clock", 0xF0100: "camera", 0xF011C: "phone",
  0xF012C: "checkmark", 0xF0140: "chevron_down", 0xF0141: "chevron_left",
  0xF0142: "chevron_right", 0xF0143: "chevron_up", 0xF0156: "dismiss", 0xF0164: "cloud_off",
  0xF018F: "copy", 0xF0193: "save", 0xF01B4: "delete", 0xF0200: "plug_connected",
  0xF0237: "fingerprint", 0xF0238: "fire", 0xF024B: "folder", 0xF02B4: "games",
  0xF02BB: "people_team", 0xF02CA: "weather_moon", 0xF02CB: "headphones", 0xF02CE: "headset",
  0xF02DA: "history", 0xF030C: "keyboard", 0xF032A: "leaf_two", 0xF0335: "lightbulb",
  0xF033E: "lock_closed", 0xF033F: "lock_open", 0xF0342: "arrow_enter", 0xF0343: "arrow_exit",
  0xF0349: "search", 0xF034E: "location", 0xF036C: "mic", 0xF036D: "mic_off",
  0xF037D: "cursor", 0xF03CC: "open", 0xF03D8: "color", 0xF03E4: "pause", 0xF03EB: "edit",
  0xF0403: "pin", 0xF040A: "play", 0xF0415: "add", 0xF0425: "power", 0xF042A: "print",
  0xF0450: "arrow_clockwise", 0xF0456: "arrow_repeat_all", 0xF0457: "arrow_repeat_all_off",
  0xF0458: "arrow_repeat_1", 0xF0493: "settings", 0xF049D: "arrow_shuffle_off",
  0xF049F: "arrow_shuffle", 0xF04AD: "next", 0xF04AE: "previous", 0xF04C3: "speaker_2",
  0xF04C5: "top_speed", 0xF04DB: "stop", 0xF04E6: "arrow_sync", 0xF0567: "video",
  0xF0570: "grid", 0xF057E: "speaker_0", 0xF057F: "speaker_1", 0xF0580: "speaker_2",
  0xF0581: "speaker_mute", 0xF0589: "clock", 0xF05AA: "wifi_warning", 0xF05AF: "window",
  0xF0632: "keyboard_shift", 0xF06E8: "lightbulb_filament", 0xF0709: "arrow_counterclockwise",
  0xF073A: "dismiss_circle", 0xF075A: "music_note_2", 0xF07C0: "desktop", 0xF0904: "weather_moon",
  # Wi-Fi ramp, weak to strong. Fluent numbers these the other way round.
  0xF091F: "wifi_4", 0xF0922: "wifi_3", 0xF0925: "wifi_2", 0xF0928: "wifi_1",
  0xF092B: "wifi_off", 0xF0930: "pin_off", 0xF0E4F: "lightbulb", 0xF0F85: "gauge",
  0xF10A9: "panel_bottom", 0xF10AA: "panel_left", 0xF10AB: "panel_right", 0xF10AC: "window",
  0xF13AB: "timer", 0xF140B: "flash", 0xF1513: "window", 0xF1853: "lightbulb_filament",
}
# Sizes to look for, best first. 20 is what Windows' own shell draws at.
SIZES = [20, 24, 16, 28, 32, 48]


# Selawik file, style name, OS/2 weight.
WEIGHTS = [("selawkl.ttf", "Light", 300), ("selawk.ttf", "Regular", 400), ("selawksb.ttf", "Semibold", 600), ("selawkb.ttf", "Bold", 700)]


def icons(source, table, upem, out):
  """The mapped icons alone, as a font at Selawik's units per em."""
  names = json.load(open(table))
  wanted = {}
  missing = []
  for code, name in MAP.items():
    for size in SIZES:
      full = f"ic_fluent_{name}_{size}_regular"
      if full in names:
        wanted[code] = names[full]
        break
    else:
      missing.append(name)
  if missing:
    sys.exit(f"Not in this Fluent release, pick another name in MAP: {', '.join(missing)}")

  font = TTFont(source)
  options = subset.Options()
  options.layout_features = []
  options.notdef_outline = True
  subsetter = subset.Subsetter(options)
  subsetter.populate(unicodes=set(wanted.values()))
  subsetter.subset(font)

  # Glyphs keep their names; only the codepoints that reach them change.
  source_cmap = font.getBestCmap()
  table12 = CmapSubtable.newSubtable(12)
  table12.platformID, table12.platEncID, table12.language = 3, 10, 0
  table12.cmap = {code: source_cmap[fluent] for code, fluent in wanted.items()}
  font["cmap"].tables = [table12]
  # The merger wants the tables its other inputs have, and these only get in its way.
  for tag in ("GSUB", "GPOS", "GDEF", "DSIG", "meta"):
    if tag in font:
      del font[tag]
  scale_upem(font, upem)
  font.save(out)


def build(selawik, icon_font, style, weight, out):
  base = TTFont(selawik)
  # Text layout tables stay out: the merger cannot combine them with a font that
  # has none, and the shell's text never leans on them beyond plain kerning.
  for tag in ("DSIG", "GSUB", "GPOS", "GDEF", "hdmx", "VDMX", "LTSH", "kern", "fpgm", "prep", "cvt ", "gasp"):
    if tag in base:
      del base[tag]
  with tempfile.TemporaryDirectory() as tmp:
    plain = os.path.join(tmp, "base.ttf")
    base.save(plain)
    merged = merge.Merger().merge([plain, icon_font])

  name = merged["name"]
  for rec in list(name.names):
    if rec.nameID in (1, 2, 3, 4, 6, 16, 17, 21, 22):
      name.removeNames(nameID=rec.nameID)
  legacy = "Winix UI" if style in ("Regular", "Bold") else f"Winix UI {style}"
  for nid, value in (
    (1, legacy),
    (2, style if style in ("Regular", "Bold") else "Regular"),
    (3, f"Winix UI {style}"),
    (4, f"Winix UI {style}"),
    (6, f"WinixUI-{style}"),
    (16, "Winix UI"),
    (17, style),
  ):
    name.setName(value, nid, 3, 1, 0x409)
  merged["OS/2"].usWeightClass = weight
  merged.save(out)
  print(f"{out}: {len(merged.getGlyphOrder())} glyphs")


def main():
  selawik, source, table, out_dir = sys.argv[1:5]
  upem = TTFont(os.path.join(selawik, "selawk.ttf"))["head"].unitsPerEm
  with tempfile.TemporaryDirectory() as tmp:
    icon_font = os.path.join(tmp, "icons.ttf")
    icons(source, table, upem, icon_font)
    for file, style, weight in WEIGHTS:
      build(os.path.join(selawik, file), icon_font, style, weight, os.path.join(out_dir, f"WinixUI-{style}.ttf"))


if __name__ == "__main__":
  main()
