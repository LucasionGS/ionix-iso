---
name: add-package
description: Add, remove, or force-rebuild a package in the Ionix ISO. Use whenever a package is added to or removed from the distro, an AUR package needs to enter the local [ionix] repo, or a package must be rebuilt after an upstream update. Encodes the packages.x86_64 / build-aur.sh dual-registration and the dependency-ordering rules.
---

# Adding a package to Ionix

A wrong or missing registration surfaces only as `target not found` at mkarchiso (step 4/4), after the multi-hour AUR build. Follow the checklist for the package's type before building anything.

## 1. Official repo package (core/extra/multilib)

Add the name to `profile/packages.x86_64` under the matching `# --- Section ---` banner. Done — nothing else to touch.

## 2. AUR package

Two files, and the order inside one of them matters:

1. **`aur/build-aur.sh` → `AUR_PACKAGES` array.** Array order IS build order: each package is `pacman -U`-installed into the build container right after building, so later entries can resolve it as a dependency. Place the new entry **after every AUR package it depends on** (check its PKGBUILD's `depends`/`makedepends` for other AUR names). Existing ordering chains to respect:
   - `libastal-io-git` → `libastal-git` → all other `libastal-*` → `libastal-meta` last
   - `libcava-git` before `libastal-cava-git`; `appmenu-glib-translator-git` before `libastal-tray-git`; `quarrel-git` before `libastal-mpris-git`/`libastal-notifd-git`
   - `openconnect-sso-git` → `ionix-openconnect-tools` → `ionix-shell`
2. **`profile/packages.x86_64`** → add the name to the trailing `# --- AUR packages (from ionix local repo) ---` block — but **only if it should be explicitly installed**. Dependency-only packages (like the `libastal-*` sublibs) go in `AUR_PACKAGES` only.
3. If the build needs a tool its PKGBUILD doesn't declare (precedent: `dart-sass` for `ags bundle`), add it to `EXTRA_BUILD_DEPS` in `build-aur.sh`.

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

- Every AUR-block name in `packages.x86_64` appears in `AUR_PACKAGES`/`LOCAL_PACKAGES` (or is a `pkgname` produced by one of them).
- The new `AUR_PACKAGES` entry sits after all its AUR dependencies.
- Then build: `sudo ./build.sh` (native, Arch only) or `./docker-build.sh`. Already-built packages are skipped via sentinels, so an incremental build is cheap. Prefer docker variant to avoid dependency installation locally.
