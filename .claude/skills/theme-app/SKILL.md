---
name: theme-app
description: Theme an application to match the Ionix purple palette, or make an app's theme switchable via the ionixtheme styler. Use when styling any app config (GTK, kitty, waybar, CSS, JSON, QML, hyprland) to the distro look, or when adding an app to the styler theme system. Encodes the palette roles, glass convention, per-syntax translation patterns, and styler registration.
---

# Theming an app for Ionix

There is **no shared palette file** — every consumer re-declares the palette in its own syntax. The role→hex table and glass convention live in the repo root `CLAUDE.md` under **Visual Theme**; treat that as the source of truth and translate roles, never invent colors.

## Recipe

1. Copy the role→hex table from `CLAUDE.md` §Visual Theme into the app's syntax.
2. Open the config with a header comment naming the roles next to the hexes (see `profile/airootfs/etc/skel/.config/waybar/themes/ionix/style.css` for the pattern) — future edits then map colors back to roles.
3. Place the config under `profile/airootfs/etc/skel/.config/<app>/` (skel is copied wholesale; no manifest). If the app also reads a system-wide config under `etc/xdg/`, prefer skel — the kitty precedent shows the two locations fully diverge over time.
4. Any executable helper needs a `file_permissions` entry in `profile/profiledef.sh`.

## Glass convention (floating surfaces)

Surfaces floating over the wallpaper (drawers, launchers, overlays, tooltips) use semi-transparent tints of the deep backgrounds (`#1a1025` / `#0f0a18`), **always paired with an explicit `background-color: transparent`** so the toolkit theme can't paint an opaque layer underneath:

- Heavy glass (panels, bars): 80–90% opacity
- Medium glass (drawers, launchers): 55–65% opacity
- Light glass (tooltips, hover cards): 30–45% opacity

## Per-syntax translation notes

- **GTK3 vs GTK4 are different variable sets — edit both.** GTK3 (`gtk-3.0/gtk.css`) uses `@define-color theme_*_color`; GTK4 (`gtk-4.0/gtk.css`) uses libadwaita names (`accent_*`, `window_*`, `card_*`).
- **kitty**: `colorN` slots plus `background`/`foreground`/`selection_*`; reference `etc/skel/.config/kitty/kitty.conf`.
- **Hyprland Lua/conf**: `rgb(9b59b6)` / `rgba(...)` — no `#` prefix. The active-border gradient is `rgb(9b59b6)` → `rgb(7c3aed)`.
- **Quickshell**: never hardcode — go through `config/Theme.qml` tokens or a styler `theme.json`.
- **GRUB/syslinux**: `boot/grub/themes/ionix/theme.txt` keys and `profile/syslinux/archiso_head.cfg` menu colors.

## Making it switchable (styler integration)

The styler lives at `profile/airootfs/usr/local/share/ionix/styler/`. `ionixtheme <theme>` sources `install-default`, then runs each `ionix_install_<section>` function **only if `themes/<theme>/<section>/` exists** — the function name must match the directory name. To add an app:

1. Add `themes/<theme>/<app>/` with the themed files for **all three** themes: `ionix`, `ionix-pro`, `winix`. A theme missing the directory simply skips that section.
2. Add `ionix_install_<app>` and `ionix_uninstall_<app>` to `styler/install-default`, following the existing functions: symlink theme files into `~/.config/...`, then nudge a live reload (precedents: `killall -SIGUSR2 waybar`, `qs -c ionix ipc call theme reload`, `hyprctl reload`).
3. `ionixtheme` uninstalls the previous theme before installing, so the uninstall function must remove exactly what install created.
