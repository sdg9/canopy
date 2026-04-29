# gvoice — sketchybar Google Voice unread badge

A sketchybar item that shows the unread Google Voice Messages count and opens
the Google Voice app on click.

There is no public Google Voice API, so the data is scraped from the running
macOS Google Voice app's accessibility/UI tree via
[`peekaboo`](https://github.com/steipete/peekaboo).

## Architecture

1. **Background HTTP service** (`service/server.js`) bound to
   `127.0.0.1:3024`. Polls every 60s, caches the latest counts, and exposes
   JSON at `/api/gvoice`, `/api/summary`, `/api/health`.
2. **Scraper**: `peekaboo see --app "Google Voice" --json` dumps the UI tree;
   the server greps `data.ui_elements[*].title|label|description` for
   `(\d+) (Messages|Calls|Voicemail|Spam)` (e.g. `"(3) Messages"`).
3. **TCC wrapper `CanopyGvoice.app`**: a tiny Swift binary that just `execv`s
   its arguments. macOS LaunchAgents do **not** inherit Terminal's TCC grants;
   permission is keyed to the parent process bundle. The .app is what you
   grant Screen Recording (and Accessibility, if needed) to; `node` and the
   `peekaboo` child inherit the grant.
4. **sketchybar plugin** (`item.sh`, `plugin.sh`): registers the item, queries
   the local API every `update_freq` seconds.

## Requirements

```sh
brew install peekaboo node
```

You also need sketchybar and a Nerd Font for the phone glyph (`󰏲`), and the
**Google Voice macOS app installed and running** (sign in once). peekaboo can
only read the UI of a running app.

## Install

```sh
cd gvoice/service
./install.sh
```

Then in **System Settings → Privacy & Security → Screen Recording**, add
`gvoice/service/CanopyGvoice.app` and toggle it on. If `/api/health` later
reports `PERMISSION_ERROR_ACCESSIBILITY`, add the same .app under
**Accessibility** too.

After granting the permission, restart the service so it picks up the new TCC
decision (TCC caches per-process):

```sh
launchctl kickstart -k gui/$(id -u)/com.canopy.gvoice
curl -s http://127.0.0.1:3024/api/health
```

## Wire into canopy

In `~/.config/sketchybar/../config.sh` (or wherever your canopy `config.sh`
lives) add this directory to `PLUGIN_DIRS` and enable it:

```sh
PLUGIN_DIRS="$HOME/dev/canopy/gvoice/.."   # parent dir of the plugin folder
ENABLED_PLUGINS="gvoice"
```

Then `sketchybar --reload`.

## Endpoints

- `GET /api/gvoice` → `{messages, calls, voicemail, spam, lastFetchedAt}`
- `GET /api/summary` → `{gvoice: {...}, lastFetchedAt}`
- `GET /api/health` → `{status, uptime, lastFetchedAt, lastError}`

## Uninstall

```sh
cd gvoice/service && ./uninstall.sh
```

## Gotchas

- Don't run `node` directly from the LaunchAgent — TCC grants are tied to the
  bundle/binary identity of the executing process. Granting Screen Recording
  to `node` or Terminal won't apply to the LaunchAgent. The Swift .app exists
  solely as a stable, codesigned-by-you bundle to hold the permission.
- After granting permission, you must restart the running process (TCC
  decisions are cached per-process). `KeepAlive` will respawn it.
- Google Voice must be running and signed in.
- Label texts (`(N) Messages` etc.) are localized — the regex assumes English.
