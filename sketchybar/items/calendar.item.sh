#!/bin/bash

sketchybar --add item calendar_current right \
           --set calendar_current \
                          update_freq=60 \
                          icon=󰃮 \
                          icon.padding_right=4 \
                          background.color=$COLOR_ITEM_BG \
                          background.corner_radius=8 \
                          background.padding_left=5 \
                          background.height=28 \
                          drawing=off \
                          script="$PLUGIN_DIR/calendar.sh" \
                          click_script="open '$HOME/Applications/Chrome Apps.localized/Google Calendar.app'"

sketchybar --add item calendar_next right \
           --set calendar_next \
                          icon=󰃭 \
                          icon.padding_right=4 \
                          background.color=$COLOR_ITEM_BG \
                          background.corner_radius=8 \
                          background.padding_left=5 \
                          background.height=28 \
                          click_script="open '$HOME/Applications/Chrome Apps.localized/Google Calendar.app'"
