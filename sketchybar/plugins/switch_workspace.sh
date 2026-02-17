#!/bin/bash

# Switch workspace to the monitor where mouse cursor is located
# Preserves the laptop display's workspace when switching on external monitors
# Usage: switch_workspace.sh <workspace>

WORKSPACE=$1
AERO=/opt/homebrew/bin/aerospace

# Get the monitor where mouse is (target for the workspace)
MOUSE_MONITOR=$($AERO list-monitors --mouse 2>/dev/null | head -1 | awk '{print $1}')

DISPLAY_COUNT=$($AERO list-monitors 2>/dev/null | wc -l | tr -d ' ')

if [ "$DISPLAY_COUNT" -le 1 ]; then
    # Single monitor - just switch
    $AERO workspace "$WORKSPACE"
    sketchybar --trigger aerospace_workspace_change AEROSPACE_FOCUSED_WORKSPACE="$WORKSPACE"
    exit 0
fi

# Laptop is aerospace monitor 2 (mapped in aerospace_multi.sh)
LAPTOP_MONITOR=2

if [ "$MOUSE_MONITOR" = "$LAPTOP_MONITOR" ]; then
    # Clicking on the laptop bar - normal switch, no restoration needed
    $AERO workspace "$WORKSPACE"
    $AERO move-workspace-to-monitor "$MOUSE_MONITOR"
    sketchybar --trigger aerospace_workspace_change AEROSPACE_FOCUSED_WORKSPACE="$WORKSPACE"
    exit 0
fi

# Record laptop's current workspace before the switch
LAPTOP_WS=$($AERO list-workspaces --monitor "$LAPTOP_MONITOR" --format "%{workspace}|%{workspace-is-visible}" 2>/dev/null | grep "|true" | head -1 | cut -d'|' -f1)

# Perform the switch
$AERO workspace "$WORKSPACE"
$AERO move-workspace-to-monitor "$MOUSE_MONITOR"

# Check if the laptop was disrupted
NEW_LAPTOP_WS=$($AERO list-workspaces --monitor "$LAPTOP_MONITOR" --format "%{workspace}|%{workspace-is-visible}" 2>/dev/null | grep "|true" | head -1 | cut -d'|' -f1)

if [ -n "$LAPTOP_WS" ] && [ "$LAPTOP_WS" != "$NEW_LAPTOP_WS" ] && [ "$LAPTOP_WS" != "$WORKSPACE" ]; then
    # Laptop changed, and the workspace we moved wasn't the one on the laptop.
    # Restore: focus the laptop (via its current unwanted workspace), then bring the original back.
    $AERO workspace "$NEW_LAPTOP_WS"
    $AERO workspace "$LAPTOP_WS"
    $AERO move-workspace-to-monitor "$LAPTOP_MONITOR"
    # Refocus the workspace the user clicked
    $AERO workspace "$WORKSPACE"
fi

sketchybar --trigger aerospace_workspace_change AEROSPACE_FOCUSED_WORKSPACE="$WORKSPACE"
