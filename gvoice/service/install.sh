#!/bin/bash
# Install canopy-gvoice as a per-user LaunchAgent.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LABEL="com.canopy.gvoice"
PLIST_SRC="$SCRIPT_DIR/$LABEL.plist"
PLIST_DST="$HOME/Library/LaunchAgents/$LABEL.plist"

NODE_PATH="$(command -v node || true)"
if [ -z "$NODE_PATH" ]; then
    echo "error: node not found in PATH" >&2
    exit 1
fi

if [ ! -x "$SCRIPT_DIR/CanopyGvoice.app/Contents/MacOS/canopy-gvoice" ]; then
    echo "Building TCC wrapper..."
    "$SCRIPT_DIR/build.sh"
fi

mkdir -p "$HOME/Library/LaunchAgents"

# Use a sed delimiter that won't appear in paths.
sed \
  -e "s|__SERVICE_DIR__|$SCRIPT_DIR|g" \
  -e "s|__NODE_PATH__|$NODE_PATH|g" \
  "$PLIST_SRC" > "$PLIST_DST"

UID_NUM="$(id -u)"
launchctl bootout "gui/$UID_NUM/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$UID_NUM" "$PLIST_DST"
launchctl enable "gui/$UID_NUM/$LABEL" 2>/dev/null || true

echo "installed $PLIST_DST"
echo
echo "Next steps:"
echo "  1. System Settings → Privacy & Security → Screen Recording"
echo "     Add: $SCRIPT_DIR/CanopyGvoice.app  (and enable)"
echo "  2. (If /api/health reports PERMISSION_ERROR_ACCESSIBILITY)"
echo "     Privacy & Security → Accessibility → add the same .app"
echo "  3. launchctl kickstart -k gui/$UID_NUM/$LABEL"
echo "  4. curl -s http://127.0.0.1:3024/api/health"
