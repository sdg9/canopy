#!/bin/bash

# Parse CPU usage from top
CPU=$(top -l 1 -n 0 2>/dev/null | awk '/CPU usage/{gsub(/%/,""); print $3+$5}')

if [ -z "$CPU" ]; then
  sketchybar --set "$NAME" label="--%"
  exit 0
fi

# Normalize to 0.0–1.0 for graph
NORM=$(echo "$CPU" | awk '{printf "%.2f", $1/100}')
LABEL=$(printf "%.0f%%" "$CPU")

sketchybar --set "$NAME" label="$LABEL" \
           --push "$NAME" "$NORM"
