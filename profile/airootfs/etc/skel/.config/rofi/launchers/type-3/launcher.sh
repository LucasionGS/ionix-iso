#!/usr/bin/env bash

## Ionix - Rofi Launcher (type-3, style-10)

dir="$HOME/.config/rofi/launchers/type-3"
theme='style-10'

rofi \
    -show drun \
    -theme ${dir}/${theme}.rasi
