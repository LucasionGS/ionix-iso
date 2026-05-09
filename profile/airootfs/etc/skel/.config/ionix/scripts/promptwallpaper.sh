#!/bin/bash
# Ionix - Wallpaper Picker
# Set wallpaper(s) using awww. Opens a file dialog if no arguments given.
#
# Usage: promptwallpaper.sh [file1] [file2] ...

IONIX_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ionix"
AWWW_ARGS="--transition-type=wave --transition-duration=2 --transition-fps=60 --transition-step=255"

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 [file1] [file2] ..."
  echo "Set wallpaper(s) using awww. If no files given, opens a file selection dialog."
  exit 0
fi

clean_cache() {
  rm -f "$IONIX_DIR/.wallpapers_active/"*
}

mkdir -p "$HOME/Pictures/Wallpapers"
mkdir -p "$IONIX_DIR/.wallpapers_active"

if [ $# -gt 0 ]; then
  FILE_ARRAY=("$@")
  for file in "${FILE_ARRAY[@]}"; do
    if [ ! -f "$file" ]; then
      echo "Error: File '$file' does not exist" >&2
      exit 1
    fi
  done
  FILE_PATHS=$(IFS='|'; echo "${FILE_ARRAY[*]}")
else
  FILE_PATHS=$(zenity --file-selection --multiple \
    --title="Select Wallpaper(s)" \
    --file-filter="*.jpg *.jpeg *.png *.gif" \
    --separator="|" \
    --filename="$HOME/Pictures/Wallpapers/" \
    --width=800 --height=600)
  if [ -z "$FILE_PATHS" ]; then
    exit 1
  fi
  IFS='|' read -r -a FILE_ARRAY <<< "$FILE_PATHS"
fi

FILE_PATH="${FILE_ARRAY[0]}"

if [ ${#FILE_ARRAY[@]} -gt 0 ]; then
  clean_cache
  for file in "${FILE_ARRAY[@]}"; do
    cp "$file" "$IONIX_DIR/.wallpapers_active/"
  done
fi
# My fork of awww supports --ken-burns, but the original does not,
# so we check for support before applying the argument
if awww img --help | grep -q -- '--ken-burns'; then
  AWWW_ARGS="$AWWW_ARGS --ken-burns"
fi

if [ -n "$FILE_PATH" ]; then
  awww img $AWWW_ARGS "$FILE_PATH"
fi
