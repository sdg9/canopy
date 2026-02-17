#!/bin/bash

# Handle display changes - when undocked, show all workspaces on laptop

DISPLAY_COUNT=$(system_profiler SPDisplaysDataType 2>/dev/null | grep -c "Resolution:")

if [ "$DISPLAY_COUNT" -eq 1 ]; then
    # Undocked - show all workspaces on the single display
    sketchybar --set aerospace.1 display=1 \
               --set aerospace.2 display=1 \
               --set aerospace.3 display=1 \
               --set aerospace.4 display=1 \
               --set aerospace.5 display=1 \
               --set aerospace.6 display=1
else
    # Docked - show workspaces on their assigned monitors
    # Display 1 = laptop, Display 2 = left 4K, Display 3 = right 4K
    sketchybar --set aerospace.1 display=2 \
               --set aerospace.2 display=3 \
               --set aerospace.6 display=3 \
               --set aerospace.3 display=1 \
               --set aerospace.4 display=1 \
               --set aerospace.5 display=1
fi
