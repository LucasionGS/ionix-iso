#!/bin/bash
# Copy one layer (base, desktop or server) into a package root with the modes a
# package should carry: directories 755, files 755 when executable in git and
# 644 otherwise, symlinks as they are. A plain `cp -a` would carry the checkout's
# umask and owner into the package instead.
#
# Usage: install-tree.sh <layer-dir> <destdir>

set -euo pipefail

SRC="${1:?Usage: install-tree.sh <layer-dir> <destdir>}"
DEST="${2:?Usage: install-tree.sh <layer-dir> <destdir>}"

cd "$SRC"
# find lists a directory before its contents, so every parent exists in time.
find . -mindepth 1 -print0 | LC_ALL=C sort -z | while IFS= read -r -d '' path; do
  path="${path#./}"
  if [[ -L "$path" ]]; then
    ln -sfn "$(readlink "$path")" "$DEST/$path"
  elif [[ -d "$path" ]]; then
    install -dm755 "$DEST/$path"
  elif [[ -x "$path" ]]; then
    install -Dm755 "$path" "$DEST/$path"
  else
    install -Dm644 "$path" "$DEST/$path"
  fi
done
