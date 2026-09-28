#!/bin/bash

DATA=$(curl -s http://localhost:7779/api/openai/usage 2>/dev/null)

if [ -z "$DATA" ]; then
    sketchybar --set $NAME label="--" icon.color=0xffff6b6b
    exit 0
fi

ERROR=$(echo "$DATA" | jq -r '.error // empty')
HAS_DATA=$(echo "$DATA" | jq -r 'if .data == null then "no" else "yes" end')

if [ -n "$ERROR" ] || [ "$HAS_DATA" = "no" ]; then
    sketchybar --set $NAME label="No token" icon.color=0xffff6b6b
    exit 0
fi

# Weekly (all-models) window — Codex's "primary" bucket is the weekly limit
READ=$(echo "$DATA" | jq -r '
    .data.rateLimits.primary
    | if . == null then "null null" else "\(.usedPercent) \(.resetsAt)" end
')
WEEKLY=$(echo "$READ" | awk '{print $1}')
RESETS_AT=$(echo "$READ" | awk '{print $2}')

NOW_EPOCH=$(date -u +%s)
if [ -n "$RESETS_AT" ] && [ "$RESETS_AT" != "null" ]; then
    RESETS_MINS=$(( (RESETS_AT - NOW_EPOCH) / 60 ))
else
    RESETS_MINS=0
fi

if [ "$RESETS_MINS" -gt 1440 ] 2>/dev/null; then
    DAYS=$((RESETS_MINS / 1440))
    HOURS=$(((RESETS_MINS % 1440) / 60))
    TIME_LEFT="${DAYS}d${HOURS}h"
elif [ "$RESETS_MINS" -gt 60 ] 2>/dev/null; then
    HOURS=$((RESETS_MINS / 60))
    MINS=$((RESETS_MINS % 60))
    TIME_LEFT="${HOURS}h${MINS}m"
elif [ "$RESETS_MINS" -gt 0 ] 2>/dev/null; then
    TIME_LEFT="${RESETS_MINS}m"
else
    TIME_LEFT="--"
fi

if [ "$WEEKLY" -ge 85 ] 2>/dev/null; then
    COLOR="0xffff6b6b"
elif [ "$WEEKLY" -ge 50 ] 2>/dev/null; then
    COLOR="0xffffd93d"
else
    COLOR="0xff6bcb77"
fi

if [ -z "$WEEKLY" ] || [ "$WEEKLY" = "null" ]; then
    sketchybar --set $NAME label="--" icon.color=0xffff6b6b
    exit 0
fi

sketchybar --set $NAME label="${WEEKLY}% ↻${TIME_LEFT}wk" icon.color=$COLOR
