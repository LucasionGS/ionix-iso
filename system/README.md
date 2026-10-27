# Ionix system packages

Ionix's own files, packaged so that an installed system keeps up with this repository through
pacman instead of being frozen at the ISO it was installed from.

| Package             | Contents                                                                             |
|---------------------|--------------------------------------------------------------------------------------|
| `ionix-base-git`    | `base/`: the styler and every theme, fish config and the skel shell setup, the GRUB theme, `ionix-console-theme`, `ionix-migrate` |
| `ionix-desktop-git` | `desktop/`: Hyprland's system config, the session scripts, login modes, fingerprint support, `ionix-extras`, `ionix-project`, the wallpaper |
| `ionix-server-git`  | `server/`: `ionix-server-firstboot` and its unit                                     |

Each directory is laid out exactly as it is installed: `base/usr/bin/ionix-migrate` becomes
`/usr/bin/ionix-migrate`. The desktop and server packages each depend on `ionix-base` and conflict
with each other. They are one split package (`pkgbase` `ionix-system-git`), so one clone builds all three.

## What does *not* go here

The ISO's `profiles/*/airootfs/` keeps everything that is not the same file on every installed system:

- **Live-medium only**: Calamares, liveuser, `ionix-install`, `ionix-post-install` and its
  `post-install.d`, `ionix-server-install`, the archiso units and hooks.
- **Owned by another package**: `/etc/default/grub` (grub), `/etc/greetd/config.toml` (greetd),
  `/etc/locale.gen` (glibc). Pacman does not let two packages own a file. The installer edits these,
  and a migration (below) changes specific keys in them when an update has to.
- **Per machine**: hostname, `passwd`, presets, `/etc/kmscon/kmscon.conf` (layout and palette
  are written per install by `10-server` and `ionix-console-theme`).

Nothing goes under `/usr/local`: that belongs to the machine's admin. The old `/usr/local` paths
still resolve through links that `ionix-migrate` keeps (see below).

## Updates and your own changes

- **Files in `/etc`** are all listed in `backup=()`. If you never edited one, it is updated
  silently. If you edited it and the package did not change it, yours stays. If both changed, yours stays
  and the new one lands next to it as `.pacnew` (`pacdiff` merges them).
- **Defaults meant to be overridden** live in a system file that the user's own file loads or
  overrides: `/etc/hypr/hyprland.lua` under `~/.config/hypr/hyprland.lua`, fish's
  `conf.d`. Prefer that to `/etc` edits wherever the app supports it.
- **`/etc/skel`** only reaches new accounts. A change existing users need goes in a user migration.

## Migrations

Some changes are actions rather than files: enabling a unit, editing a key in a file another
package owns, moving a user's settings along. Each one is an executable named `NNN-name` in
`usr/share/ionix/migrations/` of whichever layer it belongs to. A migration that needs one
package's files ships in that package (`desktop/` has `002-greeter-keyboard`), so it cannot run
before they are there. Numbers are shared across the layers.

- `system/`: runs as root from the `ionix-migrate` pacman hook after every install or upgrade
  of `ionix-base`, or of any package that ships a migration. What has run is recorded in
  `/var/lib/ionix/migrations`.
- `user/`: runs as each user at login (fish's `conf.d/ionix.fish` for login shells, the
  desktop's `init.sh` for greeter sessions). What has run is recorded in `~/.local/state/ionix/migrations`.

A migration runs once, in name order, and must be idempotent. An ISO build runs every system
migration too, on a root that has never had the old state, so each one has to find nothing to do
there and exit 0. A failing migration stops the rest of the queue and is retried the next time.

`ionix-migrate system` also keeps `/usr/local/share/ionix/<name>` linked to `/usr/share/ionix/<name>`.
Everything lived there before Ionix was packaged, and that path is still written into user homes
(theme symlinks, crontabs) and into older builds of the shell.

## Building

The ISO builds these from the working tree: `aur/build-aur.sh` lists `system` in `LOCAL_PACKAGES`,
and `./PKGBUILD` reads the files from `$startdir`. `packaging/aur/PKGBUILD` is the same recipe
fetching `system/` from GitHub. Keep the two in step; what each package contains is the Makefile's job.

The version is `r<count>.<hash>` of the commits that touched `system/`, so a change that only
affects the ISO is not an upgrade. The same formula is in `./PKGBUILD`, `packaging/aur/PKGBUILD`,
`packaging/aur/aur-publish.sh` and `aur/build-aur.sh`. If you change one, change all four.

To try a change on a running install without the AUR: `sudo ./patch-os.sh` at the repository root.

## Publishing

```bash
git push
./system/packaging/aur/aur-publish.sh "What changed"
```

It refuses to publish uncommitted or unpushed work, since the AUR build fetches from GitHub. Each
publish raises `pkgver`, so a plain `yay -Syu` picks it up; `yay -Syu --devel` also picks up commits
that were never published.
