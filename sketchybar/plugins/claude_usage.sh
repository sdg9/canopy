#!/bin/bash

DATA=$(curl -s http://localhost:7779/api/usage 2>/dev/null)
STATUS=$(curl -s http://localhost:7779/api/status 2>/dev/null)

if [ -z "$DATA" ] || [ -z "$STATUS" ]; then
    sketchybar --set $NAME label="CC: --" icon.color=0xffff6b6b
    exit 0
fi

TOKEN_HEALTH=$(echo "$STATUS" | jq -r '.tokenHealth // "unknown"')

if [ "$TOKEN_HEALTH" = "not_configured" ] || [ "$TOKEN_HEALTH" = "expired" ]; then
    sketchybar --set $NAME label="Token!" icon.color=0xffff6b6b
    exit 0
fi

# 5-hour session window
REMAINING=$(echo "$DATA" | jq -r '.data.five_hour.utilization | if . == null then "--" else (floor | tostring) end')

# Weekly (all-models) window
WEEKLY=$(echo "$DATA" | jq -r '.data.seven_day.utilization | if . == null then "--" else (floor | tostring) end')

# Color reflects whichever window is closer to its limit
REMAINING_NUM=$([ "$REMAINING" = "--" ] && echo 0 || echo "$REMAINING")
WEEKLY_NUM=$([ "$WEEKLY" = "--" ] && echo 0 || echo "$WEEKLY")
if [ "$WEEKLY_NUM" -gt "$REMAINING_NUM" ] 2>/dev/null; then
    WORST=$WEEKLY_NUM
else
    WORST=$REMAINING_NUM
fi

if [ "$WORST" -ge 85 ] 2>/dev/null; then
    COLOR="0xffff6b6b"
elif [ "$WORST" -ge 50 ] 2>/dev/null; then
    COLOR="0xffffd93d"
else
    COLOR="0xff6bcb77"
fi

# Compact format (no reset countdown) so it fits at the edge of the bar —
# click the item for the full dashboard with reset times.
sketchybar --set $NAME label="${REMAINING}% / ${WEEKLY}%wk" icon.color=$COLOR
