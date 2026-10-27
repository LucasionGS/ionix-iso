#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  Ionix ISO Build Script                                     ║
# ║  Builds the Ionix live/installer ISO using archiso.         ║
# ║  Must be run as root: sudo ./build.sh                       ║
# ╚══════════════════════════════════════════════════════════════╝
#
# Usage: sudo ./build.sh [--variant desktop|server] [--answers FILE]
#
#   -v, --variant NAME   Which ISO to build: desktop (default) or server.
#   -a, --answers FILE   Server only: bake an ionix-server-install answer file
#                        into the ISO (/etc/ionix/install.conf on the live
#                        system), so it installs with nobody at the keyboard.
#                        It holds a password hash, so keep the ISO private.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILES_DIR="${SCRIPT_DIR}/profiles"
WORK_DIR="${SCRIPT_DIR}/work"
OUT_DIR="${SCRIPT_DIR}/out"
LOCAL_REPO="${SCRIPT_DIR}/localrepo"
AUR_DIR="${SCRIPT_DIR}/aur"
ASSETS_DIR="${SCRIPT_DIR}/assets"

VARIANT="desktop"
ANSWERS=""

usage() {
    sed -n '/^# Usage:/,/^#  *It holds/s/^# \{0,1\}//p' "$0"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--variant) VARIANT="${2:-}"; shift 2 ;;
        -a|--answers) ANSWERS="${2:-}"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "ERROR: Unknown argument: $1"; usage; exit 2 ;;
    esac
done

if [[ "$VARIANT" == common || ! -d "${PROFILES_DIR}/${VARIANT}" ]]; then
    echo "ERROR: Unknown variant: '${VARIANT}'. Use desktop or server."
    exit 2
fi
if [[ -n "$ANSWERS" ]]; then
    if [[ "$VARIANT" != server ]]; then
        echo "ERROR: --answers only applies to the server variant."
        exit 2
    fi
    if [[ ! -f "$ANSWERS" ]]; then
        echo "ERROR: Answer file not found: $ANSWERS"
        exit 2
    fi
fi

# The profile mkarchiso actually builds: common/ with the variant laid over it.
# Generated assets (wallpaper, logos, GRUB fonts) are written in here too, so a
# build never modifies the source tree.
PROFILE_DIR="${SCRIPT_DIR}/staging/${VARIANT}"

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
echo "    Variant: $VARIANT"
echo ""

# ── Preflight: submodules ────────────────────────────────────
# Fail fast rather than fetching: this script runs as root, and git refuses to
# operate on a checkout owned by another user. Fetch on the host instead.
if [[ "$VARIANT" == desktop && ! -f "${SCRIPT_DIR}/submodules/ionix-quickshell/PKGBUILD" ]]; then
    echo "ERROR: submodules/ionix-quickshell is empty."
    echo "       Run this as your normal user first:"
    echo "         git submodule update --init --recursive"
    exit 1
fi

# ── Step 1: Stage the profile ────────────────────────────────
# Files overlay: a path in the variant replaces the same path in common/.
# packages.x86_64 and profiledef.sh are concatenated instead, common first, so
# a variant only lists what it adds.
echo "==> Step 1/5: Staging the ${VARIANT} profile..."
rm -rf "$PROFILE_DIR"
mkdir -p "$PROFILE_DIR"
cp -a "${PROFILES_DIR}/common/." "$PROFILE_DIR/"
cp -a "${PROFILES_DIR}/${VARIANT}/." "$PROFILE_DIR/"
for f in packages.x86_64 profiledef.sh; do
    cat "${PROFILES_DIR}/common/$f" "${PROFILES_DIR}/${VARIANT}/$f" > "${PROFILE_DIR}/$f"
done

if [[ -n "$ANSWERS" ]]; then
    install -Dm600 "$ANSWERS" "${PROFILE_DIR}/airootfs/etc/ionix/install.conf"
    echo 'file_permissions+=(["/etc/ionix/install.conf"]="0:0:600")' >> "${PROFILE_DIR}/profiledef.sh"
    echo "    Baked in answer file: $ANSWERS"
fi
echo "    Staged at: $PROFILE_DIR"

# ── Step 2: Build AUR and local packages ─────────────────────
echo ""
echo "==> Step 2/5: Building AUR and local packages..."
chmod +x "${AUR_DIR}/build-aur.sh"
"${AUR_DIR}/build-aur.sh" "$LOCAL_REPO" "${PROFILE_DIR}/packages.x86_64"

# ── Step 3: Patch pacman.conf with local repo path ───────────
echo ""
echo "==> Step 3/5: Configuring local repository..."

# Copy the local repo to a location accessible during build
REPO_MOUNT="/tmp/ionix-localrepo"
rm -rf "$REPO_MOUNT"
cp -r "$LOCAL_REPO" "$REPO_MOUNT"

echo "    Local repo at: $REPO_MOUNT"

# ── Step 4: Copy branding assets into airootfs ────────────────
echo ""
echo "==> Step 4/5: Copying branding assets..."

# Copy logo
LOGO_DEST="${PROFILE_DIR}/airootfs/usr/local/share/ionix/ionix-logo.svg"
if [[ -f "${ASSETS_DIR}/ionix-logo.svg" ]]; then
    cp "${ASSETS_DIR}/ionix-logo.svg" "$LOGO_DEST"
fi

# A 128px logo PNG: the Calamares branding logo on the desktop, and the source
# of the GRUB theme logo below on both variants.
LOGO_PNG="$(mktemp --suffix=.png)"
trap 'rm -f "$LOGO_PNG"' EXIT
if command -v rsvg-convert &>/dev/null && [[ -f "${ASSETS_DIR}/ionix-logo.svg" ]]; then
    rsvg-convert -w 128 -h 128 "${ASSETS_DIR}/ionix-logo.svg" -o "$LOGO_PNG"
elif command -v magick &>/dev/null && [[ -f "${ASSETS_DIR}/ionix-logo.svg" ]]; then
    magick "${ASSETS_DIR}/ionix-logo.svg" -resize 128x128 "$LOGO_PNG"
else
    echo "    WARNING: Cannot convert logo SVG to PNG."
    rm -f "$LOGO_PNG"
fi

CALA_BRANDING="${PROFILE_DIR}/airootfs/etc/calamares/branding/ionix"
if [[ -d "$CALA_BRANDING" ]]; then
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

    # Copy logo to calamares branding
    if [[ -f "$LOGO_PNG" ]]; then
        cp "$LOGO_PNG" "${CALA_BRANDING}/ionix-logo.png"
    fi

    # Calamares welcome-page hero (branding.desc `productWelcome`, also the first
    # install slide). Rendered at its native 1200x520; Calamares scales it down.
    CALA_WELCOME="${CALA_BRANDING}/welcome.png"
    if command -v rsvg-convert &>/dev/null && [[ -f "${ASSETS_DIR}/calamares-welcome.svg" ]]; then
        rsvg-convert -w 1200 -h 520 "${ASSETS_DIR}/calamares-welcome.svg" -o "$CALA_WELCOME"
    elif command -v magick &>/dev/null && [[ -f "${ASSETS_DIR}/calamares-welcome.svg" ]]; then
        magick -background none "${ASSETS_DIR}/calamares-welcome.svg" -resize 1200x520 "$CALA_WELCOME"
    else
        echo "    WARNING: Cannot render the Calamares welcome image; the branding will fail to load."
    fi
fi

# Generate GRUB theme assets (fonts + logo)
# Not under airootfs/boot: mkarchiso empties that from the image, so the theme
# would never reach an installed system. ionix-post-install copies it there.
GRUB_THEME_DIR="${PROFILE_DIR}/airootfs/usr/local/share/ionix/grub-theme"
echo "    Generating GRUB theme assets..."
if command -v grub-mkfont &>/dev/null; then
    FONT_DIR="${GRUB_THEME_DIR}/fonts"
    mkdir -p "$FONT_DIR"
    grub-mkfont /usr/share/fonts/noto/NotoSans-Regular.ttf -o "${FONT_DIR}/regular-16.pf2" -s 16 -n "NotoSans Regular 16" 2>/dev/null
    grub-mkfont /usr/share/fonts/noto/NotoSans-Regular.ttf -o "${FONT_DIR}/regular-14.pf2" -s 14 -n "NotoSans Regular 14" 2>/dev/null
    grub-mkfont /usr/share/fonts/noto/NotoSans-Bold.ttf    -o "${FONT_DIR}/bold-16.pf2"    -s 16 -n "NotoSans Bold 16"    2>/dev/null
    grub-mkfont /usr/share/fonts/noto/NotoSans-Bold.ttf    -o "${FONT_DIR}/bold-24.pf2"    -s 24 -n "NotoSans Bold 24"    2>/dev/null
    echo "    GRUB fonts generated."
else
    echo "    WARNING: grub-mkfont not found — GRUB theme fonts not regenerated."
fi
# Regenerate GRUB theme logo from the freshly-converted logo PNG
if [[ -f "$LOGO_PNG" ]] && command -v python3 &>/dev/null; then
    python3 - "$LOGO_PNG" "${GRUB_THEME_DIR}/ionix-logo.png" <<'PYEOF'
import sys
from PIL import Image
src, dst = sys.argv[1], sys.argv[2]
Image.open(src).convert("RGBA").resize((160, 160), Image.LANCZOS).save(dst)
PYEOF
    echo "    GRUB theme logo updated."
elif command -v magick &>/dev/null && [[ -f "$LOGO_PNG" ]]; then
    magick "$LOGO_PNG" -resize 160x160 "${GRUB_THEME_DIR}/ionix-logo.png"
    echo "    GRUB theme logo updated (ImageMagick)."
fi

# ── Step 5: Build ISO ─────────────────────────────────────────
echo ""
echo "==> Step 5/5: Building ISO with mkarchiso..."
echo "    Profile: $PROFILE_DIR"
echo "    Work dir: $WORK_DIR"
echo "    Output: $OUT_DIR"
echo ""

mkdir -p "$OUT_DIR"

# mkarchiso records every finished stage as a marker file in the work dir and
# skips that stage on the next run, so a leftover work/ silently produces an ISO
# without the current airootfs or package list. Always start from scratch; the
# packages themselves come from pacman's cache (a persistent volume under
# docker-build.sh), so this costs extraction time, not downloads.
rm -rf "$WORK_DIR"

mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"

# ── Done ──────────────────────────────────────────────────────
# mkarchiso declares file_permissions associative before sourcing; so must we.
# shellcheck source=/dev/null
ISO_NAME="$(declare -A file_permissions; source "${PROFILE_DIR}/profiledef.sh" && echo "$iso_name")"
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Build complete!                                         ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "ISO file:"
ls -lh "$OUT_DIR"/"${ISO_NAME}"-[0-9]*.iso 2>/dev/null || echo "  (no ISO found - check build output above)"
echo ""
echo "Test with QEMU:"
echo "  qemu-system-x86_64 -enable-kvm -m 4G -cdrom $OUT_DIR/${ISO_NAME}-*.iso -boot d"
