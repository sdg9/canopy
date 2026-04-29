#!/bin/bash
# Sketchybar gvoice plugin — queries the local canopy-gvoice service for the
# unread Messages count and updates the item.

API_URL="http://127.0.0.1:3024/api/gvoice"

RESPONSE=$(curl -s --connect-timeout 2 "$API_URL" 2>/dev/null)

if [ -z "$RESPONSE" ] || echo "$RESPONSE" | grep -q '"error"'; then
    sketchybar --set "$NAME" label="--" icon.color=0x88ffffff label.color=0x88ffffff
    exit 0
fi

COUNT=$(echo "$RESPONSE" | grep -o '"messages":[0-9]*' | cut -d: -f2)
COUNT=${COUNT:-0}

if [ "$COUNT" = "0" ]; then
    sketchybar --set "$NAME" label="$COUNT" icon.color=0x88ffffff label.color=0x88ffffff
else
    sketchybar --set "$NAME" label="$COUNT" icon.color=0xffffffff label.color=0xffffffff
fi
