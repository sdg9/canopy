#!/bin/bash

sketchybar --add item claude_usage right \
           --set claude_usage \
                       update_freq=60 \
                       icon=✴ \
                       icon.padding_right=4 \
                       background.color=$COLOR_ITEM_BG \
                       background.corner_radius=8 \
                       background.padding_left=5 \
                       background.height=28 \
                       label="--" \
                       script="$PLUGIN_DIR/claude_usage.sh" \
                       click_script="open http://localhost:7779"
