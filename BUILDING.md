# Building Ionix

Everything here is for people who want to compile the ISO themselves. If you just want to
*use* Ionix, the [README](README.md) is the file you want.

Ionix is an [archiso](https://wiki.archlinux.org/title/Archiso) profile. The build produces a
single hybrid ISO in `out/` that boots as both a live environment and an installer.

---

## Prerequisites

You can build **natively on Arch Linux** (requires root) or **inside Docker** on any Linux host.
The Docker route is the one to pick if you are not already on Arch.

### Submodules

`ionix-quickshell` — the desktop shell — is a git submodule, and it is built into the ISO from
your working tree as the package `ionix-quickshell-git`. Fetch it before building, **as your
normal user, not as root**:

```bash
git submodule update --init --recursive
```

`docker-build.sh` does this for you. `build.sh` deliberately does not: it runs as root, and git
refuses to touch a checkout owned by someone else. It stops with this instruction instead.

### Native build dependencies

```bash
sudo pacman -S --needed --noconfirm \
    archiso base-devel git \
    meson cmake extra-cmake-modules \
    python nodejs npm \
    rust go cargo \
    gobject-introspection
```

Some AUR packages need Python build tooling that is not in the repos:

```bash
sudo python -m ensurepip          # only if pip is missing
sudo python -m pip install meson setuptools
```

> **Python 3.14.** `gobject-introspection` from the Arch repos is compiled against Python 3.14, so
> `/usr/bin/python3.14` must exist. It does **not** need to be your default `python` — the build
> script picks the right interpreter itself.

---

## Building

### With Docker (recommended, even on Arch too)

```bash
./docker-build.sh                  # builds the ionix-builder image on first run
./docker-build.sh --rebuild-image  # force the image to rebuild
```

### Natively on Arch

```bash
sudo ./build.sh
```

Either way the ISO lands in `out/` as `ionix-<YYYY.MM.DD>-x86_64.iso`.

### What the build actually does

1. **AUR packages.** 15 AUR packages (Calamares, Google Chrome, `yay`, the Ionix tooling,
   ProtonUp-Qt and friends) are compiled in dependency order into a local pacman repository at
   `localrepo/`, alongside 2 packages built from sources inside this repo — the
   `ionix-quickshell` submodule and `aur/local/shim-signed`. Already-built AUR packages are
   skipped via sentinel files; the local ones are always rebuilt, because their sources change
   with your working tree.
2. **Repo staging.** `localrepo/` is copied to `/tmp/ionix-localrepo` so `mkarchiso` can read it
   as the `[ionix]` repository declared in `profile/pacman.conf`.
3. **Branding.** The SVGs in `assets/` are rasterised to PNG with `rsvg-convert`, or ImageMagick
   as a fallback. The generated PNGs are gitignored.
4. **ISO assembly.** `mkarchiso` builds the squashfs and the final hybrid ISO into `out/`.

The `[ionix]` repository exists only during the build and on the live medium.
`ionix-post-install` strips it from the installed system, which is what lets `yay` treat
`ionix-quickshell-git` as an ordinary AUR package afterwards.

---

## Testing

Both scripts create `ionix-test.qcow2` (64 GB) and `ionix-test-efivars.fd` on first run, and boot
QEMU with KVM, OVMF UEFI firmware and `virtio-vga-gl`:

```bash
./test.sh          # boot the newest out/ionix-*.iso as a live environment
./test-distro.sh   # boot the installed system off the virtual disk, no ISO attached
```

These open an interactive QEMU window. Note that `virtio-vga-gl` gives you working GPU
acceleration but breaks QEMU's `screendump`, so neither script can be driven headlessly. For
scripted runs — installing unattended, taking screenshots, CI-style validation — use the
`vmctl.py` harness under `.claude/skills/full-pipeline-test/scripts/`, which starts QEMU with
`-display none`, a QMP socket and plain `virtio-vga`.

---

## Writing the ISO to a USB stick

```bash
./flash-usb.sh                          # interactive disk picker
./flash-usb.sh --list                   # just print the candidate disks
./flash-usb.sh --device /dev/sdX --verify
```

It defaults to the newest `out/ionix-*.iso`. It never offers your system disk as a target, and it
makes you type the full device path back before it writes anything. Progress is rendered from
`dd`'s own byte counter — no `pv` dependency — and it writes with `oflag=direct`, so the
percentage reflects bytes actually on the stick rather than bytes sitting in the page cache.

---

## Patching an already-installed system

`patch-os.sh` rsyncs changed files from `profile/airootfs/` onto a running Ionix install, so you
can pull configuration changes across without rebuilding and reinstalling:

```bash
sudo ./patch-os.sh
```

It skips paths that only make sense on the live medium and paths that are per-machine — see the
`SKIP_EXACT` and `SKIP_PATTERNS` arrays at the top of the script. It only touches system
configuration under `/etc` and `/usr/local`; it will not update packages, so anything that ships
as a package (the shell included) still comes from `pacman`/`yay`.

---

## Cleaning up

```bash
./clean.sh
```

Removes `work/`, `out/`, `localrepo/`, the `/tmp/ionix-*` staging directories, makepkg leftovers
in the submodules, and the generated branding PNGs.

---

## Continuous integration

`.github/workflows/build-iso.yml` builds the ISO on `workflow_dispatch` or on any pushed `v*`
tag. It runs on `ubuntu-latest` with a 360-minute timeout, checks out submodules recursively,
frees runner disk space, and then runs the same Docker build you would run locally.

---

## Adding a package

Packages are registered in two places, and both matter:

- **`profile/packages.x86_64`** — the list `mkarchiso` installs into the ISO. Every package, from
  the official repos or from `[ionix]`, needs a line here.
- **`aur/build-aur.sh`** — only for AUR packages, which additionally have to be *built* into
  `localrepo/` first. Order matters: the `AUR_PACKAGES` array is built top to bottom, so a
  package must appear after anything it depends on.

Forgetting the second step gives you a build that fails at the `mkarchiso` stage with an
unresolvable dependency, because the package is requested but was never built.

---

## Repository layout

```
ionix-iso/
├── assets/                 # SVG branding (logo, wallpaper) — rasterised at build time
├── aur/
│   ├── build-aur.sh        # Builds AUR packages into localrepo/ in dependency order
│   └── local/              # PKGBUILDs maintained here rather than pulled from the AUR
├── docs/                   # README screenshots and the logo
├── includes/               # Pre-built package cache
├── profile/                # The archiso profile
│   ├── airootfs/           # Root filesystem overlay — becomes the live ISO's filesystem
│   │   ├── etc/            # System config: hypr, calamares, fish, grub.d, sysctl.d …
│   │   └── usr/local/      # Ionix scripts, the styler and its themes
│   ├── efiboot/            # UEFI boot configuration
│   ├── grub/               # GRUB configuration for the ISO
│   ├── syslinux/           # BIOS boot configuration
│   ├── packages.x86_64     # Full package list (official repos + local [ionix] repo)
│   ├── pacman.conf         # pacman config referencing the local [ionix] repo
│   └── profiledef.sh       # archiso profile definition, including file permissions
├── submodules/
│   └── ionix-quickshell/   # The desktop shell (its own repo, built into the ISO)
├── .github/workflows/      # CI: build-iso.yml
├── build.sh                # Main build entry point (run as root)
├── docker-build.sh         # Docker wrapper around build.sh
├── clean.sh                # Remove all build artifacts
├── flash-usb.sh            # Write a built ISO to a USB stick
├── patch-os.sh             # Rsync profile changes onto an installed system
├── test.sh                 # Boot the ISO in QEMU
└── test-distro.sh          # Boot the installed disk image in QEMU
```

`CLAUDE.md` in the repository root documents the architecture in more depth, including the
patterns and pitfalls that are not obvious from reading the scripts.
