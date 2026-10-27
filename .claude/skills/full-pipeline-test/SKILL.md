---
name: full-pipeline-test
description: Run the complete Ionix release pipeline end to end — clean, docker build the ISO, install it headlessly in QEMU by driving Calamares with screenshots, shut down, boot the installed system and exercise the desktop, then publish a screenshot gallery of the run. Use when asked for a full pipeline compile, a full build-and-install test, an end-to-end/release validation, or to verify an ISO actually installs and boots. Includes a diagnose-fix-retry loop on failure.
---

# Full pipeline compile and install test

Five phases, run in order: **build → headless install → shutdown → boot and exercise the desktop → publish the gallery**. Phases 2 and 4 are driven entirely through `scripts/vmctl.py`, which runs QEMU with no display and controls it over QMP: keystrokes, absolute mouse clicks, and PNG screenshots you read back with the Read tool.

Budget several hours. Phase 1 dominates: `./clean.sh` deletes `localrepo/`, including every `.built-*` sentinel, so all ~41 AUR packages rebuild from source. Say this to the user before starting — it is the single most expensive thing in the repo, and if the goal is only "test the current ISO", skip `clean.sh` and reuse `out/`.

## How to pace the run

This is a multi-hour job across many turns, so the check-in cadence matters as much as the commands. Two different rhythms:

- **The build (Phase 1) — do not narrate it.** Start it with `run_in_background: true` and let the completion notification wake you. A per-package `Monitor` fires dozens of times and is pure noise; if you want one at all, filter to failures only. Announce the start, then go quiet until it exits or breaks.
- **The VM (Phases 2 and 4) — check every 1–2 minutes.** These are interactive, and a wrong keystroke that nobody looks at wastes the whole install. Prefer several short waits over one long block, and read the screenshot every time.

Never claim a step worked without a screenshot showing it. `key` and `type` fail silently when the guest ignores them.

Send a `PushNotification` at the real milestones only — ISO built, install finished, run complete — since the user has very likely walked away.

## Phase 0 — preflight

```bash
git submodule update --init --recursive     # as the normal user; build.sh runs as root and refuses to fetch
df -h /home /tmp                            # need ~40G free: ISO build + a 64G sparse qcow2
free -h                                     # see below: /tmp is usually tmpfs
ls /dev/dri/renderD*                        # render node, only needed for --gl
ls /usr/share/edk2/x64/OVMF_CODE.4m.fd      # UEFI firmware; vmctl hardcodes this path
systemctl is-active docker && ls /dev/kvm
```

**Set `IONIX_VM_RUNDIR` to disk-backed storage before starting any VM.** The default `/tmp` is tmpfs on this machine, and the installed qcow2 grows to ~12G — on tmpfs that is 12G of RAM. Keep the path short, because the QMP socket hits the 108-byte `AF_UNIX` limit:

```bash
export IONIX_VM_RUNDIR=/home/ion/.ionix-vm
```

## Phase 1 — clean build

```bash
./clean.sh
./docker-build.sh
```

Redirect to a log and run it with `run_in_background: true`; it will outlive many turns. Prefer `docker-build.sh` over `sudo ./build.sh` — it pins the toolchain and refreshes `archlinux-keyring` first, avoiding the stale-mirror 404s a cached image otherwise hits.

A full clean build takes roughly **an hour**. Calamares dominates it; the rest are quick.

The build ends with the ISO in `out/`. `build-aur.sh` deliberately exits non-zero listing `FAILED_PACKAGES` rather than letting mkarchiso fail later with a bare `target not found`, so read the tail of the output even when an ISO appears:

```bash
grep -nE "^ERROR|FAILED|target not found" build.log
```

`ERROR` lines from a package's own test suite are not build failures — a package whose pytest collection breaks can still package cleanly. Only a `FAILED_PACKAGES` block or a non-zero exit means the build failed.

If you want a live signal rather than silence, keep the filter tight — completions and failures, nothing from `makepkg` itself:

```bash
tail -f -n 0 build.log | grep -E --line-buffered \
  "^==> Successfully built:|^ERROR|FAILED|target not found|^==> AUR build complete"
```

## Phase 2 — headless install

`out/` is root-owned after a docker build, so `sudo -n ls out/` may be needed to find the ISO. Boot it on a fresh disk:

```bash
V=.claude/skills/full-pipeline-test/scripts/vmctl.py
python3 $V start --iso out/ionix-*.iso --fresh-disk
```

`--fresh-disk` recreates both the qcow2 and the EFI vars, so every run starts from a truly blank machine. Everything lands in `$IONIX_VM_RUNDIR` (see Phase 0 — do not leave it on tmpfs).

Then loop: **screenshot → read it → act on what you actually see.** Never click blind coordinates from this document; the Calamares theme and the resolution both move things around.

```bash
python3 $V shot  "$IONIX_VM_RUNDIR/s.png"                  # single frame
python3 $V watch "$IONIX_VM_RUNDIR/s.png" --timeout 300    # until the screen stops changing
```

Read every screenshot with the Read tool before deciding the next action. **Name every frame you keep `NN-what-it-is.png`, numbered in run order** — those files and those names become the Phase 5 gallery, so naming them properly as you go costs nothing and saves reconstructing the run later.

Early boot has no display surface at all, so the first `screendump` fails with `no surface`. That is normal — wait for it rather than concluding the VM is broken:

```bash
until python3 $V shot "$IONIX_VM_RUNDIR/probe.png" >/dev/null 2>&1; do sleep 3; done
```

Batch the mechanical steps into one call (`click` → `sleep` → `shot`) so a page costs one turn, not three. Widget-level tricks that work here: Qt combo boxes and list widgets both support **type-ahead** — open the popup, type the first few characters, press Return. That is far more reliable than scrolling a 40-item timezone list by pixel.

### What the live ISO does on its own

systemd-boot auto-selects `01-ionix-linux.conf` → autologin as `liveuser` on tty1 → fish starts Hyprland via UWSM → `ionix-first-login` launches **Calamares automatically** about 2 s in (it only does this when `/run/archiso` exists). You do not need to start the installer; just wait for it. Boot to installer is typically 1–3 minutes under software rendering.

### Values to enter

| Page | Setting |
|---|---|
| welcome | continue |
| locale | Region **Europe**, Zone **Copenhagen**; language **Danish** (`da_DK.UTF-8`) |
| keyboard | **Danish** layout |
| partition | **Erase disk** on the single virtio disk (`/dev/vda`) |
| users | Full name **Lucasion**, username **ion**, hostname **ionix**, password **ionix1234** (twice) |
| personalize | leave the defaults (Ionix theme, bar at the theme default) unless testing that path |
| software | leave everything off for a baseline run; each bundle adds a full `pacman -Syu` plus its download to the install time |
| summary | confirm; `prompt-install: true` means an extra confirmation dialog appears |

**Leave the welcome page's language dropdown on American English.** It sets the *installer UI* language, and switching it renames every button you are about to click. The Danish system locale is set on the Location page instead, which leaves the UI drivable while still exercising the locale path.

The Location page's flow, in order — the zone and the locale are separate settings and each has its own trap:

1. Region combo → type-ahead or click **Europe**. The zone then falls back to Amsterdam, *not* to whatever you want.
2. Zone combo → open it, type `Copenhagen`, Return.
3. System language now auto-follows to **English (Denmark)** (`en_DK.UTF-8`) — close but wrong. Click the upper **Change…** button, click into the locale list, type `da_DK`, click **OK**.
4. Confirm both footer lines read *dansk (Danmark)* before moving on. The numbers/dates line follows the zone on its own; only the language line needs the dialog.

The keyboard page then shows **Danish/Default already selected**, inherited from the locale — no action needed.

Two traps on the users page: the username and hostname fields **auto-derive from the full name**, so typing `Lucasion` yields `lucasion`/`lucasion-standardpc`. Click each field, `ctrl-a`, then type the real value. And `doReusePassword: true` means the root password follows the user password — leave that checkbox alone. `ionix1234` passes the strong-password check.

The other trap is the keyboard layout: once the keyboard page applies **Danish**, QEMU's `send-key` still emits US scancodes and the guest remaps them. Every value in the table is alphanumeric, so it survives — but **any punctuation typed after that page comes out wrong**, in the installer and in the installed system alike. See "Commands that survive the Danish layout" in Phase 4.

Installation itself takes 10–30 minutes — about **14** on this hardware. Watch it without holding the monitor open (see the QMP single-client note): background a long `watch`, then read the PNG it keeps rewriting whenever you want to see progress. A mid-install error then gets captured rather than inferred.

### Shut down on success

When the **finished** page appears, screenshot it as proof, then:

```bash
python3 $V powerdown          # ACPI request; lets the live session unmount cleanly
python3 $V wait-off --timeout 180
```

If the ACPI request is ignored (the live session has no handler bound), `python3 $V quit` force-stops it. That is safe here — the install is already committed to disk — but note it in the report.

## When something fails: diagnose, fix, retry

Work the evidence in this order:

1. **The screenshot** — Calamares reports the failing module and its error inline.
2. **`$IONIX_VM_RUNDIR/serial.log`** — kernel console. Note that the Ionix kernel cmdline has no `console=ttyS0`, so this goes quiet after systemd-boot hands off; a silent serial log is normal and not evidence of a hang.
3. **`$IONIX_VM_RUNDIR/qemu.log`** — QEMU's own stderr, for host-side problems.
4. **Inside the still-running live session** — `super-t` opens kitty; `ionix-install` tees to `/tmp/calamares-debug.log`, and Calamares also writes `~/.cache/calamares/session.log`. Read them on screen with `less`/`tail`.
5. **Offline, after shutdown** — mount the qcow2 to inspect what actually landed:
   ```bash
   sudo modprobe nbd max_part=8
   sudo qemu-nbd --connect=/dev/nbd0 "$IONIX_VM_RUNDIR/ionix-test.qcow2"
   sudo mount /dev/nbd0p2 /mnt        # root; p1 is the ESP
   # ... inspect ...
   sudo umount /mnt && sudo qemu-nbd --disconnect /dev/nbd0
   ```

Fix the cause in the repo, then retry at the **cheapest sufficient level**: a change under `profiles/*/airootfs/`, `system/` or a `packages.x86_64` needs only `./docker-build.sh` (sentinels keep the AUR packages warm) — not `./clean.sh`. Only re-clean if the local repo itself is suspect. Then re-run Phase 2 with `--fresh-disk`.

Failures that trace to a real repo bug should be fixed in the repo, not worked around in the VM. Report anything you change.

## Phase 4 — boot the installed system and exercise it

Start again with **no ISO attached** and **no `--fresh-disk`**, so it boots the installed disk:

```bash
python3 $V start --disk "$IONIX_VM_RUNDIR/ionix-test.qcow2"
```

GRUB → autologin as `ion` → Hyprland. `/etc/hypr/scripts/init.sh` runs `hyprlock` whenever `/run/archiso` is absent, so **the installed system lands on the lock screen** — the big clock with a password field. That is the screen to type into:

```bash
python3 $V watch "$IONIX_VM_RUNDIR/lock.png" --timeout 300
python3 $V type 'ionix1234' --enter
```

Then exercise the desktop, screenshotting after each step. Allow generous settling time; rendering is software-backed here.

| Action | Input |
|---|---|
| Terminal (kitty) | `super-t` |
| Browser (Chrome) | `super-w` |
| File manager (ioexplorer) | `super-e` |
| btop in kitty | `super-b` |
| Start menu / launcher | `alt-spc` (spotlight), or click the bar's leftmost launcher button |
| Switch workspace | `super-1` … `super-9` |
| Close window | `super-q` |
| Toggle floating | `super-spc` |
| Fullscreen | `super-f` |
| Notification centre | `super-n` |
| Clipboard (copyq) | `super-v` |
| Reload Hyprland | `ctrl-super-r` |
| Restart the Quickshell bar | `super-shift-b` |
| Cycle wallpaper | `super-alt-w` |
| Wallpaper picker (zenity) | `ctrl-super-w` |

Worth covering, since these are the parts most likely to regress:

- **The Quickshell bar** — click the audio, clock, bluetooth and battery indicators to open their popouts. Only one popout opens at a time by design, so the first click after a popout is open just closes it; click again to open the next one. Bluetooth and battery have nothing to show in a VM. The green tray icon is a real tray applet, not a Quickshell module, and does not open a popout — that is not a defect.
- **Theme switching** — `ionixtheme winix`, then `ionixtheme ionix`. Screenshot between the two. Winix moves the bar to a bottom centred taskbar and changes the date format; switching back must restore the bar *and* recover `kitty.conf` from the backup the styler made on the way in.
- **A real terminal task** — `fastfetch` is the single most informative frame in the run. It confirms in one screen that the system is genuinely functional and that the install choices landed.

### Wallpaper round-trip through the browser

The most end-to-end thing the desktop can be asked to do: fetch an image off the web and make it the wallpaper. It crosses the browser, the download path, the file chooser and the compositor's background layer in one go.

1. `super-w`, dismiss the keyring prompt and the restore-pages bubble.
2. Click the omnibox, type `linux wallpaper`, Return. **No punctuation needed** — the omnibox searches directly. Google shows a Danish consent wall; *Afvis alle* rejects.
3. Click **Billeder** (Images), click a thumbnail to open the preview panel.
4. Right-click the large preview → **Gem billede som…** → the GTK save dialog defaults to `~/Downloads` → **Save**.
5. `super-3` (or any empty workspace), then `ctrl-super-w`.
6. Pick the file, **OK**, and allow ~2 s for `awww`'s wave transition.

**Confirming it actually took is the subtle part.** The wallpaper fills the same area a fullscreen window would, so a screenshot alone is ambiguous. Two reliable tells:

- Switch to a workspace holding a real window and back — the two screens must differ.
- Better, close every window (`super-q`). If the image is still there with no window icons left in the bar, it is the wallpaper.

#### Known blockers, verified 5 Aug 2026

This flow **cannot be completed exactly as written**, for two independent reasons. Both are real findings about the distro, not harness problems:

- **Google Images serves AVIF.** Every image saved through *Gem billede som…* lands as `.avif`, whatever the source site hosts. `ionix-wallpaper` runs zenity with `--file-filter="*.jpg *.jpeg *.png *.gif"` and offers no *All files* entry, so the downloaded file is invisible in the picker. `~/Downloads` looks empty even though the file is right there.
- **`~/Pictures/Wallpapers` ships empty.** The script `mkdir -p`s it and points zenity at it, so the picker opens on an empty folder with nothing to choose.

To exercise the wallpaper path itself despite this, make a PNG locally — `grim` with no arguments writes `~/Pictures/YYYYMMDD_HHhMMmSSs_grim.png`, needs no punctuation, and is picked up by the filter. That is how the mechanism was confirmed working: picker → `awww` → background layer all function correctly once given a supported file.

Do not "fix" this by widening the filter without first checking whether `awww` can decode AVIF. Widening it so the file becomes selectable, only for the wallpaper to fail to render, is worse than the current honest rejection.

### Commands that survive the Danish layout

The guest remaps punctuation, so prefer commands that are alphanumeric plus spaces. These are safe:

```
fastfetch          ionixtheme winix          ionixtheme ionix
```

`ionixtheme --list` and `pacman -Q | wc -l` are **not** — the US `-` key produces `+` and `|` needs AltGr on a key `vmctl` cannot address. `fastfetch` already reports the package count, so it covers what `pacman -Q | wc -l` would have. If you genuinely need punctuation, build the keystrokes with `key` using the Danish key positions rather than fighting `type`.

### Baseline to compare against

From the 5 Aug 2026 run, as reported by `fastfetch` on the installed system. A large drift here is worth investigating:

| | |
|---|---|
| Packages | 1274 (pacman) |
| Kernel | 7.1.5-arch1-2 |
| WM | Hyprland 0.56.1 (Wayland) |
| Shell | fish 4.8.1 |
| Terminal | kitty 0.48.2 |
| Disk used | ~11.5 GiB of 62.2 GiB, ext4 |
| Locale | `da_DK.UTF-8` |

Finish with `python3 $V powerdown && python3 $V wait-off`.

## Phase 5 — publish the run

The screenshots are the evidence, so end by making them viewable in one place rather than leaving 36 PNGs in a scratch directory. `scripts/make-gallery.py` turns them into a single self-contained HTML page — every image downscaled, JPEG'd and inlined as a data URI, so it survives the Artifact CSP:

```bash
python3 .claude/skills/full-pipeline-test/scripts/make-gallery.py manifest.json run.html
```

Then publish `run.html` with the Artifact tool. `scripts/example-manifest.json` is the real manifest from the 5 Aug 2026 run — copy it and edit rather than writing one from scratch. The manifest shape is documented in the script's docstring.

Guidance that makes the page worth reading:

- **The caption is the point.** Write what each frame *proves*, not what it depicts. "Defaults to America / New York" is weak; "the progress text is already Danish, so the locale took effect during the install itself" is the sentence someone actually wants.
- **Include the failures and the odd results**, clearly labelled. A gallery that only shows green is not evidence.
- Group by pipeline phase and number frames within each phase — the numbering encodes real sequence, which is the one case where numbered markers earn their place.
- Phase 1 has no screenshots. Cover it in the header notes with the facts that matter: packages rebuilt, exit status, ISO name and size.
- Size budget is 16 MB including base64's one-third inflation. At the script's defaults (1920px, quality 88) a 36-frame run lands near 5 MB, so quality is rarely worth cutting — the frames contain small terminal text that has to stay legible.
- Style is already handled: the page uses the Ionix palette from `CLAUDE.md` and ships both light and dark themes. Don't re-theme it.

Report the URL along with a short written summary, and point at the two or three frames worth jumping straight to.

## vmctl reference

```
start [--iso F] [--disk F] [--fresh-disk] [--memory 8G] [--cpus 4] [--width W --height H]
shot PATH                      write a PNG screenshot
watch PATH [--timeout S] [--stable S]   screenshot until the screen stops changing
key K [K...]                   combos: ret esc tab super-t ctrl-alt-f2 super-shift-b
type "TEXT" [--enter]          literal typing (US scancodes; see the layout trap)
click X Y [--button B] [--double] / move X Y / scroll up|down [N]
powerdown | wait-off | status | quit
```

Coordinates are framebuffer pixels read straight off the screenshots — `click` re-reads the live framebuffer size each time and converts, so they stay correct if the resolution changes mid-run.

Practical notes:

- Only one VM at a time; `start` refuses if one is live. `quit` before starting another.
- `key`/`type` never fail loudly when the guest ignores them — always confirm with a screenshot rather than assuming a keystroke landed.
- Never `pkill -f` a pattern that also matches your own shell command line; it kills the tool call. Use `vmctl.py quit`.
- The display comes up at whatever mode the firmware picks (often 1280x800), not necessarily the requested `--width/--height`.
- QEMU's QMP socket serves **one client at a time**. A backgrounded `watch` holds it, so a
  concurrent `shot`/`click` just blocks until it times out. To see the screen mid-`watch`, read
  the PNG `watch` is already rewriting; to act, stop the `watch` first.
- `watch` often never settles on the installed desktop, because the bar clock repaints every
  minute. Give it `--stable` well under 60s, or skip it and poll `shot` on a timer.
- The VM runs 2D `virtio-vga` by default. `--gl` swaps in `virtio-vga-gl`/`egl-headless`, which
  is faster in the guest but makes **every screenshot fail with `screendump: no surface`** the
  moment the guest's virtio-gpu driver takes over the scanout. Only pass it if you do not need
  screenshots after boot.
- Put `IONIX_VM_RUNDIR` on real storage. The default `/tmp` is usually tmpfs, and the installed
  qcow2 grows to ~12G — that is 12G of RAM.
