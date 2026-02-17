#!/bin/bash

# Media controls - shows when YouTube Music is running
# No state tracking - just show/hide based on app running

# Check if YouTube Music PWA is running
YTM_RUNNING=$(pgrep -f "YouTube Music" 2>/dev/null)

if [ -z "$YTM_RUNNING" ]; then
    # Hide all media controls
    sketchybar --set media_prev drawing=off \
               --set media_play drawing=off \
               --set media_next drawing=off
else
    # Show controls with static play/pause icon
    sketchybar --set media_prev drawing=on \
               --set media_play drawing=on icon=󰐎 icon.color=0xffffffff \
               --set media_next drawing=on
fi
