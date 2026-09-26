#!/usr/bin/env bash
# Clean Ionix build artifacts

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Cleaning Ionix build artifacts..."

sudo rm -rf "${SCRIPT_DIR}/work"
sudo rm -rf "${SCRIPT_DIR}/out"
sudo rm -rf "${SCRIPT_DIR}/localrepo"
sudo rm -rf /tmp/ionix-localrepo
sudo rm -rf /tmp/ionix-aur-build.*
sudo rm -rf /tmp/ionix-python-wrapper.*
# makepkg leftovers, in case anyone ran it inside a submodule checkout
sudo rm -rf "${SCRIPT_DIR}"/submodules/*/pkg "${SCRIPT_DIR}"/submodules/*/src
sudo rm -f "${SCRIPT_DIR}"/submodules/*/*.pkg.tar.*

# Clean generated assets from airootfs (they get regenerated on build)
rm -f "${SCRIPT_DIR}/profile/airootfs/usr/local/share/ionix/wallpaper.png"
rm -f "${SCRIPT_DIR}/profile/airootfs/usr/local/share/ionix/ionix-logo.svg"
rm -f "${SCRIPT_DIR}/profile/airootfs/etc/calamares/branding/ionix/ionix-logo.png"
rm -f "${SCRIPT_DIR}/profile/airootfs/etc/calamares/branding/ionix/welcome.png"

# Clean up Docker volumes used for caching
docker volume rm ionix-pacman-cache

echo "Done. Run ./build.sh to rebuild."
