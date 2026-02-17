#!/bin/bash

# Aerospace workspace indicator for multi-monitor sketchybar
# Item name format: aerospace.<workspace>.<sketchybar_display>
# Example: aerospace.C.1 = workspace C on sketchybar display 1

# Parse item name to get workspace and sketchybar display
WORKSPACE=$(echo $NAME | cut -d'.' -f2)
SKETCHYBAR_DISPLAY=$(echo $NAME | cut -d'.' -f3)

# Map sketchybar display IDs to aerospace monitor IDs
# Only remap when multiple monitors are connected
# Sketchybar: 1=laptop, 2=top-left, 3=top-right
# Aerospace:  2=laptop, 1=DELL(2), 3=DELL(1)
DISPLAY_COUNT=$(/opt/homebrew/bin/aerospace list-monitors 2>/dev/null | wc -l | tr -d ' ')
if [ "$DISPLAY_COUNT" -gt 1 ]; then
  case "$SKETCHYBAR_DISPLAY" in
    1) AEROSPACE_MONITOR=2 ;;  # Laptop
    2) AEROSPACE_MONITOR=1 ;;  # Top-left DELL
    3) AEROSPACE_MONITOR=3 ;;  # Top-right DELL
    *) AEROSPACE_MONITOR=$SKETCHYBAR_DISPLAY ;;
  esac
else
  AEROSPACE_MONITOR=$SKETCHYBAR_DISPLAY
fi

# Define colors for each workspace
case "$WORKSPACE" in
  C) COLOR="0xff98c379" ;;  # Green - Code
  D) COLOR="0xff98c379" ;;  # Green - Debug
  T) COLOR="0xff98c379" ;;  # Green - Terminal
  W) COLOR="0xff81a1c1" ;;  # Blue - Web
  B) COLOR="0xffebcb8b" ;;  # Yellow - Board (Kanban)
  N) COLOR="0xffebcb8b" ;;  # Orange - Notes
  S) COLOR="0xff88c0d0" ;;  # Cyan - Slack
  M) COLOR="0xffebcb8b" ;;  # Yellow - Meetings
  Y) COLOR="0xffff6b6b" ;;  # Red - YouTube Music
  *) COLOR="0xffffffff" ;;  # White - default
esac

# Check if this workspace is visible on the mapped aerospace monitor
VISIBLE=$(/opt/homebrew/bin/aerospace list-workspaces --monitor $AEROSPACE_MONITOR --format "%{workspace}|%{workspace-is-visible}" 2>/dev/null | grep "^${WORKSPACE}|" | cut -d'|' -f2)

if [ "$VISIBLE" = "true" ]; then
  sketchybar --set $NAME background.color=0xaa7aa2f7 label.color=$COLOR
else
  sketchybar --set $NAME background.color=0x40ffffff label.color=$COLOR
fi
