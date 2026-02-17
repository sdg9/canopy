#!/bin/bash

# Bar appearance — transparent bar, items have their own backgrounds
# position=top, no display filter = all monitors
sketchybar --bar position=top height=40 blur_radius=30 color=$COLOR_BAR_BG topmost=window y_offset=39 margin=10 corner_radius=12 shadow=on
