#!/usr/bin/env bash
# Ionix ISO Docker Build
# Builds the ISO inside an Arch Linux container so it works on non-Arch hosts.
# Requires Docker with --privileged support (needed by mkarchiso for loop devices,
# bind mounts, and chroot).
#
# Usage: ./docker-build.sh [--rebuild-image] [--variant desktop|server] [--answers FILE]
#
# --variant and --answers are passed on to build.sh; see its header. An answer
# file must live inside this checkout, the only host path the container sees.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="ionix-builder"
REBUILD_IMAGE=false
BUILD_ARGS=()
VARIANT="desktop"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rebuild-image) REBUILD_IMAGE=true; shift ;;
        -v|--variant) VARIANT="${2:-}"; BUILD_ARGS+=(--variant "$VARIANT"); shift 2 ;;
        -a|--answers)
            if [[ ! -f "${2:-}" ]]; then
                echo "Answer file not found: ${2:-}"
                exit 2
            fi
            if [[ "$(realpath "$2")" != "$SCRIPT_DIR"/* ]]; then
                echo "The answer file must be inside $SCRIPT_DIR: the container sees nothing else."
                exit 2
            fi
            BUILD_ARGS+=(--answers "$(realpath "$2")")
            shift 2
            ;;
        *) echo "Unknown argument: $1"; exit 2 ;;
    esac
done

# Fetch git submodules before entering the container.
# This has to happen on the host: build.sh runs as root inside the container,
# where git refuses to operate on a tree owned by another user (safe.directory).
if [[ "$VARIANT" == desktop && ! -f "$SCRIPT_DIR/submodules/ionix-quickshell/PKGBUILD" ]]; then
    echo "==> Fetching git submodules..."
    git -C "$SCRIPT_DIR" submodule update --init --recursive
fi

# Build the Docker image if it doesn't exist yet or a rebuild was requested
if [[ "$REBUILD_IMAGE" == true ]] || ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
    echo "==> Building Docker image: $IMAGE_NAME"
    docker build --platform linux/amd64 -t "$IMAGE_NAME" "$SCRIPT_DIR"
else
    echo "==> Docker image '$IMAGE_NAME' already exists (use --rebuild-image to rebuild)"
fi

echo "==> Running ISO build inside Docker..."
echo "    Project: $SCRIPT_DIR"
echo "    Output:  $SCRIPT_DIR/out/"
echo ""

# Refresh the container's pacman databases before every build, not just when the
# image is (re)built. The image ships whatever sync databases existed when it was
# created, and Arch drops superseded package versions from its mirrors within
# days — so against a cached image, every `makepkg -s` dependency install fails
# with a 404 on a version the mirror no longer carries.
#
# Refresh the keyring first (an old keyring cannot verify newly signed packages),
# and always pair -Sy with -Su: a bare -Sy leaves the container in a
# partial-upgrade state, which breaks builds in far less obvious ways.
# Keep pacman's package cache in a named volume. The container is thrown away
# after every run, and without this each build re-downloads every package the
# ISO contains (several GB) plus the build dependencies of the AUR packages.
# Reclaim the space with: docker volume rm ionix-pacman-cache
CACHE_VOLUME="ionix-pacman-cache"

docker run --rm \
    --privileged \
    --platform linux/amd64 \
    -v "$SCRIPT_DIR:$SCRIPT_DIR" \
    -v "$CACHE_VOLUME:/var/cache/pacman/pkg" \
    -w "$SCRIPT_DIR" \
    "$IMAGE_NAME" \
    bash -c 'set -e
        echo "==> Refreshing container package databases..."
        pacman -Sy --noconfirm --needed archlinux-keyring
        pacman -Su --noconfirm
        exec bash ./build.sh "$@"' _ "${BUILD_ARGS[@]}"

echo ""
echo "==> Build complete. ISO is in: $SCRIPT_DIR/out/"
