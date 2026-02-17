#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CANOPY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LABEL="com.canopy.claude-usage-api"
PLIST_SRC="$SCRIPT_DIR/$LABEL.plist"
PLIST_DST="$HOME/Library/LaunchAgents/$LABEL.plist"
PORT=7779

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

# Wait for health check
echo "Waiting for server to start..."
for i in $(seq 1 15); do
    if curl -s "http://localhost:$PORT/health" > /dev/null 2>&1; then
        echo "Server is up!"
        break
    fi
    sleep 1
done

if ! curl -s "http://localhost:$PORT/health" > /dev/null 2>&1; then
    echo "Warning: Server did not respond within 15 seconds."
    echo "  Check logs: tail -f /tmp/claude-usage-api.log /tmp/claude-usage-api.err"
    exit 1
fi

# Check if token is already configured
STATUS=$(curl -s "http://localhost:$PORT/api/status" 2>/dev/null)
if echo "$STATUS" | grep -q '"remaining"'; then
    echo "Claude usage is working — visit http://localhost:$PORT to manage."
else
    echo "Configure your token at http://localhost:$PORT"
fi
