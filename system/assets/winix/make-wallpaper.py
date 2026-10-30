#!/usr/bin/env python3
# Writes system/assets/winix/wallpaper.svg: an original abstract bloom in the Fluent
# accent blue, for the winix-experimental theme. Generated rather than hand-drawn
# because every petal is the same shape rotated; re-run it after changing the numbers.
#   system/assets/winix/make-wallpaper.py > system/assets/winix/wallpaper.svg

import math

W, H = 3840, 2160
CX, CY = W / 2, H * 0.52

# (count, reach, width, twist in degrees, inner colour, outer colour, opacity)
LAYERS = [
  (9, 1120, 0.62, 0, "#0a2a6e", "#0b5fd6", 0.55),
  (9, 980, 0.58, 20, "#0c3f9e", "#1a86f2", 0.62),
  (9, 800, 0.56, 8, "#0f5bc4", "#38a8ff", 0.70),
  (9, 620, 0.54, 28, "#1a7be0", "#7fd0ff", 0.72),
  (9, 430, 0.50, 14, "#3ea2f5", "#c9f0ff", 0.70),
  (9, 240, 0.46, 34, "#8fd2ff", "#ffffff", 0.75),
]


def petal(reach, width):
  # From the centre to the tip with a slight sweep, so the ring looks folded.
  r = reach
  w = r * width
  return f"M0 0C{w:.0f} {-r * 0.22:.0f} {w * 0.78:.0f} {-r * 0.78:.0f} {w * 0.1:.0f} {-r:.0f}C{-w * 0.42:.0f} {-r * 0.72:.0f} {-w * 0.58:.0f} {-r * 0.28:.0f} 0 0Z"


def main():
  out = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">', "<defs>"]
  out.append('<radialGradient id="bg" cx="50%" cy="52%" r="72%"><stop offset="0" stop-color="#0d3a8c"/><stop offset="0.45" stop-color="#0a1f4f"/><stop offset="1" stop-color="#060b1c"/></radialGradient>')
  for i, (_, reach, _, _, inner, outer, _) in enumerate(LAYERS):
    out.append(f'<linearGradient id="p{i}" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="0" y2="{-reach}"><stop offset="0" stop-color="{inner}"/><stop offset="1" stop-color="{outer}"/></linearGradient>')
  out.append("</defs>")
  out.append(f'<rect width="{W}" height="{H}" fill="url(#bg)"/>')
  out.append(f'<g transform="translate({CX} {CY})">')
  for i, (count, reach, width, twist, _, _, opacity) in enumerate(LAYERS):
    d = petal(reach, width)
    for n in range(count):
      angle = twist + n * 360 / count
      out.append(f'<path d="{d}" fill="url(#p{i})" opacity="{opacity}" transform="rotate({angle:.2f})"/>')
  out.append("</g></svg>")
  print("\n".join(out))


if __name__ == "__main__":
  main()
