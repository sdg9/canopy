#!/bin/bash

# CPU graph
sketchybar --add graph cpu right 70 \
           --set cpu \
                     update_freq=3 \
                     icon=󰍛 \
                     icon.padding_right=4 \
                     icon.color=$COLOR_CPU_LINE \
                     label="--%" \
                     label.font="SF Pro:Semibold:11.0" \
                     graph.color=$COLOR_CPU_LINE \
                     graph.fill_color=$COLOR_CPU_FILL \
                     graph.line_width=1.5 \
                     background.color=$COLOR_ITEM_BG \
                     background.corner_radius=8 \
                     background.padding_left=5 \
                     background.height=28 \
                     script="$PLUGIN_DIR/cpu.sh" \
                     click_script="open -a 'Activity Monitor' && osascript -e 'tell application \"System Events\" to tell process \"Activity Monitor\" to click menu item \"CPU\" of menu \"Window\" of menu bar 1'"

# RAM graph
sketchybar --add graph ram right 70 \
           --set ram \
                     update_freq=10 \
                     icon=󰘚 \
                     icon.padding_right=4 \
                     icon.color=$COLOR_RAM_LINE \
                     label="--%" \
                     label.font="SF Pro:Semibold:11.0" \
                     graph.color=$COLOR_RAM_LINE \
                     graph.fill_color=$COLOR_RAM_FILL \
                     graph.line_width=1.5 \
                     background.color=$COLOR_ITEM_BG \
                     background.corner_radius=8 \
                     background.padding_left=5 \
                     background.height=28 \
                     script="$PLUGIN_DIR/ram.sh" \
                     click_script="open -a 'Activity Monitor' && osascript -e 'tell application \"System Events\" to tell process \"Activity Monitor\" to click menu item \"Memory\" of menu \"Window\" of menu bar 1'"

# Disk usage
sketchybar --add item disk right \
           --set disk \
                     update_freq=120 \
                     icon=󰋊 \
                     icon.padding_right=4 \
                     icon.color=$COLOR_DISK_LINE \
                     label="--%" \
                     label.font="SF Pro:Semibold:11.0" \
                     background.color=$COLOR_ITEM_BG \
                     background.corner_radius=8 \
                     background.padding_left=5 \
                     background.height=28 \
                     script="$PLUGIN_DIR/disk.sh" \
                     click_script="open 'x-apple.systempreferences:com.apple.settings.Storage'"
