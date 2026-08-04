---
name: full-pipeline-test
description: Run the complete Ionix release pipeline end to end — clean, docker build the ISO, install it headlessly in QEMU by driving Calamares with screenshots, shut down, then boot the installed system and exercise the desktop. Use when asked for a full pipeline compile, a full build-and-install test, an end-to-end/release validation, or to verify an ISO actually installs and boots. Includes a diagnose-fix-retry loop on failure.
---

# Full pipeline compile and install test

Four phases, run in order: **build → headless install → shutdown → boot and exercise the desktop**. Phases 2 and 4 are driven entirely through `scripts/vmctl.py`, which runs QEMU with no display and controls it over QMP: keystrokes, absolute mouse clicks, and PNG screenshots you read back with the Read tool.

Budget several hours. Phase 1 dominates: `./clean.sh` deletes `localrepo/`, including every `.built-*` sentinel, so all ~41 AUR packages rebuild from source. Say this to the user before starting — it is the single most expensive thing in the repo, and if the goal is only "test the current ISO", skip `clean.sh` and reuse `out/`.

## Phase 0 — preflight

```bash
git submodule update --init --recursive     # as the normal user; build.sh runs as root and refuses to fetch
df -h /home /tmp                            # need ~40G free: ISO build + a 64G sparse qcow2
ls /dev/dri/renderD*                        # vmctl needs a render node for egl-headless
```

## Phase 1 — clean build

```bash
./clean.sh
./docker-build.sh
```

Run the build with `run_in_background: true` and poll it; it will outlive many turns. Prefer `docker-build.sh` over `sudo ./build.sh` — it pins the toolchain and refreshes `archlinux-keyring` first, avoiding the stale-mirror 404s a cached image otherwise hits.

The build ends with the ISO in `out/`. `build-aur.sh` deliberately exits non-zero listing `FAILED_PACKAGES` rather than letting mkarchiso fail later with a bare `target not found`, so read the tail of the output even when an ISO appears.

## Phase 2 — headless install

`out/` is root-owned after a docker build, so `sudo -n ls out/` may be needed to find the ISO. Boot it on a fresh disk:

```bash
V=.claude/skills/full-pipeline-test/scripts/vmctl.py
python3 $V start --iso out/ionix-*.iso --fresh-disk
```

`--fresh-disk` recreates both the qcow2 and the EFI vars, so every run starts from a truly blank machine. Everything lives in `/tmp/ionix-vm/` (override with `IONIX_VM_RUNDIR`, but keep the path short — the QMP socket hits the 108-byte AF_UNIX limit).

Then loop: **screenshot → read it → act on what you actually see.** Never click blind coordinates from this document; the Calamares theme and the resolution both move things around.

```bash
python3 $V watch /tmp/ionix-vm/s.png --timeout 300   # blocks until the screen stops changing
python3 $V shot /tmp/ionix-vm/s.png                  # single frame
```

Read every screenshot with the Read tool before deciding the next action, and keep the interesting ones under distinct names (`01-welcome.png`, `02-locale.png`, …) so the run is reviewable afterwards.

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
| summary | confirm; `prompt-install: true` means an extra confirmation dialog appears |

Two traps on the users page: the username and hostname fields **auto-derive from the full name**, so typing `Lucasion` yields `lucasion`/`lucasion-pc`. Clear each field (`ctrl-a` then type, or hold `backspace`) before entering `ion` and `ionix`. And `doReusePassword: true` means the root password follows the user password — leave that checkbox alone.

The other trap is the keyboard layout: once the keyboard page applies **Danish**, QEMU's `send-key` still emits US scancodes and the guest remaps them. Every value above is alphanumeric, so it survives — but any punctuation typed after that page will come out wrong.

Installation itself takes 10–30 minutes (`unpackfs` then `ionix-post-install` in the chroot). Use `watch` with a long timeout, and screenshot periodically so a mid-install error is captured rather than inferred.

### Shut down on success

When the **finished** page appears, screenshot it as proof, then:

```bash
python3 $V powerdown          # ACPI request; lets the live session unmount cleanly
python3 $V wait-off --timeout 180
```

If the ACPI request is ignored (the live session has no handler bound), `python3 $V quit` force-stops it. That is safe here — the install is already committed to disk — but note it in the report.

## Phase 3 — on failure: diagnose, fix, retry

Work the evidence in this order:

1. **The screenshot** — Calamares reports the failing module and its error inline.
2. **`/tmp/ionix-vm/serial.log`** — kernel console. This is the only view once the framebuffer has handed off, and the place a boot failure (missing module, failed mount, panic) actually shows up.
3. **`/tmp/ionix-vm/qemu.log`** — QEMU's own stderr, for host-side problems.
4. **Inside the still-running live session** — `super-t` opens kitty; `ionix-install` tees to `/tmp/calamares-debug.log`, and Calamares also writes `~/.cache/calamares/session.log`. Read them on screen with `less`/`tail`.
5. **Offline, after shutdown** — mount the qcow2 to inspect what actually landed:
   ```bash
   sudo modprobe nbd max_part=8
   sudo qemu-nbd --connect=/dev/nbd0 /tmp/ionix-vm/ionix-test.qcow2
   sudo mount /dev/nbd0p2 /mnt        # root; p1 is the ESP
   # ... inspect ...
   sudo umount /mnt && sudo qemu-nbd --disconnect /dev/nbd0
   ```

Fix the cause in the repo, then retry at the **cheapest sufficient level**: a change under `profile/airootfs/` or `packages.x86_64` needs only `./docker-build.sh` (sentinels keep the AUR packages warm) — not `./clean.sh`. Only re-clean if the local repo itself is suspect. Then re-run Phase 2 with `--fresh-disk`.

Failures that trace to a real repo bug should be fixed in the repo, not worked around in the VM. Report anything you change.

## Phase 4 — boot the installed system and exercise it

Start again with **no ISO attached** and **no `--fresh-disk`**, so it boots the installed disk:

```bash
python3 $V start --disk /tmp/ionix-vm/ionix-test.qcow2
```

GRUB → autologin as `ion` → Hyprland. `/etc/hypr/scripts/init.sh` runs `hyprlock` whenever `/run/archiso` is absent, so **the installed system lands on the lock screen** — the big clock with a password field. That is the screen to type into:

```bash
python3 $V watch /tmp/ionix-vm/lock.png --timeout 300
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

Worth covering, since these are the parts most likely to regress:

- **The Quickshell bar** — click the audio, network, bluetooth, battery and clock indicators to open their popouts. Only one popout opens at a time by design.
- **Theme switching** — in kitty run `ionixtheme --list`, then `ionixtheme winix` and `ionixtheme ionix`. Screenshot between the two; the bar, kitty and Hyprland borders should all restyle live.
- **A real terminal task** — `fastfetch` or `pacman -Q | wc -l` confirms the installed system is genuinely functional, not just drawing.

Finish with `python3 $V powerdown && python3 $V wait-off`.

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
