# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ionix is a custom Arch Linux distribution built with **archiso**. It produces a bootable live/installer ISO featuring **Hyprland** (Wayland compositor) as its desktop environment and **Calamares** as the graphical installer. The project is entirely shell scripts, configuration files, and archiso profile definitions — there is no application source code.

## Build Commands

```bash
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
```

**Native build dependencies:**
```bash
sudo pacman -S --needed --noconfirm meson python cmake extra-cmake-modules rust go cargo base-devel git nodejs npm gobject-introspection archiso
sudo python -m pip install meson setuptools
```

Python 3.14 must be installed for `gobject-introspection` compatibility but does not need to be the system default.

There are no automated tests, linters, or CI pipelines. Testing is done manually via QEMU.

## Build Pipeline (build.sh)

1. **Step 1/4** — Builds ~35 AUR packages via `aur/build-aur.sh` into `localrepo/`
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
- **`assets/`** — SVG branding assets (wallpaper, logo) converted to PNG at build time
- **`includes/`** — Pre-built package cache (calamares)

### Key Architectural Patterns

**Local AUR repository:** AUR packages are pre-built into a local pacman repo (`localrepo/`) that is injected into `pacman.conf` as the `[ionix]` repo, avoiding AUR helpers during the ISO build.

**Layered Hyprland config:** System defaults live in `profile/airootfs/etc/hypr/hyprland.conf`, user config in `profile/airootfs/etc/skel/.config/hypr/hyprland.conf` which sources the system config, then loads `ionix-shell.conf`, then allows user overrides.

**Installer flow:** Calamares runs its module sequence, ending with `ionix-post-install` (via shellprocess), which configures the installed system: sets fish as default shell, enables systemd services, handles NVIDIA detection, installs GRUB.

**First-login setup:** `ionix-first-login` is a marker-file-based one-time script that runs on first Hyprland session (e.g., clones NvChad config for neovim).

**SVG asset pipeline:** Branding is stored as SVG in `assets/` and converted to PNG at build time. Generated PNGs are gitignored and cleaned by `clean.sh`.

### Desktop Stack

- **Compositor:** Hyprland (Wayland) managed by UWSM
- **Panel:** HyprPanel (AGS-based)
- **Shell:** ionix-shell (custom AGS/Astal component)
- **Terminal:** kitty (primary), foot, tabby
- **Shell:** fish + oh-my-posh
- **Login flow:** TTY autologin → fish → auto-starts Hyprland via UWSM

### Important Scripts in `profile/airootfs/usr/local/bin/`

- `ionix-install` — Launches the Calamares installer
- `ionix-post-install` — Post-installation system configuration (runs inside chroot)
- `ionix-first-login` — One-time user environment setup
- `ionix-install-bootloader` / `grub-install-ionix` — Bootloader installation
- `ionix-mount-efi` — EFI partition mounting helper

## Working with This Repo

- When adding new packages: edit `profile/packages.x86_64`. AUR packages must also be added to `aur/build-aur.sh` with correct dependency ordering.
- When modifying default user config: edit files under `profile/airootfs/etc/skel/.config/`.
- When modifying system config: edit files under `profile/airootfs/etc/`.
- When adding new scripts: add to `profile/airootfs/usr/local/bin/` and register permissions in `profile/profiledef.sh`'s `file_permissions` array.
- Build output (`out/`, `work/`, `localrepo/`) and generated assets are gitignored.
