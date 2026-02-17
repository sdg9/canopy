#!/bin/bash

# Parse memory pressure for free percentage
FREE_PCT=$(memory_pressure 2>/dev/null | awk '/free percentage/{gsub(/%/,""); print $NF}')

if [ -z "$FREE_PCT" ]; then
  sketchybar --set "$NAME" label="--%"
  exit 0
fi

# Used % = 100 - free %
USED=$((100 - FREE_PCT))
NORM=$(echo "$USED" | awk '{printf "%.2f", $1/100}')
LABEL="${USED}%"

sketchybar --set "$NAME" label="$LABEL" \
           --push "$NAME" "$NORM"
