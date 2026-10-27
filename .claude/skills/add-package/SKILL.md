---
name: add-package
description: Add, remove, or force-rebuild a package in the Ionix ISO. Use whenever a package is added to or removed from the distro, an AUR package needs to enter the local [ionix] repo, or a package must be rebuilt after an upstream update. Encodes the packages.x86_64 / build-aur.sh dual-registration and the dependency-ordering rules.
---

# Adding a package to Ionix

A wrong or missing registration surfaces only as `target not found` at mkarchiso (step 5/5), after the multi-hour AUR build. Follow the checklist for the package's type before building anything.

## 0. Which list

There are two ISOs, desktop and server, each built from `profiles/common/` plus its own `profiles/<variant>/`. `build.sh` concatenates `common/packages.x86_64` with the variant's, so:

- needed by both (CLI tools, shell, boot, filesystems) → `profiles/common/packages.x86_64`
- desktop only (Wayland, GUI apps, audio, GPU) → `profiles/desktop/packages.x86_64`
- server only → `profiles/server/packages.x86_64`

The kernel is per variant (`linux` on the desktop, `linux-lts` on the server). Never list a package in both common and a variant.

## 1. Official repo package (core/extra/multilib)

Add the name to the right `profiles/*/packages.x86_64` (see 0) under the matching `# --- Section ---` banner. Done — nothing else to touch.

## 2. AUR package

Two files, and the order inside one of them matters:

1. **`aur/build-aur.sh` → `AUR_PACKAGES` array.** Array order IS build order: each package is `pacman -U`-installed into the build container right after building, so later entries can resolve it as a dependency. Place the new entry **after every AUR package it depends on** (check its PKGBUILD's `depends`/`makedepends` for other AUR names). Existing ordering chains to respect:
   - `python-gevent-eventemitter`/`python-vcrpy` → `openconnect-sso-git` → `ionix-openconnect-tools`
2. **`profiles/*/packages.x86_64`** → add the name to the trailing `# --- AUR packages (from ionix local repo) ---` block of the right list. `build-aur.sh` only builds the AUR and local packages the staged list names, so **an AUR package that another AUR package depends on must be listed too**, in the same variant (or common), or it is skipped and the dependent fails to build.
3. If the build needs a tool its PKGBUILD doesn't declare, add it to `EXTRA_BUILD_DEPS` in `build-aur.sh` (currently empty).

## 3. Local (in-repo) package

Add its directory path to `LOCAL_PACKAGES` in `aur/build-aur.sh` (must contain a PKGBUILD), and add the **PKGBUILD's `pkgname`** — not the directory name — to `packages.x86_64`. Local packages are always rebuilt (no sentinel skip) and old artifacts are swept automatically. If it's a git submodule, also register it in `.gitmodules` and remind the user that `git submodule update --init --recursive` must run as the normal user (build.sh runs as root and refuses to fetch).

## Forcing a rebuild of an already-built AUR package

Sentinels make `build-aur.sh` skip anything already built — an upstream update is invisible until you clear them by hand:

```bash
rm localrepo/.built-<pkg>
rm localrepo/<pkg>-*.pkg.tar.*   # required: repo-add globs the dir; a stale
                                 # version left behind can win the glob
```

Never run `./clean.sh` just to rebuild one package — it deletes all of `localrepo/` and forces a full ~41-package rebuild.

## Removing a package

Remove it from `packages.x86_64`, and from `AUR_PACKAGES`/`LOCAL_PACKAGES` if listed there. Check nothing later in `AUR_PACKAGES` depended on it. Stale artifacts in `localrepo/` are harmless but can be deleted along with the `.built-*` sentinel.

## Verify before building

- Every AUR-block name in a `packages.x86_64` appears in `AUR_PACKAGES`/`LOCAL_PACKAGES` (or is a `pkgname` produced by one of them).
- The new `AUR_PACKAGES` entry sits after all its AUR dependencies.
- Then build: `sudo ./build.sh [--variant server]` (native, Arch only) or `./docker-build.sh [--variant server]`. Already-built packages are skipped via sentinels, so an incremental build is cheap. Prefer docker variant to avoid dependency installation locally.
