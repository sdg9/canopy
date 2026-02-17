#!/bin/bash
# Launch apps for AeroSpace workspaces
# Apps are automatically placed via on-window-detected rules in aerospace.toml
#
# Usage: aerospace-launch.sh [--all]
#   --all    Launch everything (default: skip already-running apps)

set -euo pipefail

launch() {
  local app="$1"
  local bundle_id="${2:-}"

  # Skip if already running (when bundle_id provided)
  if [[ -n "$bundle_id" ]] && pgrep -f "$bundle_id" > /dev/null 2>&1; then
    echo "  ↳ $app already running, skipping"
    return
  fi

  echo "  ↳ Opening $app..."
  open -a "$app" 2>/dev/null || echo "    ⚠ Failed to open $app"
}

echo "🚀 Launching AeroSpace workspace apps..."
echo ""

# C = Code
echo "[C] Code"
launch "Visual Studio Code" "com.microsoft.VSCode"

# T = Terminal
echo "[T] Terminal"
launch "iTerm" "com.googlecode.iterm2"

# D = Debug
echo "[D] Debug"
launch "App Inspector" "com.google.Chrome.app.nkffbedfbodgigofpofbjjljcfnkmjbd"
launch "Mock Server" "com.google.Chrome.app.nlglegpjillngfijdnlcnlbbpfmkcpmn"

# W = Web
echo "[W] Web"
launch "Google Chrome" "com.google.Chrome"

# S = Slack
echo "[S] Slack"
launch "Slack" "com.tinyspeck.slackmacgap"

# N = Notes
echo "[N] Notes"
launch "Obsidian" "md.obsidian"

# B = Board
echo "[B] Board"
launch "Kanban" "com.google.Chrome.app.afpppjliigpcejdmogakhknfdanjbbon"

# M = Meetings
echo "[M] Meetings"
launch "Gmail" "com.google.Chrome.app.fmgjjmmmlfnkbppncabfkddbjimcfncm"
launch "Calendar" "com.apple.iCal"
launch "Google Calendar" "com.google.Chrome.app.kjbdgfilnfhdoflbpgamdcdgpehopbep"

# Y = Music & Voice
echo "[Y] Music & Voice"
launch "YouTube Music" "com.google.Chrome.app.cinhimbnkkaeohfgghhklpknlkffjgod"
launch "Google Voice" "com.google.Chrome.app.bbcbahpbnakjldhdcgiblnjnfgaejidg"

# P = 1Password
echo "[P] 1Password"
launch "1Password" "com.1password.1password"

echo ""
echo "✅ Done! Apps will land in their workspaces via aerospace rules."
