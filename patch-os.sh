#!/bin/bash
# This script is used to patch an existing OS with the latest updates to Ionix.
# It will be used to update files in the OS that has changed since the original ISO installation.

set -euo pipefail

AUTO_ACCEPT=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIROOTFS="$SCRIPT_DIR/profile/airootfs"
TARGET_ROOT=""

# Exact paths (relative to airootfs) to always exclude from patching.
# These are installer/live-specific files that must never be copied to an
# installed system.
SKIP_EXACT=(
    "etc/default/grub"
    "etc/mkinitcpio.d/linux.preset"
    "etc/sudoers.d/10-ionix"
    "home/liveuser/.gitkeep"
    "usr/local/bin/grub-install"
    "usr/local/bin/ionix-install"
    "usr/local/bin/ionix-post-install"
    "usr/share/applications/ionix-install.desktop"
)

# Path prefixes (relative to airootfs) to skip — these are either live-ISO-specific,
# per-machine configuration, or managed by other tools (e.g. systemctl).
SKIP_PATTERNS=(
    "etc/shadow"
    "etc/gshadow"
    "etc/group"
    "etc/passwd"
    "etc/hostname"
    "etc/locale.gen"
    "etc/locale.conf"
    "etc/vconsole.conf"
    # "etc/skel"
    "etc/mkinitcpio.conf.d"
    "etc/pacman.d/hooks"
    "etc/calamares"
    "etc/systemd/system/multi-user.target.wants"
    "etc/systemd/system/NetworkManager-wait-online.service"
    "etc/systemd/system/getty@tty1.service.d"
    "etc/systemd/system/etc-pacman.d-gnupg.mount"
    "etc/systemd/system/pacman-init.service"
    "etc/systemd/system/choose-mirror.service"
)

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Compare Ionix airootfs against an installed system and apply updates.

Options:
  -y            Auto-accept all updates (non-interactive)
  --root PATH   Target root directory (default: /)
  -h, --help    Show this help

In interactive mode (default), each changed file shows a diff and prompts
whether to update or keep the local version. Files kept locally are listed
at the end for manual review.

Files under etc/skel/ (user home templates) and live-ISO-specific paths
are excluded from patching.
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y) AUTO_ACCEPT=true; shift ;;
        --root) TARGET_ROOT="${2%/}"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1" >&2; usage ;;
    esac
done

if [[ -z "$TARGET_ROOT" && "$EUID" -ne 0 ]]; then
    echo "Error: must be run as root when targeting /." >&2
    echo "Run: sudo $0 $*" >&2
    exit 1
fi

kept_files=()

should_skip() {
    local rel="$1"
    for exact in "${SKIP_EXACT[@]}"; do
        [[ "$rel" == "$exact" ]] && return 0
    done
    for pattern in "${SKIP_PATTERNS[@]}"; do
        if [[ "$rel" == "$pattern" || "$rel" == "$pattern/"* ]]; then
            return 0
        fi
    done
    return 1
}

is_binary() {
    grep -qP "\x00" "$1" 2>/dev/null
}

install_file() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
}

echo "Ionix OS Patcher"
echo "================"
echo "Repo:   $AIROOTFS"
echo "Target: ${TARGET_ROOT:-/}"
if "$AUTO_ACCEPT"; then
    echo "Mode:   auto-accept"
else
    echo "Mode:   interactive"
fi
echo ""

QUIT=false

while IFS= read -r -d '' repo_file; do
    "$QUIT" && break

    rel="${repo_file#"$AIROOTFS"/}"
    system_file="${TARGET_ROOT}/${rel}"

    should_skip "$rel" && continue

    if [[ ! -e "$system_file" ]]; then
        # File does not exist on the target system
        if "$AUTO_ACCEPT"; then
            echo "[NEW]    /$rel"
            install_file "$repo_file" "$system_file"
        else
            echo "─────────────────────────────────────────────────────"
            echo "NEW FILE: /$rel"
            read -r -p "Install this file? [y/N/q]: " choice < /dev/tty
            case "$choice" in
                [Yy])
                    install_file "$repo_file" "$system_file"
                    echo "Installed."
                    ;;
                [Qq])
                    QUIT=true
                    ;;
                *)
                    kept_files+=("/$rel  (new — not installed)")
                    echo "Skipped."
                    ;;
            esac
            echo ""
        fi
        continue
    fi

    # Skip identical files
    cmp -s "$repo_file" "$system_file" && continue

    # Files differ
    if "$AUTO_ACCEPT"; then
        echo "[UPDATE] /$rel"
        install_file "$repo_file" "$system_file"
        continue
    fi

    echo "─────────────────────────────────────────────────────"
    echo "CHANGED: /$rel"
    echo ""

    if is_binary "$repo_file" || is_binary "$system_file"; then
        echo "(binary file — diff not shown)"
    else
        diff --color=always -u "$system_file" "$repo_file" || true
    fi

    echo ""
    read -r -p "Update this file? [y/N/q]: " choice < /dev/tty
    case "$choice" in
        [Yy])
            install_file "$repo_file" "$system_file"
            echo "Updated."
            ;;
        [Qq])
            QUIT=true
            kept_files+=("/$rel")
            ;;
        *)
            kept_files+=("/$rel")
            echo "Kept local."
            ;;
    esac
    echo ""

done < <(find "$AIROOTFS" -type f -print0 | sort -z)

# ---------------------------------------------------------------------------
# Package installation
# ---------------------------------------------------------------------------
PACKAGES_FILE="$SCRIPT_DIR/profile/packages.x86_64"

install_packages() {
    # Collect packages: strip blank lines and comments
    mapfile -t pkgs < <(grep -v '^\s*#' "$PACKAGES_FILE" | grep -v '^\s*$')

    if [[ ${#pkgs[@]} -eq 0 ]]; then
        echo "No packages found in packages.x86_64, skipping."
        return
    fi

    echo "Installing/updating ${#pkgs[@]} packages via yay --needed ..."
    echo ""

    # yay must not run as root; use SUDO_USER if available
    if [[ -n "${SUDO_USER:-}" ]]; then
        sudo -u "$SUDO_USER" yay --needed --noconfirm -S "${pkgs[@]}"
    else
        yay --needed --noconfirm -S "${pkgs[@]}"
    fi
}

# Only install packages when operating on the real root (--root skips this)
if [[ -z "$TARGET_ROOT" ]]; then
    if ! command -v yay &>/dev/null; then
        echo "Warning: yay not found — skipping package installation."
    elif "$AUTO_ACCEPT"; then
        echo "─────────────────────────────────────────────────────"
        install_packages
    else
        echo "─────────────────────────────────────────────────────"
        read -r -p "Install/update packages from packages.x86_64? [Y/n]: " choice < /dev/tty
        if [[ "$choice" != [Nn]* ]]; then
            install_packages
        else
            echo "Skipped package installation."
        fi
    fi
fi

echo "═════════════════════════════════════════════════════"
echo "Patch complete."

if [[ ${#kept_files[@]} -gt 0 ]]; then
    echo ""
    echo "Files requiring manual intervention (kept local / not installed):"
    printf "  %s\n" "${kept_files[@]}"
fi

