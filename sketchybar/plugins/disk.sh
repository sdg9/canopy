#!/bin/bash

# Get APFS container usage (accurate for macOS)
USED_PCT=$(diskutil apfs list 2>/dev/null | awk -F'[()%]' '/Capacity In Use By Volumes.*used/{printf "%.0f", $4; exit}')

if [ -z "$USED_PCT" ]; then
  sketchybar --set "$NAME" label="--%"
  exit 0
fi

LABEL="${USED_PCT}%"

sketchybar --set "$NAME" label="$LABEL"
