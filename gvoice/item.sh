#!/bin/bash

sketchybar --add item gvoice right \
           --set gvoice \
                       update_freq=60 \
                       icon=󰏲 \
                       icon.padding_right=4 \
                       background.color=0x22ffffff \
                       background.corner_radius=5 \
                       background.padding_left=5 \
                       background.height=25 \
                       label="--" \
                       script="$PLUGIN_ITEM_DIR/plugin.sh" \
                       click_script="open -a 'Google Voice'"
