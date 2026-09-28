#!/bin/bash

sketchybar --add item openai_usage right \
           --set openai_usage \
                       update_freq=60 \
                       icon=⬡ \
                       icon.padding_right=4 \
                       background.color=$COLOR_ITEM_BG \
                       background.corner_radius=8 \
                       background.padding_left=5 \
                       background.height=28 \
                       label="--" \
                       script="$PLUGIN_DIR/openai_usage.sh" \
                       click_script="open http://localhost:7779"
