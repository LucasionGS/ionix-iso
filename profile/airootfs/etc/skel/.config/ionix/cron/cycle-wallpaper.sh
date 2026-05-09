#!/bin/bash
# Ionix - Cycle Wallpaper
# Randomly cycles wallpapers across all connected displays using awww.

IONIX_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ionix"
WALLPAPER_DIR="$IONIX_DIR/.wallpapers_active"
AWWW_ARGS="--transition-type=wave --transition-duration=2 --transition-fps=60 --transition-step=255"

mapfile -d '' ALL_WALLPAPERS < <(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.gif" \) -print0)

if [ ${#ALL_WALLPAPERS[@]} -eq 0 ]; then
  echo "No wallpapers found in $WALLPAPER_DIR"
  exit 1
fi

DISPLAYS=($(awww query | grep -oP '(?<=: ).+(?=: \d+x\d+)'))

if [ ${#DISPLAYS[@]} -eq 0 ]; then
  echo "No displays found"
  exit 1
fi

declare -A CURRENT_WALLPAPERS
for display in "${DISPLAYS[@]}"; do
  current_wall=$(awww query | grep "^$display:" | grep -oP '(?<=image: ).*')
  if [ -n "$current_wall" ]; then
    CURRENT_WALLPAPERS["$display"]="$(realpath "$current_wall")"
  fi
done

mapfile -d '' SHUFFLED_WALLPAPERS < <(printf '%s\0' "${ALL_WALLPAPERS[@]}" | shuf -z)

# My fork of awww supports --ken-burns, but the original does not,
# so we check for support before applying the argument
if awww img --help | grep -q -- '--ken-burns'; then
  AWWW_ARGS="$AWWW_ARGS --ken-burns"
fi

wallpaper_index=0
for display in "${DISPLAYS[@]}"; do
  selected_wallpaper=""
  for ((i = wallpaper_index; i < ${#SHUFFLED_WALLPAPERS[@]}; i++)); do
    candidate=$(realpath "${SHUFFLED_WALLPAPERS[$i]}")
    if [ "$candidate" != "${CURRENT_WALLPAPERS[$display]}" ]; then
      selected_wallpaper="$candidate"
      wallpaper_index=$((i + 1))
      break
    fi
  done

  if [ -z "$selected_wallpaper" ]; then
    if [ $wallpaper_index -lt ${#SHUFFLED_WALLPAPERS[@]} ]; then
      selected_wallpaper=$(realpath "${SHUFFLED_WALLPAPERS[$wallpaper_index]}")
      wallpaper_index=$((wallpaper_index + 1))
    else
      wallpaper_index=0
      selected_wallpaper=$(realpath "${SHUFFLED_WALLPAPERS[$wallpaper_index]}")
      wallpaper_index=$((wallpaper_index + 1))
    fi
  fi

  echo "Setting wallpaper for $display: $(basename "$selected_wallpaper")"
  awww img $AWWW_ARGS --outputs "$display" "$selected_wallpaper"
done
