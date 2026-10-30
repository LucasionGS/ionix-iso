#!/usr/bin/env python3
# Writes system/assets/dockix/wallpaper.svg: an original dusk over rolling ridges for
# the dockix theme. Generated rather than hand-drawn because each ridge is the same
# curve at another height; re-run it after changing the numbers.
#   system/assets/dockix/make-wallpaper.py > system/assets/dockix/wallpaper.svg

import math

W, H = 3840, 2160

# (baseline as a fraction of the height, amplitude, phase, frequency, top colour, foot colour)
RIDGES = [
  (0.40, 150, 0.4, 1.1, "#c8558f", "#7a3a9e"),
  (0.50, 190, 2.1, 0.9, "#a23f9a", "#57308f"),
  (0.60, 170, 4.0, 1.3, "#7c3596", "#3f2a80"),
  (0.71, 150, 1.2, 1.0, "#55308a", "#2c2269"),
  (0.82, 130, 3.1, 1.2, "#372763", "#1d1a4c"),
  (0.92, 100, 5.2, 0.8, "#231c47", "#120f30"),
]


def ridge(base, amplitude, phase, frequency):
  # Two sines an octave and a bit apart: enough to look like land, not like a wave.
  points = []
  for step in range(0, 61):
    x = W * step / 60
    t = step / 60 * math.pi * 2
    y = H * base + amplitude * (math.sin(t * frequency + phase) + 0.35 * math.sin(t * frequency * 2.3 + phase * 1.7))
    points.append((x, y))
  # Catmull-Rom through the samples, written as cubic Beziers.
  d = [f"M{points[0][0]:.0f} {points[0][1]:.0f}"]
  for i in range(len(points) - 1):
    p0 = points[max(i - 1, 0)]
    p1 = points[i]
    p2 = points[i + 1]
    p3 = points[min(i + 2, len(points) - 1)]
    c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
    c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
    d.append(f"C{c1[0]:.0f} {c1[1]:.0f} {c2[0]:.0f} {c2[1]:.0f} {p2[0]:.0f} {p2[1]:.0f}")
  d.append(f"L{W} {H}L0 {H}Z")
  return "".join(d)


def main():
  out = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">', "<defs>"]
  out.append('<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1b2a6b"/><stop offset="0.28" stop-color="#5a3f9e"/><stop offset="0.48" stop-color="#d9648f"/><stop offset="0.62" stop-color="#ffb37a"/></linearGradient>')
  out.append(f'<radialGradient id="glow" gradientUnits="userSpaceOnUse" cx="{W * 0.62:.0f}" cy="{H * 0.46:.0f}" r="{W * 0.42:.0f}"><stop offset="0" stop-color="#ffe2b0" stop-opacity="0.75"/><stop offset="0.4" stop-color="#ffb37a" stop-opacity="0.28"/><stop offset="1" stop-color="#ffb37a" stop-opacity="0"/></radialGradient>')
  for i, (base, amplitude, _, _, top, foot) in enumerate(RIDGES):
    y1 = H * base - amplitude
    out.append(f'<linearGradient id="r{i}" gradientUnits="userSpaceOnUse" x1="0" y1="{y1:.0f}" x2="0" y2="{min(H, H * base + H * 0.28):.0f}"><stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{foot}"/></linearGradient>')
  out.append("</defs>")
  out.append(f'<rect width="{W}" height="{H}" fill="url(#sky)"/>')
  out.append(f'<rect width="{W}" height="{H}" fill="url(#glow)"/>')
  for i, (base, amplitude, phase, frequency, _, _) in enumerate(RIDGES):
    out.append(f'<path d="{ridge(base, amplitude, phase, frequency)}" fill="url(#r{i})"/>')
  out.append("</svg>")
  print("\n".join(out))


if __name__ == "__main__":
  main()
