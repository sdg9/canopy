#!/bin/bash

sketchybar --add item nowplaying right \
           --set nowplaying \
                          update_freq=5 \
                          icon=󰎆 \
                          icon.padding_right=4 \
                          background.color=0x00000000 \
                          drawing=off \
                          script="$PLUGIN_DIR/nowplaying.sh" \
                          click_script="$PLUGIN_DIR/switch_workspace.sh Y"

sketchybar --add item media_next right \
           --set media_next \
                          icon=󰒭 \
                          icon.color=$COLOR_TEXT_DIM \
                          icon.padding_left=4 \
                          icon.padding_right=4 \
                          label.drawing=off \
                          background.color=0x00000000 \
                          drawing=off \
                          script="$PLUGIN_DIR/media_controls.sh" \
                          click_script="nowplaying-cli next"

sketchybar --add item media_play right \
           --set media_play \
                          update_freq=3 \
                          icon=󰐊 \
                          icon.color=$COLOR_TEXT_DIM \
                          icon.padding_left=6 \
                          icon.padding_right=6 \
                          label.drawing=off \
                          background.color=0x00000000 \
                          drawing=off \
                          script="$PLUGIN_DIR/media_controls.sh" \
                          click_script="nowplaying-cli togglePlayPause"

sketchybar --add item media_prev right \
           --set media_prev \
                          icon=󰒮 \
                          icon.color=$COLOR_TEXT_DIM \
                          icon.padding_left=4 \
                          icon.padding_right=4 \
                          label.drawing=off \
                          background.color=0x00000000 \
                          drawing=off \
                          script="$PLUGIN_DIR/media_controls.sh" \
                          click_script="nowplaying-cli previous"

# Group all media items into one shared pill
sketchybar --add bracket media_bracket nowplaying media_next media_play media_prev \
           --set media_bracket \
                          background.color=$COLOR_ITEM_BG \
                          background.corner_radius=8 \
                          background.height=28
