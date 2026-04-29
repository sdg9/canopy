#!/bin/bash
set -euo pipefail

LABEL="com.canopy.gvoice"
PLIST_DST="$HOME/Library/LaunchAgents/$LABEL.plist"
UID_NUM="$(id -u)"

launchctl bootout "gui/$UID_NUM/$LABEL" 2>/dev/null || true
rm -f "$PLIST_DST"
echo "uninstalled $LABEL"
