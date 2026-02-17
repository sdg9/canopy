#!/bin/bash

# Slack plugin — polls mac-status-api for badge count
# Badge = mentions & DMs (important), not regular channel unreads

API_URL="http://localhost:7778/api/slack"
ICON="󰒱"

RESPONSE=$(curl -s --connect-timeout 2 "$API_URL" 2>/dev/null)

if [ -z "$RESPONSE" ] || echo "$RESPONSE" | grep -q '"error"'; then
    sketchybar --set "$NAME" icon="$ICON" label="--" icon.color=0xff8a8a8a label.color=0xff8a8a8a
    exit 0
fi

BADGE=$(echo "$RESPONSE" | grep -o '"badge":[0-9]*' | cut -d: -f2)
BADGE=${BADGE:-0}
INDICATOR=$(echo "$RESPONSE" | grep -o '"indicator":true')

if [ "$BADGE" -gt 0 ]; then
    # Has mentions/DMs — alert style
    sketchybar --set "$NAME" \
        icon=$ICON \
        label="$BADGE" \
        icon.color=0xffff6b6b \
        label.color=0xffffffff \
        background.color=0x44ff6b6b
elif [ -n "$INDICATOR" ]; then
    # Dot indicator — unreads but no direct mentions
    sketchybar --set "$NAME" \
        icon=$ICON \
        label="•" \
        icon.color=0xffffd93d \
        label.color=0xffffd93d \
        background.color=0x22ffffff
else
    # No mentions — dim
    sketchybar --set "$NAME" \
        icon=$ICON \
        label="0" \
        icon.color=0xff8a8a8a \
        background.color=0x22ffffff
fi
