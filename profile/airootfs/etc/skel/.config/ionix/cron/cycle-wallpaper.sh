#!/bin/bash
# Ionix - Cycle Wallpaper
# Randomly cycles wallpapers across all connected displays using swww.

IONIX_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ionix"
WALLPAPER_DIR="$IONIX_DIR/.wallpapers_active"
SWWW_ARGS="--transition-type=wave --transition-duration=2 --transition-fps=60 --transition-step=255"

ALL_WALLPAPERS=($(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.gif" \)))

if [ ${#ALL_WALLPAPERS[@]} -eq 0 ]; then
  echo "No wallpapers found in $WALLPAPER_DIR"
  exit 1
fi

DISPLAYS=($(swww query | grep -oP '(?<=: ).+(?=: \d+x\d+)'))

if [ ${#DISPLAYS[@]} -eq 0 ]; then
  echo "No displays found"
  exit 1
fi

declare -A CURRENT_WALLPAPERS
for display in "${DISPLAYS[@]}"; do
  current_wall=$(swww query | grep "^$display:" | grep -oP '(?<=image: ).*')
  if [ -n "$current_wall" ]; then
    CURRENT_WALLPAPERS["$display"]="$(realpath "$current_wall")"
  fi
done

SHUFFLED_WALLPAPERS=($(printf '%s\n' "${ALL_WALLPAPERS[@]}" | shuf))

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
  swww img $SWWW_ARGS --outputs "$display" "$selected_wallpaper"
done
