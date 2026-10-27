#!/bin/bash
# Publishes the Ionix system packages (pkgbase ionix-system-git, building
# ionix-base-git, ionix-desktop-git and ionix-server-git) to the AUR.
# Usage: ./aur-publish.sh [commit message]
#
# Run it after pushing: the AUR build fetches system/ from GitHub, so the
# version published here must be one GitHub can produce, or yay would keep
# offering an upgrade that never arrives.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
AUR_PKGBASE="ionix-system-git"
AUR_REPO="ssh://aur@aur.archlinux.org/${AUR_PKGBASE}.git"
AUR_DIR="${SCRIPT_DIR}/.aur-repo"

COMMIT_MSG="${1:-Update PKGBUILD}"

if [ ! -f "${SCRIPT_DIR}/PKGBUILD" ]; then
    echo "Error: PKGBUILD not found in ${SCRIPT_DIR}"
    exit 1
fi

if ! command -v makepkg &>/dev/null; then
    echo "Error: makepkg is required but not found."
    exit 1
fi

if [ -n "$(git -C "${SYSTEM_DIR}" status --porcelain -- .)" ]; then
    echo "Error: system/ has uncommitted changes. Commit and push them first."
    exit 1
fi

git -C "${SYSTEM_DIR}" fetch --quiet origin
if [ -z "$(git -C "${SYSTEM_DIR}" branch -r --contains HEAD)" ]; then
    echo "Error: HEAD is not on GitHub yet. Push it first; the AUR builds from there."
    exit 1
fi

if [ -d "${AUR_DIR}/.git" ]; then
    echo "Pulling latest from AUR..."
    git -C "${AUR_DIR}" pull --rebase || true
else
    echo "Cloning AUR repo..."
    git clone "${AUR_REPO}" "${AUR_DIR}" 2>/dev/null || {
        # If the repo doesn't exist yet on AUR, initialize it
        echo "AUR repo not found remotely. Initializing new repo..."
        mkdir -p "${AUR_DIR}"
        git -C "${AUR_DIR}" init
        git -C "${AUR_DIR}" remote add origin "${AUR_REPO}"
    }
fi

cp "${SCRIPT_DIR}/PKGBUILD" "${AUR_DIR}/PKGBUILD"

# Resolve the real version and patch the AUR copy; makepkg --printsrcinfo cannot
# run pkgver() here because $srcdir does not exist. Commits that touched system/
# only — the same formula as the PKGBUILD's pkgver() and aur/build-aur.sh.
GENERATED_VERSION=$(printf "r%s.%s" \
    "$(git -C "${SYSTEM_DIR}" rev-list --count HEAD -- .)" \
    "$(git -C "${SYSTEM_DIR}" log -1 --format=%h -- .)")
echo "Package version: ${GENERATED_VERSION}"
sed -i "s/^pkgver=.*/pkgver=${GENERATED_VERSION}/" "${AUR_DIR}/PKGBUILD"

echo "Generating .SRCINFO..."
(cd "${AUR_DIR}" && makepkg --printsrcinfo > .SRCINFO)

cd "${AUR_DIR}"
git add PKGBUILD .SRCINFO
if git diff --cached --quiet; then
    echo "No changes to publish."
    exit 0
fi
git commit -m "${COMMIT_MSG}"
git push origin master

echo "Published ${AUR_PKGBASE} to AUR."

rm -rf "${AUR_DIR}"
echo "Cleaned up temporary AUR repo."
