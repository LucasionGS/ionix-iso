#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  Ionix ISO Build Script                                     ║
# ║  Builds the Ionix live/installer ISO using archiso.         ║
# ║  Must be run as root: sudo ./build.sh                       ║
# ╚══════════════════════════════════════════════════════════════╝

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR="${SCRIPT_DIR}/profile"
WORK_DIR="${SCRIPT_DIR}/work"
OUT_DIR="${SCRIPT_DIR}/out"
LOCAL_REPO="${SCRIPT_DIR}/localrepo"
AUR_DIR="${SCRIPT_DIR}/aur"
ASSETS_DIR="${SCRIPT_DIR}/assets"

# ── Preflight checks ─────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run as root (sudo ./build.sh)"
    exit 1
fi

for cmd in mkarchiso makepkg git repo-add; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: Required command '$cmd' not found."
        echo "Install archiso and base-devel: pacman -S archiso base-devel git"
        exit 1
    fi
done

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Ionix ISO Builder                                      ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# ── Step 1: Build AUR packages ───────────────────────────────
echo "==> Step 1/4: Building AUR packages..."
chmod +x "${AUR_DIR}/build-aur.sh"
"${AUR_DIR}/build-aur.sh" "$LOCAL_REPO"

# ── Step 2: Patch pacman.conf with local repo path ───────────
echo ""
echo "==> Step 2/4: Configuring local repository..."

# Copy the local repo to a location accessible during build
REPO_MOUNT="/tmp/ionix-localrepo"
rm -rf "$REPO_MOUNT"
cp -r "$LOCAL_REPO" "$REPO_MOUNT"

echo "    Local repo at: $REPO_MOUNT"

# ── Step 3: Copy branding assets into airootfs ────────────────
echo ""
echo "==> Step 3/4: Copying branding assets..."

# Convert SVG wallpaper to PNG if rsvg-convert is available, otherwise copy SVG
WALLPAPER_DEST="${PROFILE_DIR}/airootfs/usr/local/share/ionix/wallpaper.png"
if command -v rsvg-convert &>/dev/null && [[ -f "${ASSETS_DIR}/wallpaper.svg" ]]; then
    rsvg-convert -w 3840 -h 2160 "${ASSETS_DIR}/wallpaper.svg" -o "$WALLPAPER_DEST"
    echo "    Converted wallpaper SVG to PNG (3840x2160)"
elif command -v magick &>/dev/null && [[ -f "${ASSETS_DIR}/wallpaper.svg" ]]; then
    magick "${ASSETS_DIR}/wallpaper.svg" -resize 3840x2160 "$WALLPAPER_DEST"
    echo "    Converted wallpaper SVG to PNG (3840x2160)"
elif [[ -f "${ASSETS_DIR}/wallpaper.png" ]]; then
    cp "${ASSETS_DIR}/wallpaper.png" "$WALLPAPER_DEST"
    echo "    Copied wallpaper PNG"
else
    echo "    WARNING: No wallpaper found. Generating a solid color placeholder."
    # Generate a simple solid purple PNG using ImageMagick or a fallback
    if command -v magick &>/dev/null; then
        magick -size 3840x2160 'xc:#1a1025' "$WALLPAPER_DEST"
    else
        echo "    WARNING: No image tools available. Wallpaper will be missing."
    fi
fi

# Copy logo
LOGO_DEST="${PROFILE_DIR}/airootfs/usr/local/share/ionix/ionix-logo.svg"
if [[ -f "${ASSETS_DIR}/ionix-logo.svg" ]]; then
    cp "${ASSETS_DIR}/ionix-logo.svg" "$LOGO_DEST"
fi

# Copy logo to calamares branding
CALA_LOGO="${PROFILE_DIR}/airootfs/etc/calamares/branding/ionix/ionix-logo.png"
if command -v rsvg-convert &>/dev/null && [[ -f "${ASSETS_DIR}/ionix-logo.svg" ]]; then
    rsvg-convert -w 128 -h 128 "${ASSETS_DIR}/ionix-logo.svg" -o "$CALA_LOGO"
elif command -v magick &>/dev/null && [[ -f "${ASSETS_DIR}/ionix-logo.svg" ]]; then
    magick "${ASSETS_DIR}/ionix-logo.svg" -resize 128x128 "$CALA_LOGO"
else
    echo "    WARNING: Cannot convert logo SVG to PNG for Calamares branding."
fi

# ── Step 4: Build ISO ─────────────────────────────────────────
echo ""
echo "==> Step 4/4: Building ISO with mkarchiso..."
echo "    Profile: $PROFILE_DIR"
echo "    Work dir: $WORK_DIR"
echo "    Output: $OUT_DIR"
echo ""

mkdir -p "$OUT_DIR"

mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"

# ── Done ──────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Build complete!                                        ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "ISO file:"
ls -lh "$OUT_DIR"/ionix-*.iso 2>/dev/null || echo "  (no ISO found - check build output above)"
echo ""
echo "Test with QEMU:"
echo "  qemu-system-x86_64 -enable-kvm -m 4G -cdrom $OUT_DIR/ionix-*.iso -boot d"
