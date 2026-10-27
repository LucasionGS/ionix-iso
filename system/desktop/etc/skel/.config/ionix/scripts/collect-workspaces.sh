#!/usr/bin/env bash

# Compact workspaces across all monitors: repeatedly find the first gap in
# workspace numbering and shift the workspace after it down by one, until
# there are no more gaps.

while true; do
  mapfile -t OCCUPIED < <(hyprctl workspaces -j | jq -r \
    '[.[] | select(.windows > 0 and .id > 0)] | sort_by(.id) | .[].id')

  [[ ${#OCCUPIED[@]} -le 1 ]] && break

  FOUND=0
  for ((i = 1; i < ${#OCCUPIED[@]}; i++)); do
    PREV=${OCCUPIED[$((i-1))]}
    CURR=${OCCUPIED[$i]}
    if [[ $CURR -ne $((PREV + 1)) ]]; then
      TARGET=$((PREV + 1))
      mapfile -t CLIENTS < <(hyprctl clients -j | jq -r --argjson ws "$CURR" \
        '.[] | select(.workspace.id == $ws) | .address')
      for ADDR in "${CLIENTS[@]}"; do
        hyprctl dispatch movetoworkspacesilent "${TARGET},address:${ADDR}" > /dev/null
      done
      FOUND=1
      break
    fi
  done

  [[ $FOUND -eq 0 ]] && break
done
