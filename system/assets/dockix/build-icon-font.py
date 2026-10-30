#!/usr/bin/env python3
# Builds the "Dockix UI" family in system/desktop/usr/share/fonts/dockix/: Inter (OFL)
# with Phosphor Icons (MIT) merged in under the codepoints ionix-quickshell's Icons.qml
# already uses. A theme naming this family then gets its text and its icons in every
# panel with no change to the shell. One family rather than a fallback list because Qt
# takes font.family as a single name; a glyph not mapped here still falls through to
# the system's fallback, the Nerd Font.
#
# The results are committed, so a build needs neither this script nor its sources.
# Re-run it when the shell gains a glyph worth mapping, with Inter's release
# (https://github.com/rsms/inter/releases, extras/ttf) and @phosphor-icons/web's
# src/regular from npm:
#   build-icon-font.py <inter-ttf-dir> Phosphor.ttf selection.json <out-dir>

import json
import os
import sys
import tempfile

from fontTools import merge, subset
from fontTools.ttLib import TTFont
from fontTools.ttLib.scaleUpem import scale_upem
from fontTools.ttLib.tables._c_m_a_p import CmapSubtable

# Nerd Font codepoint -> Phosphor icon name, in Icons.qml's order of appearance.
MAP = {
  0xF0004: "user", 0xF0009: "user-circle", 0xF0026: "warning", 0xF003B: "squares-four",
  0xF0054: "arrow-right",
  # Battery ramp, empty to full
  0xF008E: "battery-empty", 0xF007A: "battery-low", 0xF007B: "battery-low", 0xF007C: "battery-low",
  0xF007D: "battery-medium", 0xF007E: "battery-medium", 0xF007F: "battery-medium", 0xF0080: "battery-high",
  0xF0081: "battery-high", 0xF0082: "battery-full", 0xF0079: "battery-full", 0xF0084: "battery-charging",
  0xF009A: "bell", 0xF009B: "bell-slash", 0xF009E: "bell-ringing",
  0xF00AF: "bluetooth", 0xF00B1: "bluetooth-connected", 0xF00B2: "bluetooth-slash",
  0xF00DF: "sun", 0xF00ED: "calendar-blank", 0xF00EE: "calendar-blank",
  0xF00EF: "calendar-check", 0xF00F0: "calendar-dots", 0xF0100: "camera", 0xF011C: "phone",
  0xF012C: "check", 0xF0140: "caret-down", 0xF0141: "caret-left",
  0xF0142: "caret-right", 0xF0143: "caret-up", 0xF0156: "x", 0xF0164: "cloud-slash",
  0xF018F: "copy", 0xF0193: "floppy-disk", 0xF01B4: "trash", 0xF0200: "plug",
  0xF0237: "fingerprint", 0xF0238: "fire", 0xF024B: "folder-simple", 0xF02B4: "game-controller",
  0xF02BB: "users-three", 0xF02CA: "moon", 0xF02CB: "headphones", 0xF02CE: "headset",
  0xF02DA: "clock-counter-clockwise", 0xF030C: "keyboard", 0xF032A: "leaf", 0xF0335: "lightbulb",
  0xF033E: "lock", 0xF033F: "lock-open", 0xF0342: "sign-in", 0xF0343: "sign-out",
  0xF0349: "magnifying-glass", 0xF034E: "map-pin", 0xF036C: "microphone", 0xF036D: "microphone-slash",
  0xF037D: "cursor", 0xF03CC: "arrow-square-out", 0xF03D8: "palette", 0xF03E4: "pause", 0xF03EB: "pencil-simple",
  0xF0403: "push-pin", 0xF040A: "play", 0xF0415: "plus", 0xF0425: "power", 0xF042A: "printer",
  0xF0450: "arrow-clockwise", 0xF0456: "repeat", 0xF0457: "repeat", 0xF0458: "repeat-once",
  0xF0493: "gear", 0xF049D: "shuffle", 0xF049F: "shuffle-angular", 0xF04AD: "skip-forward", 0xF04AE: "skip-back",
  0xF04C3: "speaker-high", 0xF04C5: "gauge", 0xF04DB: "stop", 0xF04E6: "arrows-clockwise", 0xF0567: "video",
  0xF0570: "squares-four", 0xF057E: "speaker-none", 0xF057F: "speaker-low", 0xF0580: "speaker-high",
  0xF0581: "speaker-x", 0xF0589: "clock", 0xF05AA: "wifi-x", 0xF05AF: "app-window",
  0xF0632: "arrow-fat-up", 0xF06E8: "lightbulb-filament", 0xF0709: "arrow-counter-clockwise",
  0xF073A: "x-circle", 0xF075A: "music-notes", 0xF07C0: "desktop", 0xF0904: "moon",
  # Wi-Fi ramp, weak to strong.
  0xF091F: "wifi-low", 0xF0922: "wifi-medium", 0xF0925: "wifi-high", 0xF0928: "wifi-high",
  0xF092B: "wifi-slash", 0xF0930: "push-pin-slash", 0xF0E4F: "lightbulb", 0xF0F85: "gauge",
  0xF10A9: "layout", 0xF10AA: "sidebar", 0xF10AB: "sidebar-simple", 0xF10AC: "app-window",
  0xF13AB: "timer", 0xF140B: "lightning", 0xF1513: "app-window", 0xF1853: "lightbulb-filament",
  # Tune: the Quick Settings button.
  0xF062E: "sliders-horizontal",
}

# Inter file, style name, OS/2 weight.
WEIGHTS = [("Inter-Light.ttf", "Light", 300), ("Inter-Regular.ttf", "Regular", 400), ("Inter-Medium.ttf", "Medium", 500), ("Inter-SemiBold.ttf", "SemiBold", 600), ("Inter-Bold.ttf", "Bold", 700)]


def icons(source, table, upem, out):
  """The mapped icons alone, as a font at Inter's units per em."""
  names = {i["properties"]["name"]: i["properties"]["code"] for i in json.load(open(table))["icons"]}
  missing = sorted({name for name in MAP.values() if name not in names})
  if missing:
    sys.exit(f"Not in this Phosphor release, pick another name in MAP: {', '.join(missing)}")
  wanted = {code: names[name] for code, name in MAP.items()}

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
  table12.cmap = {code: source_cmap[phosphor] for code, phosphor in wanted.items()}
  font["cmap"].tables = [table12]
  # The merger wants the tables its other inputs have, and these only get in its way.
  for tag in ("GSUB", "GPOS", "GDEF", "DSIG", "meta"):
    if tag in font:
      del font[tag]
  scale_upem(font, upem)
  font.save(out)


def build(inter, icon_font, style, weight, out):
  base = TTFont(inter)
  # Text layout tables stay out: the merger cannot combine them with a font that
  # has none, and the shell's text never leans on them beyond plain kerning.
  for tag in ("DSIG", "GSUB", "GPOS", "GDEF", "hdmx", "VDMX", "LTSH", "kern", "fpgm", "prep", "cvt ", "gasp", "STAT"):
    if tag in base:
      del base[tag]
  with tempfile.TemporaryDirectory() as tmp:
    plain = os.path.join(tmp, "base.ttf")
    base.save(plain)
    merged = merge.Merger().merge([plain, icon_font])

  name = merged["name"]
  for rec in list(name.names):
    if rec.nameID in (1, 2, 3, 4, 6, 16, 17, 21, 22, 25):
      name.removeNames(nameID=rec.nameID)
  legacy = "Dockix UI" if style in ("Regular", "Bold") else f"Dockix UI {style}"
  for nid, value in (
    (1, legacy),
    (2, style if style in ("Regular", "Bold") else "Regular"),
    (3, f"Dockix UI {style}"),
    (4, f"Dockix UI {style}"),
    (6, f"DockixUI-{style}"),
    (16, "Dockix UI"),
    (17, style),
  ):
    name.setName(value, nid, 3, 1, 0x409)
  merged["OS/2"].usWeightClass = weight
  merged.save(out)
  print(f"{out}: {len(merged.getGlyphOrder())} glyphs")


def main():
  inter, source, table, out_dir = sys.argv[1:5]
  upem = TTFont(os.path.join(inter, "Inter-Regular.ttf"))["head"].unitsPerEm
  with tempfile.TemporaryDirectory() as tmp:
    icon_font = os.path.join(tmp, "icons.ttf")
    icons(source, table, upem, icon_font)
    for file, style, weight in WEIGHTS:
      build(os.path.join(inter, file), icon_font, style, weight, os.path.join(out_dir, f"DockixUI-{style}.ttf"))


if __name__ == "__main__":
  main()
