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
3. **Step 3/4** — Converts SVG branding assets (wallpaper, logo, Calamares welcome hero) to PNG using `rsvg-convert` or ImageMagick
4. **Step 4/4** — Deletes `work/`, then runs `mkarchiso` against `profile/` to produce the final ISO in `out/`

Rebuilding after a change is cheap as long as you **don't run `clean.sh`**: the AUR packages keep
their `.built-*` sentinels in `localrepo/`, and an already-built package is only reinstalled into
the build container when a package after it in `AUR_PACKAGES` still has to be built. `work/` is
the opposite — it must *not* survive, because mkarchiso skips every stage it finds a marker for
there and would ship the previous airootfs. `docker-build.sh` keeps pacman's download cache in the
`ionix-pacman-cache` volume, so the ~1300 ISO packages are downloaded once, not per build.

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

**Installer flow:** Calamares runs its module sequence, ending with `ionix-post-install` (via shellprocess), which configures the installed system: sets fish as default shell, enables systemd services, handles NVIDIA and fingerprint-reader detection, enables `[multilib]`, installs GRUB. Then `ionix-extras` installs whatever the Software page selected.

**The installer's look lives in `etc/calamares/branding/ionix/`.** `stylesheet.qss` styles every
page Calamares draws in C++; the sidebar and the button bar are QML (`calamares-sidebar.qml`,
`calamares-navigation.qml`, selected by `sidebar: qml`/`navigation: qml` in `branding.desc`); the
install slideshow is `show.qml` (slideshow API 2 — it must `import calamares.slideshow`, without
which the whole file fails and the page is blank). The welcome hero `welcome.png` is rendered from
`assets/calamares-welcome.svg` at build time. Things verified in a live VM:

- **Two pages are Ionix's own**: *Personalize* (theme, bar position) and *Software* (optional
  bundles). Both are instances of the stock `notesqml` module (`instances:` in `settings.conf`,
  configs `modules/ionix-*.conf`) loading `ionix-personalize.qml`/`ionix-software.qml` from the
  branding dir. They hand their choices on through GlobalStorage (`import io.calamares.core` →
  `Global.insert`) as `ionixTheme`, `ionixBar`, `ionixAutologin` and `ionixExtras`, which
  `shellprocess.conf` expands as `${gs[key]}`. A `${gs[key]}` whose key is missing fails the
  command, so each page writes all its keys as soon as it is created.
- **`GlobalStorage` emits `changed()` while holding its own lock.** Touching `Global` from a
  handler on that signal deadlocks the whole installer at startup — defer with `Qt.callLater`.
- **A QML page cannot be transparent**: Calamares clears it to white. The pages paint `#150d20`,
  the same flat colour as `#mainApp` in the stylesheet; a gradient on either shows the page's inset
  rectangle as a box.
- `users.conf` needs `displayAutologin: true`, or the "log in automatically" box is never shown.
  Ionix autologins on tty1 regardless and opens the session behind `ionix-lock`, so that lock *is*
  the password prompt; ticking the box makes `ionix-post-install` drop
  `/etc/ionix/skip-session-lock`, which `init.sh` checks. The users page only sets `autoLoginUser`
  when ticked, so the Personalize page mirrors it into the always-present `ionixAutologin`.
- The chosen theme is only queued (`~/.config/ionix/pending-theme`): `ionixtheme` needs a session,
  so `ionix-first-login` applies it. The bar position is written straight into the shell's
  `settings.json`.
- Hyprland floats the window (`io.calamares.calamares` rule in `hyprland.lua`) at `windowSize`.
- A `modules/welcome.conf` must exist: without one Calamares falls back to its bundled *example*,
  with joke requirement checks (`snark`, `slow-true`) and a KDE donate button.

To iterate on these files without rebuilding, copy them into a running live ISO's `/etc/calamares`
and restart `ionix-install` — but anything under `/usr/local/bin` only reaches an *installed*
system through a rebuilt ISO, because `unpackfs` copies the squashfs, not the running root.

**Optional software is not on the ISO.** GNOME, the gaming stack (Steam, Lutris, Wine,
ProtonUp-Qt…), OBS Studio and Tabby are bundles in `/usr/local/bin/ionix-extras`, which owns their
package lists. Repo packages go through `pacman -Syu` (never `-Sy`: the disk is as old as the ISO);
AUR ones through `yay` as the new user with a temporary pacman-only sudoers rule. It never fails
the install: anything it could not do (offline, a failed build) goes to
`/var/lib/ionix/extras-pending`, `ionix-first-login` says so, and `sudo ionix-extras install` retries.
The bundle ids in `ionix-software.qml` must match the script. GNOME's GRUB entry
(`/etc/grub.d/11_ionix_gnome`) only appears once `gnome-session` exists, so installing GNOME later
re-runs `grub-mkconfig`.

**Fingerprint support is per-machine, decided at install time.** `fprintd` ships on every ISO but is
inert until something asks for it — it is `Type=dbus` with no `[Install]` section, so it is activated
on demand and *cannot* be `systemctl enable`d; don't add it to the service list in `ionix-post-install`.
What varies per machine is only the PAM wiring, which `ionix-post-install` adds via
`ionix-fingerprint enable` when `ionix-fingerprint detect` finds a sensor. Unlike the NVIDIA branch
next to it, the package is **not** removed when detection fails, so a USB reader plugged in later is
one `sudo ionix-fingerprint enable` away.

`ionix-fingerprint` never hardcodes a device list. It matches sysfs against the two tables libfprint
itself installs — `/usr/lib/udev/hwdb.d/60-autosuspend-libfprint-2.hwdb` (426 USB ids, generated by
libfprint's own `fprint-list-udev-hwdb`, with the driver named in the comment above each stanza) and
`/usr/lib/udev/rules.d/70-libfprint-2.rules` (the ACPI-enumerated ElanTech SPI sensors). That is why
detection works inside the installer chroot with no D-Bus and no running fprintd, and why the
supported list stays correct across libfprint updates without this repo changing.

The two auth surfaces are configured by different mechanisms, on purpose:

- **sudo and polkit** go through `pam_fprintd`, inserted as a marker-delimited `auth sufficient`
  block above the existing stack. These are service *names*, not paths: libpam resolves
  `/etc/pam.d/<svc>` before `/usr/lib/pam.d/<svc>`, and modern polkit ships only the vendor copy
  under `/usr/lib`, which pacman owns — so `enable` seeds an `/etc` override from it, and `disable`
  deletes that override again when removing the block would leave a byte-identical copy (otherwise
  the service silently stops tracking its package's updates). `pam_fprintd` only ever sends
  `PAM_TEXT_INFO`, never a dismissable prompt, so there is no way to skip ahead to typing a
  password — hence `timeout=10` rather than the 30-second default.
- **hyprlock** does *not* use PAM for this. It drives fprintd over D-Bus itself
  (`auth:fingerprint` in `/etc/hypr/hyprlock.conf`), so password and finger race each other and the
  text field stays live while a finger is scanned. That is why it is enabled unconditionally for
  every machine: with no reader, `GetDefaultDevice` fails, hyprlock logs a warning and carries on.
  The `ready_message`/`present_message` reach the screen only through `$FPRINTPROMPT`, which
  `placeholder_text` **appends** to the password prompt rather than replacing it — the variable
  resolves to an empty string until a scan actually starts, so a machine without a sensor shows
  exactly what it showed before. hyprlock is now only the **fallback** locker (see below).
- **ionix-lock** gets the same race a third way: two `PamContext`s run side by side, one on
  `lock/pam/password`, one on `lock/pam/fingerprint` (`pam_fprintd`). With no reader or no enrolled
  finger the fingerprint one fails with `PAM_AUTHINFO_UNAVAIL` *without prompting*, and never having
  prompted is how the lock decides there is no reader and stops retrying — so the hint never shows.

**The lock screen is a second Quickshell entry point, run as its own process.**
`submodules/ionix-quickshell/ionix/lock.qml` sits next to `shell.qml`, so `qs.config` resolves to
the shell's own Config/Theme and the lock wears the live theme, but `bin/ionix-lock` starts it with
`qs -p <path>/lock.qml` so a bar crash or hot-reload can never unlock the session. Everything it uses
lives in `ionix/lock/` (`qs.lock`); `lock.qml` must never touch `Notifications` — there is one
notification server per session and it is the bar's. `Player` and `SystemInfo` are safe to run twice.
Things verified the hard way (in a nested Hyprland, `Hyprland -c <conf>` from inside a session):

- `ionix-lock` treats *"the compositor confirmed the lock"* as the only success signal: `lock.qml`
  writes `locked` to `$XDG_RUNTIME_DIR/ionix-lock.state` on `WlSessionLock.secure`. No `locked`
  within 8 s, or the process dying while locked, and it `exec`s **hyprlock** — which can only take
  over a dead lock because `misc.allow_session_lock_restore = true` in `hyprland.lua`. A QML load
  error makes `qs` exit 255, which is caught the same way. `flock` on `ionix-lock.lock` makes a second
  invocation a no-op.
- `Qt.quit()`/`Qt.exit()` have no receiver under Quickshell. `lock.qml` releases the lock and then
  SIGTERMs its own `Quickshell.processId`; the script reads `unlocked` from the state file for the
  exit status.
- The PAM stacks are read in place via `PamContext.configDirectory`, never installed to
  `/etc/pam.d`. The password stack is `pam_unix` alone, not `include login` — that pulls in
  `pam_faillock`, and three typos at a lock screen would lock you out of your own desktop. A PAM
  *error* (as opposed to a failed match) fires `error()` **and then** `completed()`; count it once.
- `ShapePath` in Qt 6.11 has no `strokeGradient`; the avatar ring is an odd-even-filled annulus with
  a `ConicalGradient` fill. A property named `playing` on a `Video` subclass collides with Video's
  own member.
- The background comes from `awww query` per output name (re-read every `interval` so the wallpaper
  cron carries through a long lock). awww's socket is per `WAYLAND_DISPLAY`, so in a nested test
  session it answers nothing and every output borrows the first known picture.
- The video is behind a `Loader` on its own file, so a missing QtMultimedia costs only the video.
  The ISO ships `qt6-multimedia-ffmpeg`; without a backend nothing decodes.

**The calendar is a daemon plus two files, never HTTP in QML.** `submodules/ionix-quickshell/bin/ionix-calendar`
(stdlib-only Python, no msal) is spawned by `services/Calendar.qml` as a child of the shell whenever
`calendar.provider` is not `none` (default `local`), takes commands on stdin (`sync`, `reload`,
`login`, `cancel`, `logout`, and `create`/`update`/`delete` with a JSON payload) and dies on stdin
EOF. The local calendar (`$XDG_DATA_HOME/ionix/calendar/local.json`, simple daily/weekly/monthly/
yearly repeats expanded on wall-clock time) is always present; a remote provider such as Outlook is
layered on top of it, never instead of it, and `phase` in `state.json` describes only the remote.
Events carry `source` and `editable`; the popout's editor opens only on the latter. It writes `state.json` (phase, account, device-code
sign-in, errors) and `events.json` (one provider-neutral event schema) under
`$XDG_STATE_HOME/ionix/quickshell/calendar/`, announcing each write on stdout so the shell re-reads
without trusting inotify on a directory that may not exist yet. The popout, the clock pill's
"next meeting" and the reminders all read those files; a new provider is a `Provider` subclass in
the daemon plus one entry in the settings picker. Outlook goes through Microsoft Graph with the
device-code flow (the tenant's app registration must allow public client flows, and `Calendars.Read`
is not user-consentable in most tenants — an admin grants it once). Tokens go to the keyring via
`secret-tool`, else a 0600 file. Reminders are sent from the shell with `notify-send --action`
(hence `libnotify` in `packages.x86_64`): the shell is the notification server, so the toast lands
in its own centre and the blocked `notify-send` printing `join` is the cue to open the link.

**First-login setup:** `ionix-first-login` is a marker-file-based one-time script that runs on first Hyprland session (e.g., clones NvChad config for neovim).

**SVG asset pipeline:** Branding is stored as SVG in `assets/` and converted to PNG at build time. Generated PNGs are gitignored and cleaned by `clean.sh`.

### Desktop Stack

- **Compositor:** Hyprland (Wayland) managed by UWSM
- **Panel:** ionix-quickshell (QML/Quickshell) — bar, popouts and OSD. Started by the
  `ionix-quickshell` systemd **user unit** (pre-enabled via the `/etc/skel` symlink), not by
  `exec-once`, so a QML runtime error self-heals via `Restart=on-failure`
- **Panel (fallback):** Waybar is still installed and its themes still ship, but nothing starts it
  automatically. `Ctrl+Super+Shift+B` launches it if the Quickshell bar misbehaves
- **Terminal:** kitty (primary), foot, tabby
- **Shell:** fish + oh-my-posh
- **Login flow:** TTY autologin → fish → auto-starts Hyprland via UWSM

### Important Scripts in `profile/airootfs/usr/local/bin/`

- `ionix-install` — Launches the Calamares installer
- `ionix-post-install` — Post-installation system configuration (runs inside chroot)
- `ionix-first-login` — One-time user environment setup
- `ionix-lock` — (from ionix-quickshell, `/usr/bin`) the lock screen; `Super+L`, the power menu and
  the session-start lock in `init.sh` all go through it
- `grub-install` — PATH-priority wrapper adding `--no-nvram`, so a plain `grub-install` call
  from inside the Calamares chroot does not fail trying to write EFI NVRAM
- `ionix-session-selector` / `ionix-arrange-workspace` — session and workspace helpers
- `ionix-fingerprint` — fingerprint reader support; survives onto the installed system
- `ionix-extras` — installs the optional bundles; survives onto the installed system

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

Three token forms per slot, because the five consumers want three syntaxes — `{{accent}}` → `#9b59b6`,
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

### Thunderbird

Themed through `userChrome.css`, which reaches the whole window — `about:3pane` and `about:message`
(folder pane, message list, reading pane) are chrome-privileged and take it. `userContent.css` does
**not** reach them and would restyle every email body instead; don't add one. The theme only
overrides Thunderbird's semantic variables (`--layout-*`, `--selected-item-*`, `--color-surface-*`…),
each with `!important` because a user sheet loses to author sheets otherwise. `ionix_install_thunderbird`
links it as `<profile>/chrome/ionix-theme.css` for every profile in `profiles.ini`, adds one tagged
`@import` to the user's own `userChrome.css` (their rules below it survive switches and win), and sets
`toolkit.legacyUserProfileCustomizations.stylesheets` in a `user.js` marker block. No live reload:
Thunderbird reads it at startup only. Test headless with `xvfb-run` + `GDK_BACKEND=x11` and a scratch
`--profile`. The five theme files are structurally identical, so edit all of them together — and never
write a glob like `--foo-*/bar` inside a CSS comment: the `*/` ends the comment and silently drops the
`:root` block after it.

### Theme options

A theme's `quickshell/theme.json` may declare an `options` array that the start menu's settings page
renders under *Theme options* as switches; each entry's config patch merges just above the theme's
own values and its state is stored per theme in `settings.json`. Only booleans are rendered —
anything genuinely one-of-N belongs in that page's own `settingsGroups` rows instead, where it
applies under every theme rather than only the one that thought to declare it. `bar.position` is the
worked example: a `choices` list on a settings row renders a `Segmented` picker, and because
`settings.json` merges above `theme.json` a theme's own position (winix docks to the bottom) reads as
a default the user's pick then outlives.

**A theme with adaptive colours must put its `options` in the template *and* the static counterpart.**
The generated `theme.json` replaces the static one wholesale, so an option declared only in the
static file disappears the moment a wallpaper is read, and one declared only in the template never
appears without matugen.

## Working with This Repo

- When adding new packages: edit `profile/packages.x86_64`. AUR packages must also be added to `aur/build-aur.sh` with correct dependency ordering.
- When changing the desktop shell: edit `submodules/ionix-quickshell/ionix/**`. Iterate without
  rebuilding the ISO — `make -C submodules/ionix-quickshell dev` symlinks the tree into
  `~/.config/quickshell/ionix`, then `qs -c ionix` runs it and **hot-reloads on save**. Errors
  report as `file:line` in the process output; there is no useful static type check, because
  Quickshell's types aren't on a standard `qmllint` import path, so the runtime is the only checker.
  Remove the symlink to go back to the packaged copy at `/etc/xdg/quickshell/ionix`.
- The bar turns. `bar.position` takes `top`/`bottom`/`left`/`right`, and everything downstream reads
  `Config.barVertical` rather than re-testing the string. Rules that took a while to find, all
  verified at runtime: a **`GridLayout` is the only layout type that turns** — leave `rows`/`columns`
  at their `-1` default and `flow` alone decides row versus column — but **do not swap a Layout's
  anchors between axes**, it keeps the stale pair and collapses to a negative size, so `Bar.qml`
  positions its three sections with `x`/`y` instead. A `Grid` positioner is the same trick for
  ordinary content, and its `horizontalItemAlignment`/`verticalItemAlignment` replace the per-child
  `anchors.verticalCenter` a `Row` needed (children of a `Grid` must not anchor at all). A module
  that hides itself does **not** free its slot: the layout sees the `Loader`, which stays visible, so
  `Bar.qml` collapses `Layout.preferredWidth/Height` — never bind the Loader's own `visible` to
  `item.visible`, which reports *effective* visibility and latches off permanently.
- Quickshell API traps worth knowing: `UPowerDevice.percentage`, `WifiNetwork.signalStrength` and
  `BluetoothDevice.battery` are all **0..1 fractions**, not 0..100. Reading a Pipewire node's
  `audio` requires a `PwObjectTracker` covering it, or it stays null. Hyprland here uses the **Lua**
  config parser, so raw `Hyprland.dispatch("workspace 3")` fails to parse — go through
  `services/Compositor.qml`, which quotes the argument when `Hyprland.usingLua`.
- When changing the styler or a theme: `bin/ionixtheme` and `bin/ionix-adaptive-colors` both hardcode
  `/usr/local/share/ionix`, so to exercise a checkout without installing it, set `IONIX_STYLER_DIR`
  and `IONIX_BIN` at the repo paths (plus `HOME`, `XDG_CONFIG_HOME` and `XDG_CACHE_HOME` at a scratch
  dir — `XDG_CONFIG_HOME` is set on a live Ionix session and will otherwise defeat a fake `HOME`).
- When touching fingerprint support: `ionix-fingerprint` edits `/etc/pam.d/sudo`, which gates sudo,
  so both edit paths are guarded — `enable` refuses to write a file that is not exactly three lines
  longer than the original, and `disable` refuses to write an empty one. Both are idempotent and the
  round trip is byte-identical; keep it that way. Test it without touching your own machine by
  overriding `HWDB`, `SPI_RULES`, `PAM_MODULE`, `PAM_ETC_DIR` and `PAM_VENDOR_DIR` at the top of a
  copy of the script — every path it writes to is one of those.
- When modifying default user config: edit files under `profile/airootfs/etc/skel/.config/`.
- When modifying system config: edit files under `profile/airootfs/etc/`.
- When adding new scripts: add to `profile/airootfs/usr/local/bin/` and register permissions in `profile/profiledef.sh`'s `file_permissions` array.
- Build output (`out/`, `work/`, `localrepo/`) and generated assets are gitignored.
