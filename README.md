# Build dependencies

```bash
sudo pacman -S --needed --noconfirm meson python cmake extra-cmake-modules rust go cargo base-devel git nodejs npm gobject-introspection
```

> **Note:** `gobject-introspection` from the Arch repos is compiled against the system Python 3.14.
> Python 3.14 must be installed (`/usr/bin/python3.14`) but does **not** need to be your default.
> The build script automatically uses `python3.14` for AUR builds without changing your system default.

## Python dependencies

```bash
sudo python -m ensurepip # If necessary
sudo python -m pip install meson setuptools
```
