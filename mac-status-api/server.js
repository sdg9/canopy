const http = require('http');
const { execFile } = require('child_process');
const fs = require('fs');

const PORT = parseInt(process.env.MAC_STATUS_PORT || '7778', 10);
const BIND = '127.0.0.1';

// Absolute binary paths — no shell, no injection
const ICAL_BUDDY = '/opt/homebrew/bin/icalBuddy';
const LSAPPINFO = '/usr/bin/lsappinfo';
const OSASCRIPT = '/usr/bin/osascript';

const startTime = Date.now();

// Check icalBuddy availability at startup
let icalBuddyAvailable = false;
try {
  fs.accessSync(ICAL_BUDDY, fs.constants.X_OK);
  icalBuddyAvailable = true;
} catch {
  console.error(`Warning: icalBuddy not found at ${ICAL_BUDDY}`);
}

// ---------------------------------------------------------------------------
// Cache
// ---------------------------------------------------------------------------
const cache = new Map();
const CACHE_TTL = { calendar: 30000, slack: 10000, email: 30000 };

function getCached(key) {
  const entry = cache.get(key);
  if (entry && Date.now() - entry.time < CACHE_TTL[key]) return entry.data;
  return null;
}

function setCache(key, data) {
  cache.set(key, { data, time: Date.now() });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function run(bin, args, timeoutMs) {
  return new Promise((resolve, reject) => {
    execFile(bin, args, { timeout: timeoutMs }, (err, stdout) => {
      if (err) reject(err);
      else resolve(stdout);
    });
  });
}

// ---------------------------------------------------------------------------
// GET /api/calendar
// ---------------------------------------------------------------------------
async function getCalendar() {
  const cached = getCached('calendar');
  if (cached) return cached;

  if (!icalBuddyAvailable) {
    const result = { current: null, next: null, available: false };
    setCache('calendar', result);
    return result;
  }

  let output;
  try {
    output = await run(ICAL_BUDDY, [
      '-n', '-nc', '-li', '10', '-npn', '-nrd',
      '-tf', '%H:%M', '-df', '',
      '-eep', 'notes,attendees,location,url',
      'eventsToday'
    ], 5000);
  } catch {
    const result = { current: null, next: null, available: true };
    setCache('calendar', result);
    return result;
  }

  const now = new Date();
  const nowMins = now.getHours() * 60 + now.getMinutes();

  // Parse icalBuddy output: bullet lines are titles, time lines follow
  const events = [];
  let lastTitle = '';

  for (const line of output.split('\n')) {
    const trimmed = line.trim();
    if (trimmed.startsWith('\u2022')) {
      lastTitle = trimmed.replace(/^\u2022\s*/, '');
      continue;
    }
    const m = trimmed.match(/^(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})$/);
    if (m && lastTitle) {
      const [sh, sm] = m[1].split(':').map(Number);
      const [eh, em] = m[2].split(':').map(Number);
      events.push({
        title: lastTitle,
        startTime: m[1],
        endTime: m[2],
        startMins: sh * 60 + sm,
        endMins: eh * 60 + em
      });
    }
  }

  // Identify current and next meetings
  let current = null;
  let currentConflicts = 0;
  let next = null;
  let nextConflicts = 0;

  for (const ev of events) {
    if (nowMins >= ev.startMins && nowMins < ev.endMins) {
      if (!current) current = ev;
      else currentConflicts++;
    } else if (ev.startMins > nowMins) {
      if (!next) {
        next = ev;
      } else if (ev.startMins < next.endMins) {
        nextConflicts++;
      }
    }
  }

  const result = {
    current: current ? {
      title: current.title,
      endTime: current.endTime,
      minutesRemaining: current.endMins - nowMins,
      conflicts: currentConflicts
    } : null,
    next: next ? {
      title: next.title,
      startTime: next.startTime,
      endTime: next.endTime,
      minutesUntil: next.startMins - nowMins,
      conflicts: nextConflicts
    } : null
  };

  setCache('calendar', result);
  return result;
}

// ---------------------------------------------------------------------------
// GET /api/slack
// ---------------------------------------------------------------------------
async function getSlack() {
  const cached = getCached('slack');
  if (cached) return cached;

  let output;
  try {
    output = await run(LSAPPINFO, ['info', '-only', 'StatusLabel', 'Slack'], 3000);
  } catch {
    const result = { badge: 0, indicator: false };
    setCache('slack', result);
    return result;
  }

  const numMatch = output.match(/"label"\s*=\s*"(\d+)"/);
  const labelMatch = output.match(/"label"\s*=\s*"([^"]*)"/);

  let badge = 0;
  let indicator = false;

  if (numMatch) {
    badge = parseInt(numMatch[1], 10);
  } else if (labelMatch && labelMatch[1] !== '') {
    // Non-numeric label (e.g. dot indicator)
    indicator = true;
  }

  const result = { badge, indicator };
  setCache('slack', result);
  return result;
}

// ---------------------------------------------------------------------------
// GET /api/email
// ---------------------------------------------------------------------------
async function getEmail() {
  const cached = getCached('email');
  if (cached) return cached;

  let output;
  try {
    output = await run(OSASCRIPT, ['-e',
      'if application "Mail" is running then\n' +
      '  tell application "Mail" to return unread count of inbox\n' +
      'else\n' +
      '  return "not_running"\n' +
      'end if'
    ], 5000);
  } catch {
    const result = { unread: 0, available: false };
    setCache('email', result);
    return result;
  }

  const trimmed = output.trim();
  if (trimmed === 'not_running') {
    const result = { unread: 0, available: false };
    setCache('email', result);
    return result;
  }

  const count = parseInt(trimmed, 10);
  const result = { unread: isNaN(count) ? 0 : count, available: true };
  setCache('email', result);
  return result;
}

// ---------------------------------------------------------------------------
// GET /health
// ---------------------------------------------------------------------------
function getHealth() {
  return {
    status: 'ok',
    uptime: Math.floor((Date.now() - startTime) / 1000),
    port: PORT
  };
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------
const routes = {
  '/api/calendar': getCalendar,
  '/api/slack': getSlack,
  '/api/email': getEmail,
  '/health': () => getHealth()
};

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const handler = routes[url.pathname];

  res.setHeader('Content-Type', 'application/json');

  if (!handler) {
    res.writeHead(404);
    res.end(JSON.stringify({ error: 'not found' }));
    return;
  }

  try {
    const data = await handler();
    res.writeHead(200);
    res.end(JSON.stringify(data));
  } catch (err) {
    console.error(`Error handling ${url.pathname}:`, err.message);
    res.writeHead(500);
    res.end(JSON.stringify({ error: 'internal error' }));
  }
});

server.listen(PORT, BIND, () => {
  console.log(`mac-status-api listening on ${BIND}:${PORT}`);
  if (!icalBuddyAvailable) {
    console.log('  icalBuddy not found — /api/calendar will return unavailable');
  }
});
