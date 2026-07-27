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

    # Build the package as the build user with a clean environment.
    # env -i strips all inherited vars (PYTHONPATH, PYTHONHOME, etc.) that
    # root's shell may have set and that break tools like meson.
    pushd "$PKG_DIR" > /dev/null
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
    pkg_files=()
    for f in "$PKG_DIR"/*.pkg.tar.zst "$PKG_DIR"/*.pkg.tar.xz; do
        [[ -f "$f" ]] || continue
        cp "$f" "$LOCAL_REPO/"
        pkg_files+=("$LOCAL_REPO/$(basename "$f")")
    done

    if [[ ${#pkg_files[@]} -eq 0 ]]; then
        echo "WARNING: No package files found for $pkg"
        continue
    fi

    # Install the package locally so dependent AUR packages can find it
    pacman -U --noconfirm --overwrite "*" --ask 4 "${pkg_files[@]}"

    # Write sentinel marker with the list of installed package files
    printf '%s\n' "${pkg_files[@]}" > "$MARKER"

    echo "==> Successfully built: $pkg"
done

# Clean up sudoers entry
rm -f /etc/sudoers.d/99-ionix-builder

# Create/update the repo database
echo ""
echo "==> Creating repository database..."
repo-add "$LOCAL_REPO/ionix.db.tar.gz" "$LOCAL_REPO"/*.pkg.tar.* 2>/dev/null

echo "==> AUR build complete. Packages in: $LOCAL_REPO"
ls -la "$LOCAL_REPO"
