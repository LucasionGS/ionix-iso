#!/usr/bin/env bash
# Ionix AUR Package Builder
# Fetches PKGBUILDs from AUR and builds packages into a local repository.
# Must be run as root (creates a temporary build user internally).

set -euo pipefail

LOCAL_REPO="${1:?Usage: build-aur.sh <local-repo-path>}"
LOCAL_REPO="$(realpath "$LOCAL_REPO")"
mkdir -p "$LOCAL_REPO"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$(mktemp -d /tmp/ionix-aur-build.XXXXXX)"
BUILD_USER="ionix-builder"

# gobject-introspection's _giscanner.so is compiled against the system python
# (python3.14 on current Arch), but the host default python may differ.
# This wrapper ensures builds use the correct Python without affecting the host.
PYTHON_BUILD="$(readlink -f /usr/bin/python3.14 2>/dev/null || echo /usr/bin/python3)"
PYTHON_WRAPPER_DIR="$(mktemp -d /tmp/ionix-python-wrapper.XXXXXX)"
chmod 755 "$PYTHON_WRAPPER_DIR"
ln -sf "$PYTHON_BUILD" "$PYTHON_WRAPPER_DIR/python"
ln -sf "$PYTHON_BUILD" "$PYTHON_WRAPPER_DIR/python3"
chmod +x "$PYTHON_WRAPPER_DIR/python" "$PYTHON_WRAPPER_DIR/python3"

# AUR packages in dependency order
AUR_PACKAGES=(
    "yay"
    "oh-my-posh-bin"
    "calamares"
    "tabby-bin"
    "grim-hyprland-git"                # Replaces grim
    "google-chrome"
    # ionix tooling (openconnect-sso before ionix-openconnect-tools)
    "python-gevent-eventemitter"
    "python-vcrpy"
    "openconnect-sso-git"
    "ionix-openconnect-tools"
    "ionix-file-manager-git"
    "ioexplorer-git"
    # Gaming
    "python-inputs"
    "python-steam"
    "protonup-qt"
)

# Packages built from sources in this repository rather than cloned from the AUR.
# Paths are relative to the repo root and must contain a PKGBUILD.
#
# These are always rebuilt: their sources change with the working tree, so the
# marker-based skip used for AUR packages would hide your own edits. They are
# cheap (no compile step), so this costs nothing against a 35-package AUR run.
#
# A local package may build under a different name than its directory — the shell
# submodule builds `ionix-quickshell-git`, the same name it is published under on
# the AUR, so that the copy shipped on the ISO is upgradable with `yay -Syu` once
# the installer drops the [ionix] repo. Names are read back from each PKGBUILD
# below rather than assumed from the path.
LOCAL_PACKAGES=(
    "submodules/ionix-quickshell"
    "aur/local/shim-signed"            # AUR version 404s; see that PKGBUILD's header
)

# Build-time tools that a PKGBUILD needs but does not declare in makedepends.
# makepkg only installs what is declared, so without this the build dies deep
# inside the package's build() with a "not found in $PATH" error.
# Currently empty; the machinery below stays because the situation recurs.
EXTRA_BUILD_DEPS=()

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cleanup() {
    echo "==> Cleaning up..."
    rm -rf "$BUILD_DIR"
    rm -rf "$PYTHON_WRAPPER_DIR"
    rm -f /etc/sudoers.d/99-ionix-builder
    userdel -r "$BUILD_USER" 2>/dev/null || true
}
trap cleanup EXIT

# Create a temporary non-root user for makepkg
if ! id "$BUILD_USER" &>/dev/null; then
    useradd -m -s /bin/bash "$BUILD_USER"
fi

# Give the build user ownership of the entire build directory
chown -R "$BUILD_USER:$BUILD_USER" "$BUILD_DIR"

# Allow the build user to run pacman without password (needed for makepkg -s)
echo "$BUILD_USER ALL=(ALL) NOPASSWD: /usr/bin/pacman" > /etc/sudoers.d/99-ionix-builder
chmod 440 /etc/sudoers.d/99-ionix-builder

echo "==> Building AUR packages into: $LOCAL_REPO"
echo "==> Build directory: $BUILD_DIR"

if [[ ${#EXTRA_BUILD_DEPS[@]} -gt 0 ]]; then
    echo "==> Installing undeclared build dependencies: ${EXTRA_BUILD_DEPS[*]}"
    # Retry behind a db refresh: in a container image built a while ago the
    # cached sync databases can predate the package being asked for.
    pacman -S --needed --noconfirm "${EXTRA_BUILD_DEPS[@]}" \
        || { pacman -Sy --noconfirm && pacman -S --needed --noconfirm "${EXTRA_BUILD_DEPS[@]}"; }
fi

# Packages whose build failed. Collected rather than fatal on the spot so one
# run reports every broken package; the script exits non-zero at the end.
# Without this, mkarchiso is the first thing to notice, and it only says
# "target not found", giving no hint that the package failed to build hours ago.
FAILED_PACKAGES=()

# Build a prepared PKGBUILD directory, copy the results into the local repo,
# install them so later packages can depend on them, and record the file list in
# the sentinel marker. Shared by the AUR and local-package loops.
#   $1 = package name (marker name)
#   $2 = directory containing the PKGBUILD, already owned by $BUILD_USER
build_pkgdir() {
    local pkg="$1" pkg_dir="$2"
    local marker="$LOCAL_REPO/.built-${pkg}"
    local pkg_files=() f

    # Build the package as the build user with a clean environment.
    # env -i strips all inherited vars (PYTHONPATH, PYTHONHOME, etc.) that
    # root's shell may have set and that break tools like meson.
    #
    # The exit status is checked explicitly: callers invoke this function as
    # `build_pkgdir ... || ...`, which disables errexit for everything inside it,
    # so a failing makepkg would otherwise fall through to the copy loop below
    # and publish whatever stale .pkg.tar.zst happened to be lying around.
    local rc=0
    pushd "$pkg_dir" > /dev/null
    sudo -u "$BUILD_USER" env -i \
        HOME="/home/$BUILD_USER" \
        USER="$BUILD_USER" \
        LOGNAME="$BUILD_USER" \
        PATH="$PYTHON_WRAPPER_DIR:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        PKG_CONFIG_PATH="/usr/lib/pkgconfig:/usr/local/lib/pkgconfig:/usr/share/pkgconfig" \
        TERM="${TERM:-xterm}" \
        makepkg -s --noconfirm --needed --noprogressbar || rc=$?
    popd > /dev/null

    if [[ $rc -ne 0 ]]; then
        echo "ERROR: makepkg failed for $pkg (exit $rc)"
        return 1
    fi

    # Copy all built package files to local repo (handles split packages)
    for f in "$pkg_dir"/*.pkg.tar.zst "$pkg_dir"/*.pkg.tar.xz; do
        [[ -f "$f" ]] || continue
        cp "$f" "$LOCAL_REPO/"
        pkg_files+=("$LOCAL_REPO/$(basename "$f")")
    done

    if [[ ${#pkg_files[@]} -eq 0 ]]; then
        echo "WARNING: No package files found for $pkg"
        return 1
    fi

    # Install the package locally so dependent packages can find it
    pacman -U --noconfirm --overwrite "*" --ask 4 "${pkg_files[@]}"

    # Write sentinel marker with the list of installed package files
    printf '%s\n' "${pkg_files[@]}" > "$marker"

    echo "==> Successfully built: $pkg"
}

for pkg in "${AUR_PACKAGES[@]}"; do
    echo ""
    echo "══════════════════════════════════════════════════"
    echo "  Building: $pkg"
    echo "══════════════════════════════════════════════════"

    PKG_DIR="$BUILD_DIR/$pkg"
    MARKER="$LOCAL_REPO/.built-${pkg}"

    # Skip build if sentinel marker exists (handles split packages correctly)
    if [[ -f "$MARKER" ]]; then
        echo "==> Already built, skipping: $pkg"
        # Re-install from the file list stored in the marker so dependents resolve
        mapfile -t pkg_files < "$MARKER"
        pacman -U --noconfirm --overwrite "*" --ask 4 "${pkg_files[@]}" || true
        continue
    fi

    # Clone the AUR package as the build user
    sudo -u "$BUILD_USER" git clone --depth 1 "https://aur.archlinux.org/${pkg}.git" "$PKG_DIR"

    # If the AUR repo is empty (no PKGBUILD), generate a stub.
    # Some AUR names are reserved but have no content yet. The stub provides the
    # virtual package name (strips the -git suffix) so that metapackages and
    # other dependents can still resolve their dependencies.
    if [[ ! -f "$PKG_DIR/PKGBUILD" ]]; then
        echo "==> WARNING: $pkg has no PKGBUILD (empty AUR repo), generating stub..."
        provides_name="${pkg%-git}"
        cat > "$PKG_DIR/PKGBUILD" << STUBEOF
pkgname=$pkg
pkgver=0.1
pkgrel=1
pkgdesc="Stub: $pkg (empty upstream AUR repo)"
arch=('any')
license=('MIT')
provides=('$provides_name')
conflicts=('$provides_name')
package() { :; }
STUBEOF
        chown "$BUILD_USER:$BUILD_USER" "$PKG_DIR/PKGBUILD"
    fi

    build_pkgdir "$pkg" "$PKG_DIR" || FAILED_PACKAGES+=("$pkg")
done

# ── Local packages (built from this repository) ──────────────────────────────
for pkgpath in "${LOCAL_PACKAGES[@]}"; do
    src="$REPO_ROOT/$pkgpath"
    pkg="$(basename "$pkgpath")"

    echo ""
    echo "══════════════════════════════════════════════════"
    echo "  Building (local): $pkg"
    echo "══════════════════════════════════════════════════"

    if [[ ! -f "$src/PKGBUILD" ]]; then
        echo "ERROR: $src/PKGBUILD not found."
        echo "       This is a git submodule. Fetch it with:"
        echo "         git submodule update --init --recursive"
        exit 1
    fi

    # Copy out of the git tree: makepkg writes pkg/ and src/ next to the PKGBUILD,
    # and it must never do that inside a checkout.
    PKG_DIR="$BUILD_DIR/$pkg"
    rm -rf "$PKG_DIR"
    mkdir -p "$PKG_DIR"
    cp -a "$src/." "$PKG_DIR/"
    # Drop anything a previous in-tree `makepkg` left behind. A stale
    # *.pkg.tar.* in particular makes makepkg refuse with "A package has already
    # been built", and the copy loop would then ship that stale artifact.
    rm -rf "$PKG_DIR/.git" "$PKG_DIR/pkg" "$PKG_DIR/src"
    rm -f "$PKG_DIR"/*.pkg.tar.*

    # Resolve the version here, from the real checkout: .git was just stripped
    # from the copy, so a -git style pkgver() has nothing to read there. The
    # formula must stay identical to the one the package's AUR publish script
    # uses, otherwise the shipped build and the AUR build of the same commit
    # would compare as different versions.
    #
    # safe.directory=* because this script runs as root over a checkout owned by
    # the invoking user, which git otherwise rejects as "dubious ownership". A
    # submodule's .git is a gitlink into the superproject, so the exemption has
    # to cover every path, not just $src.
    if [[ -e "$src/.git" ]]; then
        if ! git -c safe.directory='*' -C "$src" rev-parse HEAD > /dev/null 2>&1; then
            echo "ERROR: $src is a git checkout but its history is unreadable."
            echo "       A -git PKGBUILD there would be versioned from a placeholder."
            FAILED_PACKAGES+=("$pkg")
            continue
        fi
        printf "r%s.%s" \
            "$(git -c safe.directory='*' -C "$src" rev-list --count HEAD)" \
            "$(git -c safe.directory='*' -C "$src" rev-parse --short HEAD)" \
            > "$PKG_DIR/.pkgver"
        echo "==> $pkg version: $(cat "$PKG_DIR/.pkgver")"
    fi

    chown -R "$BUILD_USER:$BUILD_USER" "$PKG_DIR"

    # Always rebuild, and drop any previous artifact first. repo-add below globs
    # the whole directory, so leaving an older build there would make the database
    # entry depend on glob ordering.
    #
    # The built package name is not necessarily the directory name (the shell
    # submodule lives in submodules/ionix-quickshell but builds
    # ionix-quickshell-git), so ask the PKGBUILD instead of guessing. Sourcing it
    # in a subshell is safe: only the variable assignments run, not pkgver() or
    # package().
    mapfile -t pkg_names < <(
        bash -c 'source "$1" > /dev/null 2>&1; printf "%s\n" "${pkgname[@]}"' _ "$PKG_DIR/PKGBUILD"
    )
    rm -f "$LOCAL_REPO/.built-${pkg}"
    for name in "${pkg_names[@]}"; do
        [[ -n "$name" ]] || continue
        rm -f "$LOCAL_REPO/${name}"-*.pkg.tar.*
    done
    # Also sweep an artifact left by an earlier build under the directory name,
    # for packages that have since been renamed (ionix-quickshell ->
    # ionix-quickshell-git). Anchored on a digit so it cannot match the -git
    # package's own r<count>.<hash> files.
    rm -f "$LOCAL_REPO/${pkg}"-[0-9]*.pkg.tar.*

    build_pkgdir "$pkg" "$PKG_DIR" || FAILED_PACKAGES+=("$pkg")
done

# Clean up sudoers entry
rm -f /etc/sudoers.d/99-ionix-builder

# Create/update the repo database
echo ""
echo "==> Creating repository database..."
repo-add "$LOCAL_REPO/ionix.db.tar.gz" "$LOCAL_REPO"/*.pkg.tar.* 2>/dev/null

echo "==> AUR build complete. Packages in: $LOCAL_REPO"
ls -la "$LOCAL_REPO"

if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
    echo ""
    echo "ERROR: ${#FAILED_PACKAGES[@]} package(s) failed to build:"
    printf '  - %s\n' "${FAILED_PACKAGES[@]}"
    echo ""
    echo "They are listed in profile/packages.x86_64, so mkarchiso would fail"
    echo "with 'target not found'. Fix the builds above, or drop the packages."
    exit 1
fi
