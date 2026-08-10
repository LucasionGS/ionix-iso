# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ionix is a custom Arch Linux distribution built with **archiso**. It produces a bootable live/installer ISO featuring **Hyprland** (Wayland compositor) as its desktop environment and **Calamares** as the graphical installer. The project is entirely shell scripts, configuration files, and archiso profile definitions — there is no application source code.

## Build Commands

```bash
# Fetch submodules first (as your normal user — build.sh runs as root and won't):
git submodule update --init --recursive

# Native build (Arch Linux only, requires root):
sudo ./build.sh

# Docker build (any Linux with Docker):
./docker-build.sh [--rebuild-image]

# Clean all build artifacts:
./clean.sh

# Test ISO in QEMU (live environment, boots from ISO):
./test.sh

# Test installed distro in QEMU (boots from disk only):
./test-distro.sh

# Write the built ISO to a USB stick for real hardware:
./flash-usb.sh                      # interactive picker
./flash-usb.sh --list               # just show the disks
./flash-usb.sh --device /dev/sdX --verify
```

`flash-usb.sh` defaults to the newest `out/ionix-*.iso`, refuses the system disk outright, and
requires the target's full device path to be typed back before it writes. It renders its own
progress bar from `dd`'s byte counter (no `pv` dependency) and uses `oflag=direct` so the
percentage tracks bytes actually on the stick rather than bytes parked in the page cache.

**Native build dependencies:**
```bash
sudo pacman -S --needed --noconfirm meson python cmake extra-cmake-modules rust go cargo base-devel git nodejs npm gobject-introspection archiso
sudo python -m pip install meson setuptools
```

Python 3.14 must be installed for `gobject-introspection` compatibility but does not need to be the system default.

There are no automated tests, linters, or CI pipelines. Testing is done manually via QEMU.

## Build Pipeline (build.sh)

1. **Step 1/4** — Builds ~35 AUR packages via `aur/build-aur.sh` into `localrepo/`, then the local
   packages listed in that script's `LOCAL_PACKAGES` array (currently `submodules/ionix-quickshell`)
2. **Step 2/4** — Copies the local repo to `/tmp/ionix-localrepo` for archiso access
3. **Step 3/4** — Converts SVG branding assets (wallpaper, logo) to PNG using `rsvg-convert` or ImageMagick
4. **Step 4/4** — Runs `mkarchiso` against `profile/` to produce the final ISO in `out/`

## Architecture

### Directory Layout

- **`profile/`** — archiso profile (heart of the distro)
  - `airootfs/` — root filesystem overlay that becomes the live ISO's filesystem
  - `packages.x86_64` — full package list for the ISO (official + AUR)
  - `pacman.conf` — pacman config referencing the local `[ionix]` repo
  - `profiledef.sh` — archiso profile definition (boot modes, compression, file permissions)
- **`aur/`** — AUR package build infrastructure; `build-aur.sh` builds packages in dependency order with sentinel files to skip already-built packages
- **`submodules/`** — in-repo sources built into the local pacman repo
  - `ionix-quickshell/` — the desktop shell (QML/Quickshell). Built from the working tree by
    `build-aur.sh`'s `LOCAL_PACKAGES` loop, under the **same package name it is published to the
    AUR as**, `ionix-quickshell-git` (see its `packaging/aur/PKGBUILD`), so the shipped copy is
    upgradable with `yay -Syu`
- **`assets/`** — SVG branding assets (wallpaper, logo) converted to PNG at build time
- **`includes/`** — Pre-built package cache (calamares)

### Key Architectural Patterns

**Local AUR repository:** AUR packages are pre-built into a local pacman repo (`localrepo/`) that is injected into `pacman.conf` as the `[ionix]` repo, avoiding AUR helpers during the ISO build.

**Local packages:** entries in `build-aur.sh`'s `LOCAL_PACKAGES` are built from directories in this repo instead of being cloned from the AUR. They are copied into a scratch dir first (makepkg must never write into a git checkout) and are **always rebuilt** — the sentinel-marker skip used for AUR packages would otherwise hide your own edits. Any previous artifact is deleted first, because the final `repo-add` globs the directory and two versions would make the database entry depend on glob ordering; the names to delete are read back out of each PKGBUILD, since a local package need not build under its directory name.

**Local packages that are also AUR packages:** `ionix-quickshell` builds as `ionix-quickshell-git`, the same name it is published under on the AUR. Since `ionix-post-install` strips the `[ionix]` repo from the installed system, pacman then treats it as a foreign package and `yay -Syu` upgrades it from the AUR normally. This only works while the version *scheme* matches on both sides: `build-aur.sh` writes `r<count>.<shorthash>` of the submodule commit into `.pkgver` in the scratch dir (the copy has no `.git` for a `pkgver()` to read), using the same formula as the submodule's `packaging/aur/aur-publish.sh`. Change one, change the other.

**Layered Hyprland config:** System defaults live in `profile/airootfs/etc/hypr/hyprland.lua`, user config in `profile/airootfs/etc/skel/.config/hypr/hyprland.lua` which loads the system config with `dofile`, then allows user overrides.

**Installer flow:** Calamares runs its module sequence, ending with `ionix-post-install` (via shellprocess), which configures the installed system: sets fish as default shell, enables systemd services, handles NVIDIA detection, installs GRUB.

**First-login setup:** `ionix-first-login` is a marker-file-based one-time script that runs on first Hyprland session (e.g., clones NvChad config for neovim).

**SVG asset pipeline:** Branding is stored as SVG in `assets/` and converted to PNG at build time. Generated PNGs are gitignored and cleaned by `clean.sh`.

### Desktop Stack

- **Compositor:** Hyprland (Wayland) managed by UWSM
- **Panel:** ionix-quickshell (QML/Quickshell) — bar, popouts and OSD. Started by the
  `ionix-quickshell` systemd **user unit** (pre-enabled via the `/etc/skel` symlink), not by
  `exec-once`, so a QML runtime error self-heals via `Restart=on-failure`
- **Panel (fallback):** Waybar is still installed and its themes still ship, but nothing starts it
  automatically. `Ctrl+Super+Shift+B` launches it if the Quickshell bar misbehaves
- **Shell:** ionix-shell (custom AGS/Astal component)
- **Terminal:** kitty (primary), foot, tabby
- **Shell:** fish + oh-my-posh
- **Login flow:** TTY autologin → fish → auto-starts Hyprland via UWSM

### Important Scripts in `profile/airootfs/usr/local/bin/`

- `ionix-install` — Launches the Calamares installer
- `ionix-post-install` — Post-installation system configuration (runs inside chroot)
- `ionix-first-login` — One-time user environment setup
- `grub-install` — PATH-priority wrapper adding `--no-nvram`, so a plain `grub-install` call
  from inside the Calamares chroot does not fail trying to write EFI NVRAM
- `ionix-session-selector` / `ionix-arrange-workspace` — session and workspace helpers

## Visual Theme

Ionix uses a **deep purple/violet dark** theme consistently across all UI surfaces. When styling any component, use these values.

### Core Palette

| Role | Hex | Usage |
|---|---|---|
| Deepest background | `#0f0a18` | Terminal bg, deepest layers |
| Window background | `#1a1025` | Bar, menus, popover backgrounds |
| Card/button background | `#2d2d3f` | Buttons, cards, input fills |
| Hover | `#3a2d50` | Button/item hover state |
| Border / dim | `#4a3d60` | Borders, dividers, dim text |
| Muted foreground | `#6b5f80` | Dim/secondary text, passive icons |
| Primary text | `#c4b5fd` | Default UI text |
| Bright text | `#e2d9f3` | Headings, input text |
| Accent (mid) | `#9b59b6` | Primary accent, sliders, switches |
| Accent (bright) | `#a855f7` | Active items, highlights |
| Accent (light) | `#c084fc` | Icons, labels, glows |

### Semantic Colors

| Role | Hex |
|---|---|
| Success / green | `#2ecc71` |
| Warning / orange | `#f39c12` |
| Error / red | `#e74c3c` |
| Info / cyan | `#48dbfb` |
| Link / blue-purple | `#7c3aed` |

### Glass / Transparency Convention

UI surfaces that float over the wallpaper (drawers, launchers, overlays) should use semi-transparent backgrounds so the wallpaper shows through. Always pair with an explicit `background-color: transparent` to prevent the GTK theme from painting an opaque layer underneath.

- **Heavy glass** (panels, bars): 80–90% opacity
- **Medium glass** (drawers, launchers): 55–65% opacity
- **Light glass** (tooltips, hover cards): 30–45% opacity

Tint using the deep background colors (`#1a1025` / `#0f0a18`) at the appropriate alpha rather than solid fills.

### Wallpaper-adaptive themes

A theme can have its colours derived from the current wallpaper instead of stating them. It opts in
with `export USE_ADAPTIVE_COLORS=true` in its `install` file; `profile/airootfs/usr/local/share/ionix/bin/ionix-adaptive-colors`
then renders its templates against the wallpaper into `~/.config/ionix/adaptive-colors/`, and
`install-default`'s `ionix_theme_file` makes each `ionix_install_<section>` link that instead of the
theme's own file. `ionix-adaptive` is the first such theme; `ionix-adaptive/install` documents every knob.

```
themes/<name>/adaptive/<section>/<file>   # template, tokens below
themes/<name>/<section>/<file>            # MANDATORY static counterpart
```

The static counterpart is not optional: it is what gets installed when there is no wallpaper, no
matugen, or a template that fails to render, and it is what the start menu's theme picker reads for
the preview swatch. Generate it by rendering the template with the base Ionix palette so the two
cannot drift structurally.

Three token forms per slot, because the four consumers want three syntaxes — `{{accent}}` → `#9b59b6`,
`{{accent.raw}}` → `9b59b6` (hyprland's `rgb()`/`rgba()`), `{{accent.rgb}}` → `155,89,182` (GTK CSS).
Alpha belongs in the template (`rgba({{bgDeep.rgb}},0.74)`), not the token. Slots are the eleven
palette roles above plus `accentDeep`, `link`, `shadow`, `green`/`orange`/`red`/`cyan` and `ansi0`–`ansi15`;
a surviving `{{token}}` makes the generator refuse that one file and fall back.

Triggered by `ionix-wallpaper`, `ionix-cycle-wallpaper`, `ionixtheme` and `etc/hypr/scripts/init.sh` —
awww has no hook mechanism. The generator exits 0 silently when the active theme has not opted in, so
those call it unconditionally.

matugen traps, all verified: `--source-color-index 0` is **mandatory** or matugen 4 tries to prompt
for a source colour and hard-fails headless; its `colors.surface*` roles are grey (chroma ~5) and its
`base16` block is a monochrome ramp, so neither is usable — the palette comes from
`palettes.secondary`/`palettes.primary` tones under `-t scheme-content`, which are CIE L\* and so hold
text contrast steady across hues.

## Working with This Repo

- When adding new packages: edit `profile/packages.x86_64`. AUR packages must also be added to `aur/build-aur.sh` with correct dependency ordering.
- When changing the desktop shell: edit `submodules/ionix-quickshell/ionix/**`. Iterate without
  rebuilding the ISO — `make -C submodules/ionix-quickshell dev` symlinks the tree into
  `~/.config/quickshell/ionix`, then `qs -c ionix` runs it and **hot-reloads on save**. Errors
  report as `file:line` in the process output; there is no useful static type check, because
  Quickshell's types aren't on a standard `qmllint` import path, so the runtime is the only checker.
  Remove the symlink to go back to the packaged copy at `/etc/xdg/quickshell/ionix`.
- Quickshell API traps worth knowing: `UPowerDevice.percentage`, `WifiNetwork.signalStrength` and
  `BluetoothDevice.battery` are all **0..1 fractions**, not 0..100. Reading a Pipewire node's
  `audio` requires a `PwObjectTracker` covering it, or it stays null. Hyprland here uses the **Lua**
  config parser, so raw `Hyprland.dispatch("workspace 3")` fails to parse — go through
  `services/Compositor.qml`, which quotes the argument when `Hyprland.usingLua`.
- When changing the styler or a theme: `bin/ionixtheme` and `bin/ionix-adaptive-colors` both hardcode
  `/usr/local/share/ionix`, so to exercise a checkout without installing it, set `IONIX_STYLER_DIR`
  and `IONIX_BIN` at the repo paths (plus `HOME`, `XDG_CONFIG_HOME` and `XDG_CACHE_HOME` at a scratch
  dir — `XDG_CONFIG_HOME` is set on a live Ionix session and will otherwise defeat a fake `HOME`).
- When modifying default user config: edit files under `profile/airootfs/etc/skel/.config/`.
- When modifying system config: edit files under `profile/airootfs/etc/`.
- When adding new scripts: add to `profile/airootfs/usr/local/bin/` and register permissions in `profile/profiledef.sh`'s `file_permissions` array.
- Build output (`out/`, `work/`, `localrepo/`) and generated assets are gitignored.
