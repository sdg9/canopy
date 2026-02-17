#!/bin/bash

# Email plugin — polls mac-status-api for unread count

API_URL="http://localhost:7778/api/email"

RESPONSE=$(curl -s --connect-timeout 2 "$API_URL" 2>/dev/null)

if [ -z "$RESPONSE" ] || echo "$RESPONSE" | grep -q '"error"'; then
    sketchybar --set "$NAME" label="--" icon.color=0xff8a8a8a label.color=0xff8a8a8a
    exit 0
fi

COUNT=$(echo "$RESPONSE" | grep -o '"unread":[0-9]*' | cut -d: -f2)
COUNT=${COUNT:-0}
AVAILABLE=$(echo "$RESPONSE" | grep -o '"available":true')

if [ -z "$AVAILABLE" ]; then
    # Mail.app not running
    sketchybar --set "$NAME" label="--" icon.color=0x88ffffff label.color=0x88ffffff
elif [ "$COUNT" = "0" ]; then
    sketchybar --set "$NAME" label="$COUNT" icon.color=0x88ffffff label.color=0x88ffffff
else
    sketchybar --set "$NAME" label="$COUNT" icon.color=0xffffffff label.color=0xffffffff
fi
