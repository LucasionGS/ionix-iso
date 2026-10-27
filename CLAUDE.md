# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ionix is a custom Arch Linux distribution built with **archiso**, in two variants. The **desktop** ISO is a live/installer featuring **Hyprland** (Wayland compositor) as its desktop environment and **Calamares** as the graphical installer. The **server** ISO is headless: the same shell, tools and themes, installed from the console, over SSH or unattended by `ionix-server-install` (see "Ionix Server" below). The project is entirely shell scripts, configuration files, and archiso profile definitions — there is no application source code.

## Build Commands

```bash
# Fetch submodules first (as your normal user — build.sh runs as root and won't):
git submodule update --init --recursive

# Native build (Arch Linux only, requires root):
sudo ./build.sh [--variant desktop|server] [--answers FILE]

# Docker build (any Linux with Docker):
./docker-build.sh [--rebuild-image] [--variant desktop|server] [--answers FILE]

# Clean all build artifacts:
./clean.sh

# Test ISO in QEMU (live environment, boots from ISO; newest desktop ISO by default):
./test.sh [out/ionix-server-*.iso]

# Test installed distro in QEMU (boots from disk only):
./test-distro.sh [server]

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

1. **Step 1/5** — Stages the profile: `profiles/common/` copied to `staging/<variant>/`, the variant's
   directory laid over it (same path replaces), `packages.x86_64` and `profiledef.sh` concatenated
   common-first instead. `--answers` adds `/etc/ionix/install.conf` (mode 600) here
2. **Step 2/5** — Builds the AUR packages via `aur/build-aur.sh` into `localrepo/`, then the local
   packages listed in that script's `LOCAL_PACKAGES` array (currently `submodules/ionix-quickshell`,
   `system` and `aur/local/shim-signed`) — but only those the staged package list names
3. **Step 3/5** — Copies the local repo to `/tmp/ionix-localrepo` for archiso access
4. **Step 4/5** — Renders the installer's own branding (Calamares logo and welcome hero, desktop
   only) with `rsvg-convert` **into the staged profile** — a build never writes to the source
   tree. The wallpaper, logo and GRUB theme logo are rendered by `system/Makefile` instead
5. **Step 5/5** — Deletes `work/`, then runs `mkarchiso` against the staged profile to produce
   `out/ionix-<date>-x86_64.iso` or `out/ionix-server-<date>-x86_64.iso`

Rebuilding after a change is cheap as long as you **don't run `clean.sh`**: the AUR packages keep
their `.built-*` sentinels in `localrepo/`, and an already-built package is only reinstalled into
the build container when a package after it in `AUR_PACKAGES` still has to be built. `work/` is
the opposite — it must *not* survive, because mkarchiso skips every stage it finds a marker for
there and would ship the previous airootfs. `docker-build.sh` keeps pacman's download cache in the
`ionix-pacman-cache` volume, so the ~1300 ISO packages are downloaded once, not per build.

## Architecture

### Directory Layout

- **`system/`** — Ionix's own files as packages, laid out as installed: `base/` →
  `ionix-base-git` (fish and the skel shell config, the styler and every theme,
  `ionix-console-theme`, `ionix-migrate`, the GRUB theme), `desktop/` → `ionix-desktop-git`
  (Hyprland's system config, the desktop's scripts and skel, the wallpaper), `server/` →
  `ionix-server-git` (`ionix-server-firstboot`). See "Ionix system packages" below and
  `system/README.md`
  - `etc/ionix/variant` (`desktop`/`server`, in the variant package) says which one a machine
    was installed from; `patch-os.sh` reads it, defaulting to desktop
- **`profiles/`** — the archiso profile, in layers `build.sh` merges. Its `airootfs/` holds only
  what is not the same file on every installed system: live-medium, installer, per-machine, and
  files another package owns
  - `common/` — both variants: `ionix-post-install` (base), archiso's live units and hooks,
    shared syslinux files, `pacman.conf`, `bootstrap_packages`, and the first half of
    `packages.x86_64`/`profiledef.sh`
  - `desktop/` — Calamares, `post-install.d/10-desktop`, liveuser, `/etc/default/grub`,
    greetd's config, `linux` boot entries
  - `server/` — `ionix-server-install`, kmscon.conf, sshd/networkd live setup,
    `post-install.d/10-server`, `linux-lts` boot entries (with serial-console ones)
  - in each: `airootfs/` (root filesystem overlay), `packages.x86_64`, `profiledef.sh`
    (`file_permissions+=(...)` in a variant), `efiboot/`/`grub/`/`syslinux/` where they differ
- **`aur/`** — AUR package build infrastructure; `build-aur.sh` builds packages in dependency order with sentinel files to skip already-built packages
- **`submodules/`** — in-repo sources built into the local pacman repo
  - `ionix-quickshell/` — the desktop shell (QML/Quickshell). Built from the working tree by
    `build-aur.sh`'s `LOCAL_PACKAGES` loop, under the **same package name it is published to the
    AUR as**, `ionix-quickshell-git` (see its `packaging/aur/PKGBUILD`), so the shipped copy is
    upgradable with `yay -Syu`
- **`assets/`** — the installer's SVG branding (Calamares welcome hero), converted to PNG at build
  time; the wallpaper and logo SVGs are in `system/assets/`
- **`includes/`** — Pre-built package cache (calamares)

### Key Architectural Patterns

**Local AUR repository:** AUR packages are pre-built into a local pacman repo (`localrepo/`) that is injected into `pacman.conf` as the `[ionix]` repo, avoiding AUR helpers during the ISO build.

**Local packages:** entries in `build-aur.sh`'s `LOCAL_PACKAGES` are built from directories in this repo instead of being cloned from the AUR. They are copied into a scratch dir first (makepkg must never write into a git checkout) and are **always rebuilt** — the sentinel-marker skip used for AUR packages would otherwise hide your own edits. Any previous artifact is deleted first, because the final `repo-add` globs the directory and two versions would make the database entry depend on glob ordering; the names to delete are read back out of each PKGBUILD, since a local package need not build under its directory name.

**Local packages that are also AUR packages:** `ionix-quickshell` builds as `ionix-quickshell-git`
(and `system/` as `ionix-{base,desktop,server}-git`, below), the same name it is published under on the AUR. Since `ionix-post-install` strips the `[ionix]` repo from the installed system, pacman then treats it as a foreign package and `yay -Syu` upgrades it from the AUR normally. This only works while the version *scheme* matches on both sides: `build-aur.sh` writes `r<count>.<shorthash>` of the submodule commit into `.pkgver` in the scratch dir (the copy has no `.git` for a `pkgver()` to read), using the same formula as the submodule's `packaging/aur/aur-publish.sh`. Change one, change the other.

**Ionix system packages:** an installed system keeps up with this repository through pacman.
Everything of Ionix's own that every installed system should have is in `system/`, built into
`ionix-base-git` + `ionix-desktop-git`/`ionix-server-git` (one split package) and installed on the
ISO like any other package. `system/PKGBUILD` builds from the working tree for the ISO;
`system/packaging/aur/PKGBUILD` is the same recipe fetching `system/` from the public GitHub repo,
published by `aur-publish.sh`. Their version is `r<count>.<hash>` of the commits touching
`system/` only, so an ISO-only change is not an upgrade — the formula is in both PKGBUILDs,
`aur-publish.sh` and `build-aur.sh`. Nothing is installed under `/usr/local` (the admin's): scripts are in
`/usr/bin`, data in `/usr/share/ionix`. Rules that follow from pacman, all checked:

- every regular file under `/etc` goes into `backup=()` (computed in `_etc_backup`). An edited one is
  kept and the new one written as `.pacnew` — also on a first install over an unowned copy, which
  is how `patch-os.sh` adopts a system installed before the packages existed (`--overwrite` for
  exactly the packaged paths, then a diff walk over the `.pacnew`s);
- a file another package owns (`/etc/default/grub`, `/etc/greetd/config.toml`, `/etc/locale.gen`)
  or one written per machine (`kmscon.conf`) cannot be packaged — it stays in the airootfs, and
  an update that must change it is a migration;
- changes that are not files are **migrations**, `NNN-name` executables run once by
  `ionix-migrate`: `migrations/system/` from a pacman hook after every ionix-base install or
  upgrade (an ISO build runs them all too, on a fresh root, so each must be a no-op there),
  `migrations/user/` at login (fish's `ionix.fish` and the desktop's `init.sh`). `001-usr-local-to-usr`
  moves an older install's `/usr/local` copies aside to `/var/lib/ionix/pre-package/`;
- `ionix-migrate system` also keeps `/usr/local/share/ionix/<name>` linked to
  `/usr/share/ionix/<name>`, on every system including fresh ones: user homes (theme symlinks,
  crontabs) and the shell's `Config.qml`/`LockMedia.qml`/`ionix-greeter` still name the old path;
- GRUB's copy in `/boot/grub/themes/ionix` is refreshed by the `ionix-grub-theme` pacman hook,
  only where that directory already exists.

**Layered profile:** a file belongs in `common/` only if *both* ISOs want it as is; anything a
variant would override goes in each variant instead (`loader.conf`, `etc/default/grub`,
`hostname`, `motd`, `passwd`…), so `common/` never quietly carries desktop values. The same goes
for `system/base` against `system/desktop`/`server`, which are separate packages and so must
never ship the same path. The skel `config.fish` is in base; the desktop's tty1 `uwsm start`,
keyring `SSH_AUTH_SOCK` (which would break agent forwarding on a server), `TERMINAL` and `BROWSER`
live in the desktop's `skel/.config/fish/conf.d/ionix-desktop.fish`, which conf.d runs before
config.fish as before.

**Layered Hyprland config:** System defaults live in `system/desktop/etc/hypr/hyprland.lua`, user config in `system/desktop/etc/skel/.config/hypr/hyprland.lua` which loads the system config with `dofile`, then allows user overrides.

**Post-install is a base plus hooks.** `ionix-post-install` (common) does what turning any copy of
the live medium into an installed system takes: live-artefact cleanup, each kernel in
`/usr/lib/modules/*/pkgbase` copied to `/boot` with a standard preset, then every executable in
`/usr/local/share/ionix/post-install.d/` in name order, then **one** `mkinitcpio -P` (so a hook
may edit `mkinitcpio.conf` — the desktop's NVIDIA `MODULES`, the server's `HOOKS`), the keyring,
sudoers. Hooks get the installer's `IONIX_*` environment and `NEWUSER`. It also copies the GRUB
theme from `/usr/share/ionix/grub-theme` to `/boot/grub/themes/ionix`: mkarchiso deletes
everything under the image's `/boot` (`_cleanup_pacstrap_dir`), so a theme kept in
`airootfs/boot/` never reached an installed system and GRUB quietly fell back to its plain menu.

**Installer flow:** Calamares runs its module sequence, ending with `ionix-post-install` (via shellprocess), whose `10-desktop` hook configures the installed desktop: login mode, keyring PAM, theme/bar, `[multilib]`, services, NVIDIA and fingerprint-reader detection. Then shellprocess installs GRUB and `ionix-extras` installs whatever the Software page selected.

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
  The same goes for every module in `settings.conf`: `initcpiocfg`'s example adds a hook named
  `bogus`. Give each module its own file under `modules/`.
- **Full-disk encryption** ("Encrypt system" on the partition page) puts `/boot` inside the LUKS
  root — only the ESP is separate — so GRUB itself unlocks the disk. That takes four stock modules
  in the exec sequence: `luksbootkeyfile` (adds `/crypto_keyfile.bin` so the passphrase is asked
  once, by GRUB, not again by the initramfs), `luksopenswaphookcfg`, `initcpiocfg` (busybox
  `encrypt` hook — `useSystemdHook: false`, because `grubcfg` writes `cryptdevice=`, which
  `sd-encrypt` ignores) and `grubcfg`, which must run **before** `shellprocess` so
  `GRUB_ENABLE_CRYPTODISK=y` is set when `grub-install` runs, and whose `kernel_params` must repeat
  Ionix's own (`quiet loglevel=3`). `partition.conf` pins `luksGeneration: luks1`: GRUB
  cannot open LUKS2's default argon2. `ionix-post-install` builds the images with `mkinitcpio -P`
  only after deleting archiso's `mkinitcpio.conf.d` override, which is what lets these hooks apply.
- archiso's `journald.conf.d/volatile-storage.conf` rides along into the target with the rest of
  the squashfs; `ionix-post-install` deletes it, or an installed system loses every log on reboot.
- `etc/locale.gen` must stay glibc's **full** commented list: `localecfg` enables the chosen
  locales by uncommenting their lines, so archiso's one-line file meant nothing but `en_US` was
  ever generated and every program on the installed system logged "Locale not supported by C library".
- `mount.conf`'s `options` must be YAML lists (`[ bind ]`). A bare `bind` is split into
  `-o b,i,n,d`, the bind mount of `/dev` fails silently, and anything that needs a device inside
  the target — `luksbootkeyfile` did — fails with it.
- `umount` must stay the last exec module. Without it the target is left mounted after "All
  done" with its final writes still cached; powering off there (rather than pressing Restart)
  leaves ext4 files such as `/boot/grub/grub.cfg` zero-length, and the machine boots to a bare
  `grub>` prompt. Found by force-quitting the test VM right after an install.
- If Calamares is killed after an install, its target stays mounted and the LUKS volume open; the
  partition page then offers only manual partitioning. `umount -R /tmp/calamares-root-*` and
  `cryptsetup close` it before retrying.

To iterate on these files without rebuilding, copy them into a running live ISO's `/etc/calamares`
and restart `ionix-install` — but the scripts the install runs (`ionix-post-install`, its hooks,
the packaged ones) only reach an *installed* system through a rebuilt ISO, because `unpackfs`
copies the squashfs, not the running root.

**Optional software is not on the ISO.** The gaming stack (Steam, Lutris, Wine,
ProtonUp-Qt…), OBS Studio and Tabby are bundles in `/usr/bin/ionix-extras`, which owns their
package lists. Repo packages go through `pacman -Syu` (never `-Sy`: the disk is as old as the ISO);
AUR ones through `yay` as the new user with a temporary pacman-only sudoers rule. It never fails
the install: anything it could not do (offline, a failed build) goes to
`/var/lib/ionix/extras-pending`, `ionix-first-login` says so, and `sudo ionix-extras install` retries.
The bundle ids in `ionix-software.qml` must match the script. GNOME support was dropped (2026.09): no
bundle, no boot entry, no session branch in fish. What stays is what GTK apps under Hyprland read —
`gnome-keyring`, `gnome-themes-extra` (Adwaita-dark) and the `org.gnome.desktop.interface` keys that
`ionix-first-login` loads from `/usr/share/ionix/gtk-defaults.dconf`.

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

**The login greeter is the lock screen with a username field, run under cage by greetd.**
`ionix-login-mode greeter|autologin|locked` picks how an *installed* machine starts (the live ISO
always autologins as `liveuser`): `greeter` enables `greetd` (`/etc/greetd/config.toml` runs
`cage -s -- ionix-greeter`), `autologin` and `locked` are the tty1 autologin flows, without and with
the session-start `ionix-lock`. `ionix-post-install` picks `autologin` when the users page box is
ticked and `greeter` otherwise. Modes are recorded in `/etc/ionix/login-mode`; `skip-session-lock` stays
what `init.sh` reads. GRUB has a single "Ionix" entry and the kernel
command line no longer carries `ionix.desktop=`; choosing a session is meant to move into the greeter.

- `greeter.qml` (third entry point, next to `shell.qml`/`lock.qml`) hosts `lock/LockView.qml` — the
  body of the old `LockSurface`, now a plain Item — in one ordinary `FloatingWindow`: cage has no
  ext-session-lock and shows one window. `LockSurface` is now a thin `WlSessionLockSurface` around it.
- Greeter behaviour is `LockState.greeter` (`IONIX_GREETER=1`, set by `bin/ionix-greeter`). Password
  checking moves to greetd in `lock/GreeterBackend.qml`, **loaded through a `Loader` only there** so
  the lock still works on a Quickshell built without `Quickshell.Services.Greetd`. It opens a greetd
  session as soon as a username exists (not at Enter), so `pam_fprintd` in `/etc/pam.d/greetd`
  (`ionix-fingerprint enable` wires it) listens immediately; the password prompt is answered once Enter
  has been pressed. Cost: with a sensor and an enrolled finger, a password typed during the 10 s
  fingerprint window waits for it to time out. Editing the username cancels the session and opens
  another (debounced).
- **Quickshell's `Greetd` (0.3.1) pairs greetd's replies by its current state, not by request.** Every
  `cancel_session` — including the one it sends itself after a wrong password — gets a `success`
  reply, and if a new session is already `Authenticating` when it lands, that is read as "password
  accepted": `readyToLaunch` fires, and the next stray `success` even reads as "session launched",
  so the greeter quits with nobody logged in. A wrong password logged "in" this way until
  `GreeterBackend` learned to open sessions only after a `settle` delay, to believe `readyToLaunch`
  only if the session answered its prompt or saw a fingerprint message, and never to call `Greetd`
  from inside its own signals (it emits `authFailure` before resetting itself).
- Under greetd the greeter's stdout is discarded, so `ionix-greeter` sends it to the journal with
  greetd debug on: `journalctl -t ionix-greeter` (add `-b -1` for a previous boot).
- Keys go to the password buffer by default; the username `TextInput` takes them only while
  `LockState.usernameEditing` (click it, or Tab/Up; Enter/Tab/Down hands back). No screensaver in the greeter.
- `IONIX_GREETER_DRY=1` skips greetd: PAM (`lock/pam/password`, with `PamContext.user`) checks the
  typed user's password and nothing launches. Try it from a session with
  `IONIX_GREETER_DRY=1 IONIX_GREETER_ENTRY=<checkout>/ionix/greeter.qml cage -s -- <checkout>/bin/ionix-greeter`
  (opens as a nested window). `greetd` itself is not needed for that.
- **Last user's look.** The `greeter` account cannot read `/home`, so `bin/ionix-greeter-sync` (run by
  `init.sh`, `ionix-wallpaper`, `ionix-cycle-wallpaper` and `ionixtheme`; a no-op without the greeter)
  copies the user's shell config/theme/settings JSON, `current-theme`, avatar, the `awww query`
  wallpapers and any `lock.background` image/video/slideshow into
  `/var/lib/ionix-greeter/users/<name>/home` — world-readable, paths rewritten. `users/` is sticky
  1777 (`etc/tmpfiles.d/ionix-greeter.conf`) so each user writes only their own directory. On success
  the greeter writes `/var/lib/ionix-greeter/last-user`; `ionix-greeter` points `HOME` at that copy, so
  Config, Theme and `LockMedia` (which reads `wallpapers.json` instead of asking awww) need no changes.
- `greetd.service` `Conflicts=` getty@tty1; enabling it with `--force` is deliberate (another display manager may hold
  `display-manager.service`).

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

**Project workspaces are a CLI, a Lua function and a label.** `/usr/bin/ionix-project`
(stdlib Python) saves one workspace to `~/.config/ionix/projects/<slug>.json`: per window its class,
how to start it again (the desktop entry's `Exec` matched by `StartupWMClass`/id, else
`/proc/<pid>/cmdline`; a hand-written `"exec"` wins), the cwd of a terminal's shell, floating
geometry, and the tiled windows as a **split tree** (`layout_tree()` finds the guillotine cuts; no
cut, as under master, means `tree: null` and tiling in order). Loading launches everything on the
next free workspace (an empty unlabeled active one counts) with `hl.dsp.exec_cmd(cmd, { workspace
= "N silent", float = true })`, claims new windows by class from `hyprctl clients` (moving any that
an already-running instance opened elsewhere), then calls `ionix_project_apply(spec)` in
`hyprland.lua` through `hyprctl eval`, which rebuilds dwindle's tree in-process the way
`arrange_grid` does. Things read out of Hyprland's source, not guessed:

- every `hl.dsp.window.*` dispatcher takes `window = "address:0x…"`; `move`/`resize` with `x`/`y`
  and no `relative` are absolute (global layout px);
- `hl.dsp.layout("preselect r|d")` fixes the next split's direction *and* puts the new window
  second, whatever the box shape or cursor; `splitratio <r> exact` sets the node's ratio, and the
  split window (first child) gets `r/2` of it;
- `float({ action = "disable" })` re-adds the window with no focal point, so under
  `use_active_for_splits` (default on) the *focused* tiled window is the one divided.

The label is the workspace's Hyprland name (`hl.dsp.workspace.rename`), not state of our own:
`Projects.labelFor(ws)` in the shell is just "`ws.name` unless it is the id", Quickshell updates
the name from the `renameworkspace` event, and the label goes when the workspace does — or, because
Hyprland keeps the workspace you are on alive while empty, when its last window closes or moves away:
`Projects.qml` renames it back to its id on that drop to zero (not on a workspace that was always
empty, since a load labels its workspace before any app has a window). The shell
(`services/Projects.qml`) hides the whole feature unless `ionix-project` is on PATH, since the AUR
package also runs off Ionix. It re-reads `ionix-project list --json` when the start menu opens and
on `qs ipc call projects refresh`, which the CLI sends after every change. Run without a terminal
(from the shell or a bind) the CLI reports through `notify-send`. To try it without Hyprland:
`HYPRCTL=<fake script> PROJECTS_DIR=<dir> ionix-project --dry-run load <name>` prints every dispatch.

A capture only knows a command line, not what the app had open (VS Code's folder, a browser
profile), so each window entry can be tuned: `ionix-project app <name> <n> --exec/--cwd/--class/--remove`,
which the start menu's *Edit apps* page (right-click a project) drives, re-reading
`ionix-project apps <name> --json` on every refresh. `"exec"` is a shell string run as typed —
never prefixed with `exec`, it may be several commands — and saving the workspace over the project
again carries each `exec` over to the first new window of the same class. A changed `--class`
is what the loader then waits for, so a command that opens something else needs both.

**First-login setup:** `ionix-first-login` is a marker-file-based one-time script that runs on first Hyprland session (e.g., clones NvChad config for neovim).

**SVG asset pipeline:** Branding is stored as SVG and converted to PNG at build time: the wallpaper and the GRUB logo by `system/Makefile` (into makepkg's `$srcdir`), the installer's logo and welcome hero by `build.sh` (into the staged profile). Nothing generated is written to the source tree.

### Ionix Server

`profiles/server/` makes a headless ISO (`ionix-server-<date>`, `linux-lts`) with no desktop, no
Calamares and no liveuser: the live medium autologins **root** on tty1 (kmscon, see below), runs
`sshd` (root may log in with a key or, once `passwd` has set one, a password —
`sshd_config.d/10-ionix-live.conf`), systemd-networkd/resolved with archiso releng's `.network`
files, and iwd for Wi-Fi. Boot menus add a serial-console entry (`console=ttyS0,115200 console=tty0`:
the **last** `console=` is `/dev/console`, so the screen keeps the boot log).

**`ionix-server-install`** (`usr/local/bin`, Bash, the repo's CLI conventions: `install` default,
`disks`, `example`, `help`, `version`; exit 2 bad args, 3 bad answers) installs it:

- **Answer file** — `KEY=value`, parsed, never sourced (a password hash contains `$`). Keys and
  defaults are documented in `usr/local/share/ionix/server/install.conf.example`, which is what
  `ionix-server-install example` prints; an unknown key is an error. Interactive runs ask for
  whatever the file left out; `--auto` never asks.
- **Where answers come from** — `--config`, else what `ionix-live-setup.service`
  (`ionix-server-install live-setup`, at boot) found: `/etc/ionix/install.conf` baked in by
  `build.sh --answers`, else `ionix-install.conf` on any filesystem labelled `IONIXCFG`, copied to
  `/run/ionix/install.conf`. live-setup also writes its `SSH_KEY`s to root's `authorized_keys`, and
  with `AUTO_INSTALL=yes` starts the install as its own unit (`ionix-autoinstall`, output on the
  console) so the boot is not held up. That stick is left out of `disks`.
- **Unattended safety** — `--auto` requires `DISK=/dev/disk/by-id/...` (a baked ISO booted on
  another machine finds nothing to erase), waits 15 s, and live-setup skips a disk whose
  `@/etc/ionix/installed-from` equals this medium's `archisosearchuuid`. That guard matters:
  OVMF in QEMU boots the CD again after the reboot despite the new NVRAM entry, and without it the
  install loops. Verified.
- **Layout** — GPT: 1 MiB BIOS boot, 1 GiB ESP (`/boot/efi`), btrfs `ionix` with `@` `/`,
  `@home`, `@snapshots` `/.snapshots`, `@log`, `@pkg` `/var/cache/pacman/pkg`, `@docker`; `/boot`
  lives in `@`, so a snapshot includes its kernel. `genfstab` output has `subvolid=` stripped
  (a rollback replaces ids). GRUB is installed for **both** `i386-pc` and `x86_64-efi` (plus the
  removable `EFI/BOOT/BOOTX64.EFI`), `--no-nvram` when not booted UEFI. Booted both ways in QEMU.
- **Steps** — partition, format, `unsquashfs` the live image (`/run/archiso/copytoram/airootfs.sfs`),
  fstab, `systemd-machine-id-setup --root`, `useradd` + `chpasswd -e`, `ionix-post-install` with
  `IONIX_*` env (and `SNAP_PAC_SKIP=y`, so the keyring refresh in there does not leave pre/post
  snapshots of a half-installed system), GRUB, log to `/var/log/ionix-server-install.log` on the
  target. Command output goes to the log only; the screen gets one line per step.

**`post-install.d/10-server`** writes the answers into the target: hostname/locale/timezone, kmscon
on every VT (`systemctl disable getty@tty1`, delete `/etc/systemd/system/autovt@.service` — systemd's
install script aliased it to getty@ and `enable` refuses to take it over — then `enable kmsconvt@.service`),
`xkb-layout=` in `kmscon.conf` (kmscon takes X layout names; `xkb_from_keymap` strips `-latin1`
and maps `uk`→`gb`), serial console in `/etc/default/grub`, networkd (static: `10-static.network`
matched before the DHCP `20-ethernet.network`; wait-online unmasked with `--any`), sshd
(`PermitRootLogin no`, password logins only if asked or no key given — `passwd -l root`), Docker
(+ docker group), snapper by hand (template copied to `configs/root`, `SNAPPER_CONFIGS="root"`:
`snapper create-config` would make its own nested `.snapshots`), timers, `grub-btrfsd`, and
`HOOKS=(... grub-btrfs-overlayfs)` on the **udev** hook set — that hook is a busybox runscript,
and mkinitcpio now defaults to systemd hooks. It runs `ionixtheme` as the user and
`ionix-console-theme` as root, clones NvChad (best effort), and deletes the installer.

**`ionix-server-firstboot`** (oneshot, `Before=network-pre.target sshd.service`, gated on
`/etc/ionix/firstboot`, disables itself) sets up ufw — deny in, allow SSH and `FIREWALL_ALLOW` —
and takes snapper's "Fresh install" snapshot (`--no-dbus`). ufw is not run in the chroot: it would
load its rules into the *live* kernel. Docker-published ports bypass ufw (Docker's own iptables
chains come first); the example answer file says so.

**The console is kmscon.** `etc/kmscon/kmscon.conf` (server only) sets `font-name=JetBrainsMono
Nerd Font` (needs `fontconfig`, an optdepend), `term=xterm-256color` (kmscon's own default,
`kmscon`, is unknown to most remote hosts), `dpms-timeout=600`, and holds the palette between the
markers `ionix-console-theme` rewrites. Prompt glyphs, powerline arrows and `lsd` icons render —
the kernel console cannot, whatever the font: its bitmap fonts hold at most 512 glyphs. The plain
getty kmscon falls back to (`OnFailure=getty@%i`) uses `ter-v20n` and the fish section's OSC P
palette. On the **live medium** `kmsconvt@` cannot be enabled (it conflicts with `getty@tty1`, which
systemd's own install script enables before the overlay could stop it), so getty@tty1's drop-in
runs `ionix-live-console` instead: kmscon with `login -f root`, falling back to the autologin
agetty if kmscon dies within 5 s. kmscon owning the screen hides kernel console output, so
`root/.config/fish/conf.d/ionix-live.fish` (live only, like the wrapper; 10-server deletes both)
repeats live-setup's messages at login and follows an unattended install with
`journalctl -f -t ionix-server-install` — `-t`, because `-u` also catches useradd/runuser syslog
lines from the chroot. live-setup is ordered `Before=getty@tty1.service` for that.

**Known, not ours:** `linux-lts` 6.18.57+ registers no fixed-feature ACPI power button (no
"Power Button" input device, `/sys/firmware/acpi/interrupts/ff_pwr_btn` stays 0), so QEMU's
`system_powerdown`/IPMI soft-off are ignored until upstream fixes it. Shut a test VM down over SSH.
Also: QEMU's default i440fx machine shows the same symptom on any kernel; test on `-machine q35`.
QEMU no longer takes `serial=` on `-drive`; a by-id name needs `-device virtio-blk-pci,serial=`.

### Desktop Stack

- **Compositor:** Hyprland (Wayland) managed by UWSM
- **Panel:** ionix-quickshell (QML/Quickshell) — bar, popouts and OSD. Started by the
  `ionix-quickshell` systemd **user unit** (pre-enabled via the `/etc/skel` symlink, under
  `graphical-session.target`), not by
  `exec-once`, so a QML runtime error self-heals via `Restart=on-failure`. Anything the shell
  starts for the user (apps, desktop actions, settings tools, `xdg-open`, the power commands) goes
  through `services/Launch.qml`, which wraps it in `systemd-run --user --scope` under the unit:
  systemd stops a unit by killing its whole cgroup, so a plain `execDetached` child — detached or
  not — died with every shell crash or restart. Short-lived helpers the shell waits on stay plain
  `Process`/`execDetached`
- **Panel (fallback):** Waybar is still installed and its themes still ship, but nothing starts it
  automatically. `Ctrl+Super+Shift+B` launches it if the Quickshell bar misbehaves
- **Session services** are user units enabled for every new account by symlinks in
  `etc/skel/.config/systemd/user/graphical-session.target.wants/`: `ionix-quickshell`,
  `ioexplorer-desktop`/`-quick`/`-spotlight` and `hyprpolkitagent`. `ionix-quickshell` used to sit in
  `default.target.wants`: it then started before Hyprland, crashed with no display, and only showed
  because its restart happened to land after the compositor — and a relogin within ~10 s of logout
  (the user manager still alive, `default.target` already reached) never started it at all.
  Graphical ones belong under `graphical-session.target` even when their own `[Install]` says
  `default.target`: under greetd the user manager (and so `default.target`) starts at PAM login,
  before Hyprland exists, and they would crash-loop with no display. `ioexplorer-portal` has no
  `[Install]` — it is D-Bus activated, and only ever asked for because
  `etc/xdg/xdg-desktop-portal/hyprland-portals.conf` names it the FileChooser (its `.portal` file
  still uses `UseIn=`, which xdg-desktop-portal no longer reads).
- **Keyring:** unlocked with the login password by `pam_gnome_keyring` in `/etc/pam.d/greetd`
  (auth + `session … auto_start`) and kept in step by `/etc/pam.d/passwd`; `ionix-post-install` adds
  those lines, because both files belong to packages. The greeter's own session uses
  `etc/pam.d/greetd-greeter` (greetd prefers it over `greetd`), keyring-free — without it the
  `greeter` account tried to start a keyring with no home. Only a *password* login unlocks it:
  autologin and a fingerprint at the greeter leave it locked until first use. The exception is
  `ionix-lock`: its `lock/pam/password` stack runs `pam_gnome_keyring` after `pam_unix`, and the
  module reaches the session's daemon via `$XDG_RUNTIME_DIR/keyring/control`, so a password typed
  at any lock (the `locked` mode's session-start one included) unlocks it. All of these unlock the
  keyring named **`login`** only; a default keyring under any other name keeps prompting.
- **Terminal:** ionterm (primary, AUR `ionterm-git`; window class `ionterm`, themed by the styler's
  `ionterm/theme.toml` section, which it hot-reloads), kitty, foot, tabby
- **Shell:** fish + oh-my-posh
- **Login flow:** TTY autologin → fish → auto-starts Hyprland via UWSM

### Important Scripts (`system/*/usr/bin/`, installer ones in `profiles/*/airootfs/usr/local/bin/`)

- `ionix-install` — Launches the Calamares installer
- `ionix-post-install` — Post-installation system configuration (runs inside chroot)
- `ionix-first-login` — One-time user environment setup
- `ionix-lock` — (from ionix-quickshell, `/usr/bin`) the lock screen; `Super+L`, the power menu and
  the session-start lock in `init.sh` all go through it
- `grub-install` — PATH-priority wrapper adding `--no-nvram`, so a plain `grub-install` call
  from inside the Calamares chroot does not fail trying to write EFI NVRAM
- `ionix-arrange-workspace` — workspace helper
- `ionix-project` — save/load labeled project workspaces (see "Project workspaces" above)
- `ionix-login-mode` — greeter / autologin / locked; survives onto the installed system
- `ionix-fingerprint` — fingerprint reader support; survives onto the installed system
- `ionix-extras` — installs the optional bundles; survives onto the installed system
- `ionix-migrate` — (base) runs pending migrations: `system` from a pacman hook, `user` at login
- `ionix-console-theme` — (base) copies a theme's `tty/kmscon.conf` palette lines, and only
  those, into `/etc/kmscon/kmscon.conf`; root; a no-op error where kmscon is not set up
- `ionix-server-install`, `ionix-server-firstboot` — the server's installer and first-boot job
  (see "Ionix Server" above)

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
with `export USE_ADAPTIVE_COLORS=true` in its `install` file; `system/desktop/usr/share/ionix/bin/ionix-adaptive-colors`
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

### Terminal sections

Four styler sections theme the terminal, and are all the server installs: `fish/theme.fish`
(→ `~/.config/fish/conf.d/ionix-theme.fish`: syntax and pager colours as `set -g`, which shadows
fish's universal defaults; `FZF_DEFAULT_OPTS`; and on `TERM=linux` the 16-slot console palette by
OSC P, clearing once on a login shell because existing cells keep their old background),
`prompt/theme.omp.json` (→ `~/.config/ionix/theme.omp.json`, which the skel `config.fish` prefers
over the stock `ionix.omp.json`), `btop/ionix.theme` (→ `~/.config/btop/themes/ionix-styler.theme`,
`color_theme` set once in `btop.conf`) and `tty/kmscon.conf` (via `ionix-console-theme`: system-wide,
so `sudo -n` or a hint). `/etc/skel` ships the first three as symlinks into the `ionix` theme, so
a new account is themed before anyone runs `ionixtheme`. `bat` is set to `--theme=ansi` in skel
and follows the terminal's palette instead.

Every section of every theme, including `ionix-adaptive`'s templates (static = template rendered
with the base palette), comes from one set of templates; the oh-my-posh one is the stock prompt
with each colour turned into a slot and every Go action written `{{ if`, never `{{if`, because
`ionix-adaptive-colors` refuses a file with anything matching `{{[A-Za-z]` left in it.

`ionixtheme` skips installing a section whose `ionix_available_<section>` (install-default) fails —
`command -v` for the desktop apps, `/etc/kmscon/kmscon.conf` for `tty` — and
`ionix-adaptive-colors`' re-link loop asks the same, so one theme tree serves both variants.

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

- When adding new packages: edit `profiles/common/packages.x86_64` (both ISOs) or a variant's. AUR packages must also be added to `aur/build-aur.sh` with correct dependency ordering, and an AUR package another one depends on must be listed too: `build-aur.sh` builds only what the staged list names.
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
  `/usr/share/ionix`, so to exercise a checkout without installing it, set `IONIX_STYLER_DIR`
  and `IONIX_BIN` at the repo paths (plus `HOME`, `XDG_CONFIG_HOME` and `XDG_CACHE_HOME` at a scratch
  dir — `XDG_CONFIG_HOME` is set on a live Ionix session and will otherwise defeat a fake `HOME`).
- When touching fingerprint support: `ionix-fingerprint` edits `/etc/pam.d/sudo`, which gates sudo,
  so both edit paths are guarded — `enable` refuses to write a file that is not exactly three lines
  longer than the original, and `disable` refuses to write an empty one. Both are idempotent and the
  round trip is byte-identical; keep it that way. Test it without touching your own machine by
  overriding `HWDB`, `SPI_RULES`, `PAM_MODULE`, `PAM_ETC_DIR` and `PAM_VENDOR_DIR` at the top of a
  copy of the script — every path it writes to is one of those.
- When modifying default user config: edit files under `system/<base|desktop>/etc/skel/.config/`.
  Skel only reaches new accounts; a change existing users need is a user migration too.
- When modifying system config: edit files under `system/<layer>/etc/` — or, for a live-medium,
  per-machine or other-package file, `profiles/<layer>/airootfs/etc/`.
- When adding new scripts: add to `system/<layer>/usr/bin/` with the executable bit set in git
  (`install-tree.sh` takes modes from it; `git update-index --chmod=+x`). Only an installer- or
  live-only script goes in `profiles/<layer>/airootfs/usr/local/bin/`, and it needs an entry in
  that layer's `profiledef.sh` (`file_permissions=(...)` in common, `file_permissions+=(...)` in a
  variant): mkarchiso copies the overlay with `--no-preserve=mode`.
- When an update needs an action rather than a file (enable a unit, edit a key in a file another
  package owns, fix up user state): add a migration under `system/base/usr/share/ionix/migrations/`.
- Build output (`out/`, `work/`, `localrepo/`) and generated assets are gitignored.
