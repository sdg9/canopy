#!/bin/bash

sketchybar --add item slack right \
           --set slack \
                       update_freq=30 \
                       icon=󰒱 \
                       icon.padding_right=4 \
                       background.color=$COLOR_ITEM_BG \
                       background.corner_radius=8 \
                       background.padding_left=5 \
                       background.height=28 \
                       script="$PLUGIN_DIR/slack.sh" \
                       click_script="open -a Slack"
