#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CANOPY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LABEL="com.canopy.mac-status-api"
PLIST_SRC="$SCRIPT_DIR/$LABEL.plist"
PLIST_DST="$HOME/Library/LaunchAgents/$LABEL.plist"

NODE_PATH=$(which node 2>/dev/null || true)
if [ -z "$NODE_PATH" ]; then
    echo "Error: node not found in PATH"
    exit 1
fi

echo "Using node: $NODE_PATH"
echo "Canopy:     $CANOPY_DIR"

# Unload existing if present
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true

mkdir -p "$HOME/Library/LaunchAgents"

# Substitute placeholders and install plist
sed -e "s|__NODE_PATH__|$NODE_PATH|g" \
    -e "s|__CANOPY_PATH__|$CANOPY_DIR|g" \
    "$PLIST_SRC" > "$PLIST_DST"

launchctl bootstrap "gui/$(id -u)" "$PLIST_DST"

echo "Loaded $LABEL"
echo "  Verify: curl -s http://localhost:7778/health"
