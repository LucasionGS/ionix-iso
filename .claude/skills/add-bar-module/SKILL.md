---
name: add-bar-module
description: Scaffold a new ionix-quickshell bar widget (module) and optional popout panel. Use when adding a widget/indicator to the Quickshell bar, creating a new popout, or wiring a new shell feature into config, icons, settings, and IPC. Encodes the module/popout contracts and all registration touchpoints in submodules/ionix-quickshell.
---

# Adding a bar module to ionix-quickshell

All paths below are under `submodules/ionix-quickshell/ionix/`. A new widget has up to 7 touchpoints — walk them in order. Use `modules/AudioIndicator.qml` as the cleanest reference for the full module+popout pattern.

## 1. The module file — `modules/<Name>.qml`

Contract every bar module follows:

- Root is an `Item` with `property var bar: null` — the bar assigns this in `Loader.onLoaded` (`Bar.qml` does `item.bar = root` directly; note `hasOwnProperty()` is false for QML-declared properties, so the property must exist or every module silently breaks).
- `implicitWidth`/`implicitHeight`, normally `Theme.pillHeight`.
- An `IconButton` (glyph from `Icons.qml`) as the visual.
- If it has a popout: `readonly property bool popoutOpen: Popouts.isOpen("<name>", root.bar?.screen)`, toggle with `Popouts.toggle("<name>", root.bar?.screen)`, and a trailing `<Name>Popout { anchorItem: root; shouldOpen: root.popoutOpen }`.

Match the house style: every QML file opens with a prose header comment explaining *why* it exists, not what it does.

## 2. Registration — `config/Config.qml` + `defaults.json`

Bar composition is config-driven: `Bar.qml` loads `Config.modules.{left,center,right}` entries by filename. Add the module name to the right section of the shipped defaults in `Config.qml`, then mirror the same change into `defaults.json` — that file is documentation-only (not read at runtime) but must stay in sync.

## 3. Glyphs — `config/Icons.qml`

Add any Nerd Font glyphs to the tables in `Icons.qml` (deliberately separate from `Theme.qml`). Picker logic goes here as pure functions.

## 4. Optional popout — `popouts/<Name>Popout.qml`

Root at `components/Popout.qml`. Rules that are easy to violate:

- Popouts are single-open by design: `services/Popouts.qml` holds one `current` name + screen; opening one closes the rest. Pick a unique name string.
- **Never assign `shouldOpen = false`** — that overwrites the binding and the panel never reopens. Always close via `Popouts.close()`.
- `Popout` already provides click-outside dismissal (`HyprlandFocusGrab`), Escape handling, exit-animation hold, and a `maxContentHeight` cap at half the screen — don't reimplement these.

## 5. Optional user-facing toggle — `popouts/StartPopout.qml` + `shell.qml`

If the widget is user-toggleable, add a settings-page row in `StartPopout.qml` (settings write to `settings.json`, the only file the shell writes) and, if it should be scriptable, an `IpcHandler` entry in `shell.qml` following the existing `audio`/`brightness`/etc. handlers.

## API traps

- `UPowerDevice.percentage`, `WifiNetwork.signalStrength`, `BluetoothDevice.battery` are **0..1 fractions**, not 0..100.
- A Pipewire node's `audio` stays null without a `PwObjectTracker` covering it (see `services/Audio.qml`).
- Hyprland runs the **Lua** config parser here, so raw `Hyprland.dispatch("workspace 3")` fails to parse — go through `services/Compositor.qml`, which quotes arguments when `Hyprland.usingLua`.
- Colors/spacing/durations come from `config/Theme.qml` tokens (`Theme.c(...)` surfaces, `sp1..sp7`, `durFast/durSlide/durSlow`) — never hardcode hex or pixel values.

## Dev loop (no ISO rebuild)

```bash
make -C submodules/ionix-quickshell dev   # symlinks tree into ~/.config/quickshell/ionix
qs -c ionix                               # runs it; hot-reloads on save
make -C submodules/ionix-quickshell check # only real checker; needs a live Wayland session
rm ~/.config/quickshell/ionix             # revert to packaged copy at /etc/xdg/quickshell/ionix
```

Errors report as `file:line` in the `qs` process output; the runtime is the only type checker (Quickshell types aren't on a qmllint import path). Do not run `qmlformat`/`make lint` — it mangles formatting on purpose per the Makefile comment.
