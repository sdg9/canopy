#!/bin/bash

# Fetch usage from claude-usage-api
DATA=$(curl -s http://localhost:7779/api/status 2>/dev/null)

if [ -z "$DATA" ]; then
    sketchybar --set $NAME label="CC: --" icon.color=0xffff6b6b
    exit 0
fi

TOKEN_HEALTH=$(echo "$DATA" | jq -r '.tokenHealth // "unknown"')

if [ "$TOKEN_HEALTH" = "not_configured" ] || [ "$TOKEN_HEALTH" = "expired" ]; then
    sketchybar --set $NAME label="Token!" icon.color=0xffff6b6b
    exit 0
fi

REMAINING=$(echo "$DATA" | jq -r '.remaining // 0')
RESETS_MINS=$(echo "$DATA" | jq -r '.resetsInMinutes // 0')

# Format time until reset
if [ "$RESETS_MINS" -gt 60 ] 2>/dev/null; then
    HOURS=$((RESETS_MINS / 60))
    MINS=$((RESETS_MINS % 60))
    TIME_LEFT="${HOURS}h${MINS}m"
elif [ "$RESETS_MINS" -gt 0 ] 2>/dev/null; then
    TIME_LEFT="${RESETS_MINS}m"
else
    TIME_LEFT="--"
fi

# Set color based on remaining percentage
if [ "$REMAINING" -ge 85 ] 2>/dev/null; then
    COLOR="0xffff6b6b"  # Red
elif [ "$REMAINING" -ge 50 ] 2>/dev/null; then
    COLOR="0xffffd93d"  # Yellow
else
    COLOR="0xff6bcb77"  # Green
fi

sketchybar --set $NAME label="${REMAINING}% ↻${TIME_LEFT}" icon.color=$COLOR
