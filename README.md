<div align="center">

# Ionix

**A modern, gaming-ready Arch Linux distribution powered by Hyprland**

*Beautiful by default. Fast by design. Familiar to use.*

</div>

---

## Overview

Ionix is a custom Arch Linux–based operating system built around the [Hyprland](https://hyprland.org/) Wayland compositor. It ships as a bootable live ISO with a graphical installer (Calamares), giving you a polished, fully configured desktop the moment installation finishes — no post-install configuration required.

Ionix is designed for developers, power users, and gamers who want the bleeding-edge rolling-release Arch ecosystem without spending hours assembling a desktop from scratch.

---

## Features at a Glance

| Category | What's Included |
|---|---|
| **Desktop** | Hyprland (Wayland), ionix-quickshell bar, ionix-shell command palette |
| **Shell** | Fish + oh-my-posh prompt, NvChad for Neovim (auto-configured on first login) |
| **Terminals** | kitty (primary), foot, Tabby |
| **Browser** | Google Chrome |
| **Files** | Nemo file manager with context-menu integration |
| **Gaming** | Steam, GameMode, MangoHud, Gamescope, Lutris, OBS Studio, Wine (Staging) |
| **Audio** | PipeWire (with PulseAudio + JACK compatibility) |
| **Bluetooth** | BlueZ + Blueman |
| **GPU** | AMD, Intel, NVIDIA (auto-detected and configured during install) |
| **Installer** | Calamares graphical installer, auto-launched on boot |

---

## Desktop Environment

Ionix uses **Hyprland** — a dynamic tiling Wayland compositor with smooth animations, rounded corners, and blur effects out of the box.

### Visual Style

- Rounded window corners (12 px rounding)
- Background blur and drop shadows
- Purple-accented window borders
- Dark GTK and icon theme (Adwaita Dark / Papirus-Dark)
- Animated workspace transitions

### Panel & Shell

- **ionix-quickshell** — the status bar, written in QML on [Quickshell](https://quickshell.org). Floating, blurred and rounded, with workspaces, a window taskbar, media controls, system tray, and audio / network / bluetooth / battery indicators. Clicking an indicator opens an in-shell panel rather than launching a separate app: a calendar, an audio mixer with per-application volume sliders, a Wi-Fi picker with inline password entry, a bluetooth manager, a media player, and a power menu. Volume and brightness get an on-screen display.
  - Configure it with `~/.config/quickshell/ionix/config.json` — changes apply live, no restart. See `/etc/xdg/quickshell/ionix/defaults.json` for every key.
  - Restart it with `Super+Shift+B`.
  - Shipped as a git submodule and published to the AUR as `ionix-quickshell-git`, so it updates independently of ISO releases.
- **Waybar** — still installed as a fallback, but no longer started automatically. Run `waybar` from a terminal (or `Ctrl+Super+Shift+B`) if you need it.
- **ionix-shell** — custom AGS/Astal component providing a command palette (`Super+R`) and an `Alt+Tab` window switcher

### Screen Lock

- **hyprlock** — lockscreen triggered with `Super+L` or on idle via hypridle

### App Launcher

- **Walker** — icon-based application drawer (`Super+R or SUPER_L`)

### Login Flow

The system auto-logs in to a TTY on boot, starts the Fish shell, and launches Hyprland via UWSM automatically — no display manager required.

---

## Pre-installed Applications

### Productivity & Development

| App | Purpose |
|---|---|
| **Neovim** + NvChad | Modal text editor, auto-configured on first login |
| **kitty** | GPU-accelerated terminal (with transparency) |
| **foot** | Lightweight Wayland terminal (also runs as a server for fast launches) |
| **Tabby** | Feature-rich tabbed terminal (`Ctrl+Alt+T`) |
| **Fish** | User-friendly shell with syntax highlighting and autocompletion |
| **oh-my-posh** | Cross-shell prompt engine with the Ionix theme |
| **btop** | Resource monitor |
| **fastfetch** | System information display |
| **yay** | AUR helper |

### Internet & Communication

| App | Purpose |
|---|---|
| **Google Chrome** | Primary web browser |
| **NetworkManager** | Network management with GUI (`nm-connection-editor`) |
| **openconnect-sso** | VPN client with SSO support |

### Gaming

| App | Purpose |
|---|---|
| **Steam** | Game library and launcher |
| **Lutris** | Game manager for non-Steam titles |
| **Wine (Staging)** | Windows compatibility layer + winetricks |
| **ProtonUp-Qt** | Manage Proton and Wine-GE versions |
| **GameMode** | CPU/GPU performance governor during gameplay |
| **MangoHud** | In-game performance overlay |
| **Gamescope** | Micro-compositor for resolution scaling and frame limiting |
| **OBS Studio** | Screen recording and streaming |
| **AntiMicroX** | Gamepad-to-keyboard/mouse mapper |

### System Utilities

| App | Purpose |
|---|---|
| **CopyQ** | Clipboard manager with history (`Super+V`) |
| **Blueman** | Bluetooth GUI |
| **pavucontrol** | PipeWire/PulseAudio volume control |
| **nwg-displays** | Multi-monitor layout manager |
| **hyprpicker** | Color picker |
| **hyprshot** | Screenshot tool |
| **Docker** | Container runtime |

---

## Gaming Optimizations

Ionix ships SteamOS-inspired kernel tweaks for improved in-game performance:

- `vm.max_map_count = 2147483642` — required by many Proton/Wine titles
- Split-lock mitigation disabled — prevents frame drops in older games
- Reduced memory compaction stalls
- Increased UDP receive buffers for online play
- Raised file descriptor limits (`524288`) for heavily-modded games
- **ananicy-cpp** — automatic CPU priority management for games and background tasks

---

## Key Bindings

> **`$mainMod` = Super (Windows key)**

### Applications

| Shortcut | Action |
|---|---|
| `Super+T` | Open kitty terminal |
| `Ctrl+Alt+T` | Open Tabby terminal |
| `Super+W` | Open Google Chrome |
| `Super+E` | Open Nemo file manager |
| `Super+B` | Open btop system monitor |
| `Super+R` | Toggle nwg-drawer app drawer |
| `Alt+Space` | Open ionix-shell command palette |
| `Super+V` | Toggle CopyQ clipboard manager |
| `Super+L` | Lock screen |
| `Ctrl+Super+R` | Reload Hyprland config |

### Screenshots

| Shortcut | Action |
|---|---|
| `Print` | Area screenshot → clipboard |
| `Ctrl+Print` | Full screen screenshot → clipboard |
| `Super+Print` | Area screenshot → `~/Pictures/` |
| `Shift+Print` | Active monitor screenshot → clipboard |

### Window Management

| Shortcut | Action |
|---|---|
| `Super+Q` | Close active window |
| `Super+Space` | Toggle floating |
| `Super+F` | Fullscreen |
| `Super+Arrow keys` | Move focus |
| `Super+Shift+Arrow keys` | Move window |
| `Super+Alt+Arrow keys` | Resize window |
| `Super+G` | Toggle window group |
| `Super+P` | Pin window (always on top) |
| `Alt+Tab` / `Shift+Alt+Tab` | Cycle through windows |

### Workspaces

| Shortcut | Action |
|---|---|
| `Super+1`…`0` | Switch to workspace 1–10 |
| `Ctrl+Super+Right/Left` | Next/previous workspace |
| `Super+Alt+1`…`0` | Move window to workspace (silent) |
| `Super+S` | Toggle scratchpad workspace |

### Media Keys

| Shortcut | Action |
|---|---|
| `XF86AudioRaiseVolume` | Volume up |
| `XF86AudioLowerVolume` | Volume down |
| `XF86AudioMute` | Toggle mute |
| `XF86AudioPlay` | Play/pause |
| `XF86AudioNext/Prev` | Next/previous track |
| `XF86MonBrightnessUp/Down` | Screen brightness |

---

## Installation

1. **Download** the Ionix ISO (or [build it yourself](#building-ionix)).
2. **Boot** from the ISO (USB drive or DVD).
3. The live session logs in automatically. **Click the installer icon** on the desktop or run `ionix-install` in a terminal.
4. Follow the **Calamares** graphical installer — choose your language, timezone, keyboard layout, partition scheme, and create your user account.
5. After installation completes, **reboot** and remove the installation media.

### Post-Installation (Automatic)

When you first log in, Ionix automatically:

- Sets Fish as the default shell for your user
- Clones the NvChad starter config for Neovim
- Sets up standard XDG user directories
- Applies the dark theme for GTK and portal-aware apps

### NVIDIA GPUs

NVIDIA is detected automatically during installation. If an NVIDIA GPU is found:

- DRM modesetting is enabled (`nvidia_drm modeset=1 fbdev=1`)
- NVIDIA kernel modules are injected into the initramfs for early loading
- The `nvidia-open` driver is pre-installed

If no NVIDIA GPU is found, the NVIDIA packages are removed to save disk space.

### Secure Boot

Ionix includes `shim-signed`, `sbctl`, and `mokutil` for Secure Boot support. Manual enrollment of your own keys via `sbctl` is possible after installation.

---

## Customizing Hyprland

User configuration lives in `~/.config/hypr/hyprland.lua`. This file loads the system defaults from `/etc/hypr/hyprland.lua` first, so you only need to add overrides:

```lua
# Example: change keyboard layout to US
hl.config({ input = { kb_layout = "us" } })

# Example: add a custom keybinding
hl.bind(mainMod .. " + code:60", hl.dsp.exec_cmd("yourapp"))
```

Monitor layout can be managed by adding `hl.monitor({ ... })` rules to `~/.config/hypr/hyprland.lua`.

---

## Building Ionix

> This section is intended for developers who want to compile the ISO from source.

### Prerequisites

Ionix can be built **natively on Arch Linux** (requires root) or **inside Docker** on any Linux host.

#### Submodules

`ionix-quickshell` (the desktop shell) is a git submodule and is built into the ISO from the
working tree. Fetch it before building — as your normal user, not root:

```bash
git submodule update --init --recursive
```

`docker-build.sh` does this for you. `build.sh` will not, because it runs as root and git refuses
to touch a checkout owned by someone else; it fails with this instruction instead.

#### Native Build Dependencies

```bash
sudo pacman -S --needed --noconfirm \
    archiso base-devel git \
    meson cmake extra-cmake-modules \
    python nodejs npm \
    rust go cargo \
    gobject-introspection
```

Install Python build tools:

```bash
sudo python -m ensurepip   # if pip is not already available
sudo python -m pip install meson setuptools
```

> **Python 3.14 note:** `gobject-introspection` from the Arch repos is compiled against Python 3.14.
> Python 3.14 must be present at `/usr/bin/python3.14` but does **not** need to be the system default.
> The build script selects the correct Python automatically.

### Build with Docker (Recommended for non-Arch hosts)

Any Linux machine with Docker installed can build the ISO without an Arch system:

```bash
# Build the ISO (builds the Docker image on first run)
./docker-build.sh

# Force a rebuild of the Docker image
./docker-build.sh --rebuild-image
```

The ISO is written to `./out/`.

### Native Build (Arch Linux only)

```bash
sudo ./build.sh
```

The build proceeds in four steps:

1. **AUR packages** — ~35 AUR packages (including ionix-shell, Calamares, etc.) are compiled into a local `localrepo/` pacman repository.
2. **Local repo** — the local repo is staged at `/tmp/ionix-localrepo` for use by archiso.
3. **Branding assets** — SVG wallpaper and logo are rasterised to PNG with `rsvg-convert` (or ImageMagick as a fallback).
4. **ISO assembly** — `mkarchiso` builds the final squashfs-compressed ISO in `./out/`.

### Testing the ISO

**Test the live environment** (boots from ISO):

```bash
./test.sh
```

**Test the installed system** (boots from a virtual disk):

```bash
./test-distro.sh
```

Both scripts use QEMU with KVM, OVMF (UEFI firmware), and `virtio-vga-gl` for GPU acceleration. A 64 GB `qcow2` virtual disk (`ionix-test.qcow2`) is created automatically on first run.

### Cleaning Build Artifacts

```bash
./clean.sh
```

This removes `out/`, `work/`, `localrepo/`, and any generated PNG assets.

### Repository Layout

```
ionix-iso/
├── assets/               # SVG branding (wallpaper, logo) — converted to PNG at build time
├── aur/
│   └── build-aur.sh      # Builds AUR packages into localrepo/ in dependency order
├── includes/             # Pre-built Calamares package cache
├── profile/              # archiso profile
│   ├── airootfs/         # Root filesystem overlay (becomes the live ISO's filesystem)
│   │   ├── etc/          # System configuration (hyprland, calamares, fish, etc.)
│   │   └── usr/local/bin/# Ionix scripts (ionix-install, ionix-post-install, ...)
│   ├── packages.x86_64   # Full package list (official repos + local AUR repo)
│   ├── pacman.conf       # pacman config referencing the local [ionix] repo
│   └── profiledef.sh     # archiso profile definition
├── build.sh              # Main build entry point (run as root)
├── docker-build.sh       # Docker wrapper for build.sh
├── clean.sh              # Remove all build artifacts
├── test.sh               # Boot ISO in QEMU
└── test-distro.sh        # Boot installed disk image in QEMU
```
