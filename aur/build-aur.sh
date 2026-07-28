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
# libastal-io-git is the foundation; all other astal libs depend on it.
# libastal-git (split) provides libastal + libastal-4; required by aylurs-gtk-shell-git.
# libastal-meta is a metapackage requiring every libastal-* sublib.
AUR_PACKAGES=(
    "yay"
    "oh-my-posh-bin"
    "calamares"
    "shim-signed"
    "tabby-bin"
    "grim-hyprland-git"                # Replaces grim
    # astal core (build order: io first, then base, then everything else)
    "libastal-io-git"
    "libastal-git"
    "libastal-4-git"                   # separate AUR pkg providing libastal-4
    "libcava-git"                      # required by libastal-cava-git
    "appmenu-glib-translator-git"      # required by libastal-tray-git
    "libastal-apps-git"
    "libastal-auth-git"
    "libastal-battery-git"
    "libastal-bluetooth-git"
    "libastal-cava-git"
    "libastal-hyprland-git"
    "libastal-mpris-git"
    "libastal-network-git"
    "libastal-notifd-git"
    "wl-vapi-gen"
    "libastal-wl-git"
    "libastal-powerprofiles-git"
    "libastal-river-git"
    "libastal-greet-git"
    "libastal-tray-git"
    "libastal-wireplumber-git"
    "libastal-gjs-git"
    "libastal-meta"
    "aylurs-gtk-shell-git"
    "google-chrome"
    # ionix tooling (openconnect-sso before ionix-openconnect-tools; ionix-openconnect-tools before ionix-shell)
    "python-gevent-eventemitter"
    "python-vcrpy"
    "openconnect-sso-git"
    "ionix-openconnect-tools"
    "ionix-shell"
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
LOCAL_PACKAGES=(
    "submodules/ionix-quickshell"
)

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
    pushd "$pkg_dir" > /dev/null
    sudo -u "$BUILD_USER" env -i \
        HOME="/home/$BUILD_USER" \
        USER="$BUILD_USER" \
        LOGNAME="$BUILD_USER" \
        PATH="$PYTHON_WRAPPER_DIR:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        PKG_CONFIG_PATH="/usr/lib/pkgconfig:/usr/local/lib/pkgconfig:/usr/share/pkgconfig" \
        TERM="${TERM:-xterm}" \
        makepkg -s --noconfirm --needed --noprogressbar
    popd > /dev/null

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
    # Some astal sub-packages exist as reserved AUR names but have no content yet.
    # The stub provides the virtual package name (strips -git suffix) so that
    # libastal-meta and other dependents can resolve their dependencies.
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

    build_pkgdir "$pkg" "$PKG_DIR" || continue
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
    rm -rf "$PKG_DIR/.git" "$PKG_DIR/pkg" "$PKG_DIR/src"
    chown -R "$BUILD_USER:$BUILD_USER" "$PKG_DIR"

    # Always rebuild, and drop any previous artifact first. repo-add below globs
    # the whole directory, so leaving an older build there would make the database
    # entry depend on glob ordering.
    rm -f "$LOCAL_REPO/.built-${pkg}" "$LOCAL_REPO/${pkg}"-[0-9]*.pkg.tar.*

    build_pkgdir "$pkg" "$PKG_DIR" || continue
done

# Clean up sudoers entry
rm -f /etc/sudoers.d/99-ionix-builder

# Create/update the repo database
echo ""
echo "==> Creating repository database..."
repo-add "$LOCAL_REPO/ionix.db.tar.gz" "$LOCAL_REPO"/*.pkg.tar.* 2>/dev/null

echo "==> AUR build complete. Packages in: $LOCAL_REPO"
ls -la "$LOCAL_REPO"
