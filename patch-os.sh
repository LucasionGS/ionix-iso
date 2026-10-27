#!/bin/bash
# Brings an installed Ionix system up to date with this checkout.
#
# Ionix's own files are packages now (ionix-base-git plus ionix-desktop-git or
# ionix-server-git, built from system/), so this builds them from the working
# tree and installs them with pacman. Pacman then does what this script used to
# do by hand: a config file you edited is kept and the new one written next to
# it as .pacnew, which this script walks you through. On a system installed
# before the packages existed, the first run also takes ownership of the files
# the ISO copied in, and the ionix-base hook moves the old /usr/local copies
# out of the way.
#
# Once the packages are on the AUR, `yay -Syu` does the same from there; this
# script is for trying unpublished changes and for adopting an older install.

set -euo pipefail

AUTO_ACCEPT=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILES_DIR="$SCRIPT_DIR/profiles"
SYSTEM_DIR="$SCRIPT_DIR/system"
TARGET_ROOT=""
VARIANT=""

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Build the Ionix system packages from this checkout and install them.

Options:
  -y               Take every new config file without asking (yours is kept
                   next to it as .pacorig)
  --root PATH      Install into the system mounted at PATH (default: /);
                   skips the package list
  --variant NAME   desktop or server (default: read from the target's
                   /etc/ionix/variant, else desktop)
  -h, --help       Show this help

In interactive mode (default), each config file you changed that the packages
also changed shows a diff and asks which version to keep. Files kept are
listed at the end, with the new version left beside them as .pacnew.
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y) AUTO_ACCEPT=true; shift ;;
        --root) TARGET_ROOT="${2%/}"; shift 2 ;;
        --variant) VARIANT="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1" >&2; usage ;;
    esac
done

if [[ "$EUID" -ne 0 ]]; then
    echo "Error: must be run as root." >&2
    echo "Run: sudo $0 $*" >&2
    exit 1
fi

# Systems installed before the variants existed have no marker: desktop.
if [[ -z "$VARIANT" ]]; then
    VARIANT="$(cat "${TARGET_ROOT}/etc/ionix/variant" 2>/dev/null || echo desktop)"
fi
if [[ "$VARIANT" != desktop && "$VARIANT" != server ]]; then
    echo "Error: unknown variant '$VARIANT' (desktop or server)." >&2
    exit 2
fi

# makepkg refuses to run as root.
BUILD_USER="${SUDO_USER:-nobody}"
[[ "$BUILD_USER" == root ]] && BUILD_USER=nobody

echo "Ionix OS Patcher"
echo "================"
echo "Repo:    $SCRIPT_DIR ($VARIANT)"
echo "Target:  ${TARGET_ROOT:-/}"
if "$AUTO_ACCEPT"; then
    echo "Mode:    auto-accept"
else
    echo "Mode:    interactive"
fi
echo ""

# ---------------------------------------------------------------------------
# Build the system packages
# ---------------------------------------------------------------------------
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

echo "Building the Ionix system packages..."
pacman -S --needed --noconfirm --asdeps librsvg make > /dev/null
cp -a "$SYSTEM_DIR/." "$BUILD_DIR/"
rm -rf "$BUILD_DIR"/{build,pkg,src} "$BUILD_DIR"/*.pkg.tar.*
# The same version aur/build-aur.sh gives an ISO build of this commit.
printf "r%s.%s" \
    "$(git -c safe.directory='*' -C "$SYSTEM_DIR" rev-list --count HEAD -- .)" \
    "$(git -c safe.directory='*' -C "$SYSTEM_DIR" log -1 --format=%h -- .)" \
    > "$BUILD_DIR/.pkgver"
chown -R "$BUILD_USER" "$BUILD_DIR"
(cd "$BUILD_DIR" && sudo -u "$BUILD_USER" makepkg --nodeps --noprogressbar > "$BUILD_DIR/makepkg.log" 2>&1) || {
    echo "Failed to build the packages. makepkg said:" >&2
    tail -20 "$BUILD_DIR/makepkg.log" >&2
    exit 1
}

PKG_FILES=("$BUILD_DIR"/ionix-base-git-*.pkg.tar.* "$BUILD_DIR"/ionix-"$VARIANT"-git-*.pkg.tar.*)

# ---------------------------------------------------------------------------
# Install them
# ---------------------------------------------------------------------------
# Every path the packages ship may already be on disk, unowned, from the ISO
# or an older run of this script. --overwrite lets pacman take those over;
# it only ever applies to these paths, never to another package's files.
overwrite=()
while read -r _ path; do
    overwrite+=(--overwrite "$path")
done < <(for f in "${PKG_FILES[@]}"; do pacman -Qlp "$f"; done)

pacman_args=(-U --noconfirm "${overwrite[@]}")
[[ -n "$TARGET_ROOT" ]] && pacman_args+=(--sysroot "$TARGET_ROOT")

echo "Installing $(for f in "${PKG_FILES[@]}"; do basename "$f" | sed 's/-any\.pkg\.tar\..*//'; done | paste -sd' ')..."
pacman "${pacman_args[@]}" "${PKG_FILES[@]}"
echo ""

# ---------------------------------------------------------------------------
# Merge config files
# ---------------------------------------------------------------------------
kept_files=()

# Config files of ours with a .pacnew beside them: ones you changed and the
# packages changed too, or (on the first run) every one the ISO put there that
# differs from today's.
mapfile -t pacnews < <(
    for f in "${PKG_FILES[@]}"; do
        bsdtar -xOf "$f" .PKGINFO | sed -n 's/^backup = //p'
    done | while IFS= read -r rel; do
        [[ -f "${TARGET_ROOT}/$rel.pacnew" ]] && printf '/%s\n' "$rel"
    done
)

for rel in "${pacnews[@]}"; do
    current="${TARGET_ROOT}${rel}"
    new="$current.pacnew"

    if "$AUTO_ACCEPT"; then
        echo "[UPDATE] $rel (yours kept as $rel.pacorig)"
        mv "$current" "$current.pacorig"
        mv "$new" "$current"
        continue
    fi

    echo "─────────────────────────────────────────────────────"
    echo "CHANGED: $rel"
    echo ""
    diff --color=always -u "$current" "$new" || true
    echo ""
    read -r -p "Take the new version? [y/N/q]: " choice < /dev/tty
    case "$choice" in
        [Yy])
            mv "$new" "$current"
            echo "Updated."
            ;;
        [Qq])
            kept_files+=("$rel")
            break
            ;;
        *)
            kept_files+=("$rel")
            echo "Kept yours; the new version stays as $rel.pacnew."
            ;;
    esac
    echo ""
done

# ---------------------------------------------------------------------------
# Package installation
# ---------------------------------------------------------------------------
# The variant's packages this system does not have yet. `pacman -T` counts a
# package that provides the name, so a renamed or replaced one is not missing.
# Packages it has are left to `yay -Syu`: asking yay for them again would
# upgrade them against a stale database, or swap one built here (shim-signed)
# for an AUR package of a similar name.
#
# The installer removes the NVIDIA stack from a machine without an NVIDIA GPU
# (post-install.d/10-desktop); keep this list in step with the one there, or
# every such machine is offered the drivers back.
NVIDIA_PACKAGES=(nvidia-open nvidia-utils lib32-nvidia-utils egl-wayland libva-nvidia-driver)

missing_packages() {
    local skip=()
    lspci 2>/dev/null | grep -qi nvidia || skip=("${NVIDIA_PACKAGES[@]}")
    cat "$PROFILES_DIR/common/packages.x86_64" "$PROFILES_DIR/$VARIANT/packages.x86_64" \
        | sed 's/[[:space:]]*#.*//; s/[[:space:]]*$//' | grep -v '^$' \
        | grep -vxF -f <(printf '%s\n' "${skip[@]}" "") \
        | xargs pacman -T || true
}

install_packages() {
    local pkgs=("$@")
    echo "Installing ${#pkgs[@]} package(s) with a full yay -Syu: ${pkgs[*]}"
    echo ""
    # yay must not run as root; use SUDO_USER if available. -Syu, never -S
    # alone: new packages built against today's repos need today's libraries.
    if [[ -n "${SUDO_USER:-}" ]]; then
        sudo -u "$SUDO_USER" yay -Syu --needed --noconfirm "${pkgs[@]}"
    else
        yay -Syu --needed --noconfirm "${pkgs[@]}"
    fi
}

# Only install packages when operating on the real root (--root skips this)
if [[ -z "$TARGET_ROOT" ]]; then
    echo "─────────────────────────────────────────────────────"
    mapfile -t missing < <(missing_packages)
    if [[ ${#missing[@]} -eq 0 ]]; then
        echo "Every package in packages.x86_64 is installed."
    elif ! command -v yay &>/dev/null; then
        echo "Warning: yay not found — not installing: ${missing[*]}"
    elif "$AUTO_ACCEPT"; then
        install_packages "${missing[@]}"
    else
        echo "Missing from packages.x86_64: ${missing[*]}"
        read -r -p "Install them (with a full yay -Syu)? [y/N]: " choice < /dev/tty
        if [[ "$choice" == [Yy]* ]]; then
            install_packages "${missing[@]}"
        else
            echo "Skipped package installation."
        fi
    fi
fi

echo "═════════════════════════════════════════════════════"
echo "Patch complete."

if [[ ${#kept_files[@]} -gt 0 ]]; then
    echo ""
    echo "Kept your version of these; the new one is next to each as .pacnew"
    echo "(pacdiff, from pacman-contrib, merges them):"
    printf "  %s\n" "${kept_files[@]}"
fi
