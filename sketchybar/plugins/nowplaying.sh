#!/bin/bash

# Get now playing info using nowplaying-cli (install: brew install nowplaying-cli)
# Falls back to checking if any media app is playing

if command -v nowplaying-cli &> /dev/null; then
  TITLE=$(nowplaying-cli get title 2>/dev/null)
  ARTIST=$(nowplaying-cli get artist 2>/dev/null)
  STATE=$(nowplaying-cli get playbackRate 2>/dev/null)
  
  if [ -n "$TITLE" ] && [ "$TITLE" != "null" ] && [ "$STATE" != "0" ]; then
    # Playing - truncate if too long
    if [ ${#TITLE} -gt 25 ]; then
      TITLE="${TITLE:0:22}..."
    fi
    sketchybar --set $NAME label="$TITLE" icon=󰎆 icon.color=0xffff6b6b drawing=on
  elif [ -n "$TITLE" ] && [ "$TITLE" != "null" ]; then
    # Paused
    sketchybar --set $NAME label="$TITLE" icon=󰏤 icon.color=0x88ffffff drawing=on
  else
    # Nothing playing
    sketchybar --set $NAME drawing=off
  fi
else
  # Fallback: check Chrome/YouTube Music via AppleScript
  PLAYING=$(osascript -e '
    tell application "System Events"
      if exists process "Google Chrome" then
        tell application "Google Chrome"
          repeat with w in windows
            repeat with t in tabs of w
              if URL of t contains "music.youtube.com" then
                return title of t
              end if
            end repeat
          end repeat
        end tell
      end if
    end tell
    return ""
  ' 2>/dev/null)
  
  if [ -n "$PLAYING" ] && [ "$PLAYING" != "" ]; then
    # Remove " - YouTube Music" suffix
    PLAYING="${PLAYING% - YouTube Music}"
    if [ ${#PLAYING} -gt 25 ]; then
      PLAYING="${PLAYING:0:22}..."
    fi
    sketchybar --set $NAME label="$PLAYING" icon=󰎆 icon.color=0xffff6b6b drawing=on
  else
    sketchybar --set $NAME drawing=off
  fi
fi
