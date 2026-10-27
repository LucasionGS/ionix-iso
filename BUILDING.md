# Building Ionix

Everything here is for people who want to compile the ISO themselves. If you just want to
*use* Ionix, the [README](README.md) is the file you want.

Ionix is an [archiso](https://wiki.archlinux.org/title/Archiso) profile, in two variants: the
**desktop** (Hyprland, Calamares) and the **server** (headless, CLI installer). Each build produces
one hybrid ISO in `out/` that boots as both a live environment and an installer.

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
./docker-build.sh                    # the desktop ISO; builds the ionix-builder image on first run
./docker-build.sh --variant server   # the server ISO
./docker-build.sh --rebuild-image    # force the image to rebuild
```

### Natively on Arch

```bash
sudo ./build.sh
sudo ./build.sh --variant server
```

Either way the ISO lands in `out/` as `ionix-<YYYY.MM.DD>-x86_64.iso`, or
`ionix-server-<YYYY.MM.DD>-x86_64.iso` for the server.

`--answers FILE` (server only) bakes an answer file into the ISO, so that it installs with nobody at
the keyboard; see [Unattended server installs](#unattended-server-installs).

### What the build actually does

1. **Profile staging.** `profiles/common/` is copied to `staging/<variant>/` with the variant's
   directory laid over it; their `packages.x86_64` and `profiledef.sh` are concatenated instead.
   Everything below happens in that copy, so a build never modifies the source tree.
2. **AUR packages.** 15 AUR packages (Calamares, Google Chrome, `yay`, the Ionix tooling,
   ProtonUp-Qt and friends) are compiled in dependency order into a local pacman repository at
   `localrepo/`, alongside the packages built from sources inside this repo: the
   `ionix-quickshell` submodule, Ionix's own files in `system/` (`ionix-base-git` plus
   `ionix-desktop-git` or `ionix-server-git`) and `aur/local/shim-signed`. Already-built AUR packages are
   skipped via sentinel files; the local ones are always rebuilt, because their sources change
   with your working tree. Only the ones the staged package list names are built, so the server
   build needs just `yay`, `oh-my-posh-bin`, `shim-signed` and the system packages.
3. **Repo staging.** `localrepo/` is copied to `/tmp/ionix-localrepo` so `mkarchiso` can read it
   as the `[ionix]` repository declared in `profiles/common/pacman.conf`.
4. **Branding.** The installer's own images (the Calamares logo and welcome hero) are rasterised
   with `rsvg-convert` into the staged profile. The wallpaper, logo and GRUB theme are rendered
   by the system packages instead, because installed systems need them too.
5. **ISO assembly.** `mkarchiso` builds the squashfs and the final hybrid ISO into `out/`.

The `[ionix]` repository exists only during the build and on the live medium.
`ionix-post-install` strips it from the installed system, which is what lets `yay` treat
`ionix-quickshell-git` and the system packages as ordinary AUR packages afterwards.

---

## Testing

Both scripts create `ionix-test.qcow2` (64 GB) and `ionix-test-efivars.fd` on first run, and boot
QEMU with KVM, OVMF UEFI firmware and `virtio-vga-gl`. A server ISO gets its own
`ionix-server-test.*` pair, so it never installs over the desktop test disk:

```bash
./test.sh                              # boot the newest desktop ISO as a live environment
./test.sh out/ionix-server-*.iso       # boot a server ISO
./test-distro.sh                       # boot the installed desktop off the virtual disk
./test-distro.sh server                # boot the installed server
```

These open an interactive QEMU window. Note that `virtio-vga-gl` gives you working GPU
acceleration but breaks QEMU's `screendump`, so neither script can be driven headlessly. For
scripted runs — installing unattended, taking screenshots, CI-style validation — use the
`vmctl.py` harness under `.claude/skills/full-pipeline-test/scripts/`, which starts QEMU with
`-display none`, a QMP socket and plain `virtio-vga`.

---

## Unattended server installs

The server ISO installs from its console (`ionix-server-install`), over SSH, or with nobody there.
Every question the installer asks can be answered in a file; print a commented example with
`ionix-server-install example`, or read it at
`profiles/server/airootfs/usr/local/share/ionix/server/install.conf.example`.

The live medium looks for one at boot:

1. baked into the ISO with `./build.sh --variant server --answers install.conf` (with Docker the file
   must be inside the checkout); it then sits on the medium, password hash included, so keep that
   ISO to yourself
2. as `ionix-install.conf` at the top of any filesystem labelled `IONIXCFG`, such as a second USB
   stick formatted with `mkfs.fat -n IONIXCFG`

Its `SSH_KEY` lines may log in as root straight away. With `AUTO_INSTALL=yes` it installs to `DISK`,
which must then be a `/dev/disk/by-id/` path, after a 15-second warning on the console, and reboots.
It will not reinstall a disk the same medium already installed, so a stick left in does not loop.

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

## Keeping installed systems up to date

Ionix's own files (the styler and themes, Hyprland's defaults, the session scripts, the GRUB
theme...) ship as packages built from `system/`, so an installed system updates them like any
other package:

```bash
yay -Syu
```

That needs a publish to the AUR (`system/packaging/aur/aur-publish.sh`, after pushing).
`system/README.md` explains which files are packaged, how a config file you edited is kept
(`.pacnew`), and how changes that are not files (migrations) reach existing systems.

To try a change before publishing, or to bring a system installed before the packages existed
up to date, `patch-os.sh` builds the packages from your checkout and installs them:

```bash
sudo ./patch-os.sh
```

It walks you through every config file where your version and the new one differ, then offers
to install anything new in the variant's `packages.x86_64` with `yay`. Live-medium and
per-machine files (`profiles/*/airootfs/`) are never touched.

---

## Cleaning up

```bash
./clean.sh
```

Removes `work/`, `staging/`, `out/`, `localrepo/`, the `/tmp/ionix-*` staging directories and
makepkg leftovers in the submodules.

---

## Continuous integration

`.github/workflows/build-iso.yml` builds both ISOs, one job per variant, on `workflow_dispatch`
or on any pushed `v*` tag. It runs on `ubuntu-latest` with a 360-minute timeout, checks out submodules recursively,
frees runner disk space, and then runs the same Docker build you would run locally.

---

## Adding a package

Packages are registered in two places, and both matter:

- **`profiles/<layer>/packages.x86_64`** — the lists `mkarchiso` installs into the ISO: `common/`
  for both variants, `desktop/` or `server/` for one. Every package, from the official repos or
  from `[ionix]`, needs a line in one of them.
- **`aur/build-aur.sh`** — only for AUR packages, which additionally have to be *built* into
  `localrepo/` first. Order matters: the `AUR_PACKAGES` array is built top to bottom, so a
  package must appear after anything it depends on.

Forgetting the second step gives you a build that fails at the `mkarchiso` stage with an
unresolvable dependency, because the package is requested but was never built.

---

## Repository layout

```
ionix-iso/
├── assets/                 # The installer's SVG branding, rasterised at build time
├── aur/
│   ├── build-aur.sh        # Builds AUR packages into localrepo/ in dependency order
│   └── local/              # PKGBUILDs maintained here rather than pulled from the AUR
├── docs/                   # README screenshots and the logo
├── includes/               # Pre-built package cache
├── profiles/               # The archiso profile, in layers build.sh merges
│   ├── common/             # Both variants: boot, pacman, archiso's live units
│   │   ├── airootfs/       # Live-medium and per-machine files laid over the ISO's root
│   │   ├── packages.x86_64 # Packages on both ISOs
│   │   ├── pacman.conf     # pacman config referencing the local [ionix] repo
│   │   └── profiledef.sh   # Shared archiso settings and file permissions
│   ├── desktop/            # Hyprland, Calamares, the desktop's scripts and boot entries
│   └── server/             # ionix-server-install, kmscon, ufw, snapper, LTS boot entries
├── submodules/
│   └── ionix-quickshell/   # The desktop shell (its own repo, built into the ISO)
├── system/                 # Ionix's own files as packages (ionix-base/desktop/server-git)
├── .github/workflows/      # CI: build-iso.yml
├── build.sh                # Main build entry point (run as root)
├── docker-build.sh         # Docker wrapper around build.sh
├── clean.sh                # Remove all build artifacts
├── flash-usb.sh            # Write a built ISO to a USB stick
├── patch-os.sh             # Install the system packages from this checkout
├── test.sh                 # Boot the ISO in QEMU
└── test-distro.sh          # Boot the installed disk image in QEMU
```

`CLAUDE.md` in the repository root documents the architecture in more depth, including the
patterns and pitfalls that are not obvious from reading the scripts.
