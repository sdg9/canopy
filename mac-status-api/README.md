# mac-status-api

Native macOS status server for sketchybar. Exposes calendar, Slack, and email data as JSON over HTTP so sketchybar plugins can be thin `curl | display` scripts.

## Why

- **Consistent pattern** — all sketchybar plugins now use the same `curl → parse JSON → update bar` pattern
- **Zero npm dependencies** — single file, no package.json, no node_modules, no supply chain risk
- **127.0.0.1 only** — unreachable from the network
- **`execFile` not `exec`** — no shell spawned, no injection vector
- **launchd managed** — native macOS, auto-restarts on crash, starts on login

## Endpoints

| Endpoint | Source | Cache TTL |
|----------|--------|-----------|
| `GET /api/calendar` | icalBuddy | 30s |
| `GET /api/slack` | lsappinfo | 10s |
| `GET /api/email` | osascript (Mail.app) | 30s |
| `GET /health` | — | none |

### Response examples

**`/api/calendar`**
```json
{
  "current": { "title": "Standup", "endTime": "10:30", "minutesRemaining": 8, "conflicts": 1 },
  "next": { "title": "Sprint Planning", "startTime": "11:00", "endTime": "11:30", "minutesUntil": 38, "conflicts": 0 }
}
```
`current` and/or `next` are `null` when no meetings apply. Returns `"available": false` if icalBuddy is not installed.

**`/api/slack`**
```json
{ "badge": 3, "indicator": false }
```
`indicator: true` when Slack shows the dot instead of a number.

**`/api/email`**
```json
{ "unread": 5, "available": true }
```
`available: false` when Mail.app isn't running.

**`/health`**
```json
{ "status": "ok", "uptime": 3600, "port": 7778 }
```

## Setup

### Prerequisites

- **Node.js** (any recent version)
- **icalBuddy** (optional, only needed for `/api/calendar`): `brew install ical-buddy`

### Install

```bash
cd ~/dev/canopy/mac-status-api
./install.sh
```

This will:
1. Detect your node binary path
2. Generate a launchd plist with the correct paths
3. Load the service via `launchctl bootstrap`

### Verify

```bash
curl -s http://localhost:7778/health
curl -s http://localhost:7778/api/calendar
curl -s http://localhost:7778/api/slack
curl -s http://localhost:7778/api/email
```

### Uninstall

```bash
cd ~/dev/canopy/mac-status-api
./uninstall.sh
```

## Configuration

| Env var | Default | Description |
|---------|---------|-------------|
| `MAC_STATUS_PORT` | `7778` | Port to listen on |

## Logs

```bash
tail -f /tmp/mac-status-api.log    # stdout
tail -f /tmp/mac-status-api.err    # stderr
```

## Troubleshooting

**Server not responding after install:**
```bash
# Check if it's running
pgrep -f "mac-status-api/server.js"

# Check launchd status
launchctl print gui/$(id -u)/com.canopy.mac-status-api

# Check error log
cat /tmp/mac-status-api.err
```

**Calendar returns `"available": false`:**
```bash
# Install icalBuddy and restart the service
brew install ical-buddy
cd ~/dev/canopy/mac-status-api && ./install.sh
```

**Auto-restart test:**
```bash
kill $(pgrep -f "mac-status-api/server.js")
sleep 5
curl -s http://localhost:7778/health   # should be back
```
