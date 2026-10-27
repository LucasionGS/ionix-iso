#!/usr/bin/env bash
# Clean Ionix build artifacts

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Cleaning Ionix build artifacts..."

sudo rm -rf "${SCRIPT_DIR}/work"
sudo rm -rf "${SCRIPT_DIR}/staging"
sudo rm -rf "${SCRIPT_DIR}/out"
sudo rm -rf "${SCRIPT_DIR}/localrepo"
sudo rm -rf /tmp/ionix-localrepo
sudo rm -rf /tmp/ionix-aur-build.*
sudo rm -rf /tmp/ionix-python-wrapper.*
# makepkg leftovers, in case anyone ran it inside a submodule checkout
sudo rm -rf "${SCRIPT_DIR}"/submodules/*/pkg "${SCRIPT_DIR}"/submodules/*/src
sudo rm -f "${SCRIPT_DIR}"/submodules/*/*.pkg.tar.*

# Clean up Docker volumes used for caching
docker volume rm ionix-pacman-cache

echo "Done. Run ./build.sh to rebuild."
