#!/bin/bash

# Calendar plugin — polls mac-status-api for current + next meeting

API_URL="http://localhost:7778/api/calendar"

RESPONSE=$(curl -s --connect-timeout 2 "$API_URL" 2>/dev/null)

if [ -z "$RESPONSE" ] || echo "$RESPONSE" | grep -q '"error"'; then
    sketchybar --set calendar_current drawing=off
    sketchybar --set calendar_next label="--" icon="󰃭" icon.color=0xff8a8a8a label.color=0xff8a8a8a drawing=on
    exit 0
fi

# --- Current meeting ---
CURRENT=$(echo "$RESPONSE" | grep -o '"current":{[^}]*}')

if [ -n "$CURRENT" ]; then
    TITLE=$(echo "$CURRENT" | grep -o '"title":"[^"]*"' | head -1 | cut -d'"' -f4)
    MINS_LEFT=$(echo "$CURRENT" | grep -o '"minutesRemaining":[0-9]*' | cut -d: -f2)
    CONFLICTS=$(echo "$CURRENT" | grep -o '"conflicts":[0-9]*' | cut -d: -f2)

    MINS_LEFT=${MINS_LEFT:-0}
    CONFLICTS=${CONFLICTS:-0}

    if [ "$CONFLICTS" -gt 0 ]; then
        [ ${#TITLE} -gt 10 ] && TITLE="${TITLE:0:10}…"
        LABEL="NOW +${CONFLICTS} ${TITLE}"
    else
        [ ${#TITLE} -gt 14 ] && TITLE="${TITLE:0:14}…"
        LABEL="NOW ${TITLE}"
    fi

    if [ "$MINS_LEFT" -le 10 ]; then
        LABEL="${LABEL} (${MINS_LEFT}m)"
    fi

    sketchybar --set calendar_current \
        label="$LABEL" \
        icon="󰃮" \
        icon.color=0xffff6b6b \
        label.color=0xffffffff \
        drawing=on
else
    sketchybar --set calendar_current drawing=off
fi

# --- Next meeting ---
NEXT=$(echo "$RESPONSE" | grep -o '"next":{[^}]*}')

if [ -n "$NEXT" ]; then
    TITLE=$(echo "$NEXT" | grep -o '"title":"[^"]*"' | head -1 | cut -d'"' -f4)
    MINS=$(echo "$NEXT" | grep -o '"minutesUntil":[0-9]*' | cut -d: -f2)
    CONFLICTS=$(echo "$NEXT" | grep -o '"conflicts":[0-9]*' | cut -d: -f2)

    MINS=${MINS:-0}
    CONFLICTS=${CONFLICTS:-0}

    if [ "$MINS" -ge 60 ]; then
        HOURS=$((MINS / 60))
        REMAINDER=$((MINS % 60))
        TIME_DISPLAY="${HOURS}h${REMAINDER}m"
    else
        TIME_DISPLAY="${MINS}m"
    fi

    if [ "$CONFLICTS" -gt 0 ]; then
        [ ${#TITLE} -gt 10 ] && TITLE="${TITLE:0:10}…"
        LABEL="${TIME_DISPLAY} +${CONFLICTS} ${TITLE}"
        ICON_COLOR="0xffffd93d"
    else
        [ ${#TITLE} -gt 14 ] && TITLE="${TITLE:0:14}…"
        LABEL="${TIME_DISPLAY} ${TITLE}"

        if [ "$MINS" -le 5 ]; then
            ICON_COLOR="0xffff6b6b"
        elif [ "$MINS" -le 15 ]; then
            ICON_COLOR="0xffffd93d"
        else
            ICON_COLOR="0xff98c379"
        fi
    fi

    sketchybar --set calendar_next \
        label="$LABEL" \
        icon="󰃭" \
        icon.color="$ICON_COLOR" \
        label.color=0xffffffff \
        drawing=on
else
    sketchybar --set calendar_next \
        label="Clear" \
        icon="󰃭" \
        icon.color=0xff8a8a8a \
        label.color=0xff8a8a8a \
        drawing=on
fi
