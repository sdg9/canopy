#!/bin/bash

# Aerospace workspace indicators (multi-display)
# Each display shows its own active workspace highlighting

sketchybar --add event aerospace_workspace_change

# Handle display changes (dock/undock)
sketchybar --add item display_watcher left \
           --set display_watcher drawing=off \
                                 script="$PLUGIN_DIR/display_change.sh" \
           --subscribe display_watcher display_change

# Workspace definitions: name|icon|color
WORKSPACES=(
  "C|󰅩|0xff98c379"
  "D|󰃤|0xff98c379"
  "T|󰆍|0xff98c379"
  "W|󰖟|0xff81a1c1"
  "S|󰍡|0xff88c0d0"
  "B|󰐃|0xffebcb8b"
  "N|󰎞|0xffebcb8b"
  "M|󰻧|0xffebcb8b"
  "Y|󰎆|0xffff6b6b"
  "P|󰌆|0xff61afef"
  "Q|󰍹|0xffc678dd"
)

# Get number of displays
DISPLAY_COUNT=$(aerospace list-monitors 2>/dev/null | wc -l | tr -d ' ')
[ -z "$DISPLAY_COUNT" ] && DISPLAY_COUNT=1

# Create workspace items for each display
for display in $(seq 1 $DISPLAY_COUNT); do
  for ws_def in "${WORKSPACES[@]}"; do
    WS=$(echo "$ws_def" | cut -d'|' -f1)
    ICON=$(echo "$ws_def" | cut -d'|' -f2)
    COLOR=$(echo "$ws_def" | cut -d'|' -f3)

    sketchybar --add item aerospace.${WS}.${display} left \
      --subscribe aerospace.${WS}.${display} aerospace_workspace_change \
      --set aerospace.${WS}.${display} \
        display=$display \
        background.color=$COLOR_WORKSPACE_BG \
        background.corner_radius=8 \
        background.height=28 \
        background.padding_left=2 \
        label.padding_left=8 \
        label.padding_right=8 \
        label="${WS} ${ICON}" \
        label.color=$COLOR \
        click_script="$PLUGIN_DIR/switch_workspace.sh $WS" \
        script="$PLUGIN_DIR/aerospace_multi.sh"
  done
done

# Set initial active workspace per display
(sleep 2 && sketchybar --trigger aerospace_workspace_change) &

sketchybar --add item chevron left \
           --set chevron icon= label.drawing=off
