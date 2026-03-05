#!/usr/bin/env bash
# Ionix ISO Docker Build
# Builds the ISO inside an Arch Linux container so it works on non-Arch hosts.
# Requires Docker with --privileged support (needed by mkarchiso for loop devices,
# bind mounts, and chroot).
#
# Usage: ./docker-build.sh [--rebuild-image]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="ionix-builder"
REBUILD_IMAGE=false

for arg in "$@"; do
    case "$arg" in
        --rebuild-image) REBUILD_IMAGE=true ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

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

docker run --rm \
    --privileged \
    --platform linux/amd64 \
    -v "$SCRIPT_DIR:$SCRIPT_DIR" \
    -w "$SCRIPT_DIR" \
    "$IMAGE_NAME" \
    bash ./build.sh

echo ""
echo "==> Build complete. ISO is in: $SCRIPT_DIR/out/"
