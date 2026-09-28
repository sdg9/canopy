#!/usr/bin/env node
'use strict';

const http = require('http');
const { execFile } = require('child_process');

const PORT = parseInt(process.env.PORT || '3024', 10);
const BIND = process.env.BIND || '127.0.0.1';
const POLL_INTERVAL_MS = parseInt(process.env.POLL_INTERVAL_MS || '60000', 10);
const PEEKABOO_PATH = process.env.PEEKABOO_PATH || '/opt/homebrew/bin/peekaboo';
// peekaboo `see` always saves a screenshot. Pin it to a single file in /tmp so
// it gets overwritten each poll instead of piling up on the Desktop.
const SNAPSHOT_PATH = process.env.SNAPSHOT_PATH || '/tmp/canopy-gvoice-snapshot.png';

const startTime = Date.now();
let gvoiceCache = { messages: 0, calls: 0, voicemail: 0, spam: 0 };
let lastFetchedAt = null;
let lastError = null;

// Real Google Voice tab labels, observed from peekaboo output:
//   "Calls"                      → 0 unread
//   "Messages"                   → 0 unread
//   "Voicemail: 159 unread"      → 159 unread
//   "Spam: 536 unread"           → 536 unread
// Older spec mentioned "(3) Messages" — keep that pattern as a fallback.
const COLON_RE = /^(Messages|Calls|Voicemail|Spam):\s*(\d+)\s*unread\b/i;
const PAREN_RE = /\((\d+)\)\s*(Messages|Calls|Voicemail|Spam)\b/i;
const BARE_RE  = /^(Messages|Calls|Voicemail|Spam)$/i;

function parsePeekabooOutput(stdout) {
  const counts = { messages: 0, calls: 0, voicemail: 0, spam: 0 };
  const seen = { messages: false, calls: false, voicemail: false, spam: false };
  let data;
  try {
    data = JSON.parse(stdout);
  } catch (e) {
    throw new Error('peekaboo returned non-JSON output');
  }
  const elements = (data && data.data && data.data.ui_elements) || [];
  for (const el of elements) {
    for (const field of ['description', 'title', 'label']) {
      const v = el && el[field];
      if (typeof v !== 'string') continue;
      let key = null;
      let n = null;
      let m;
      if ((m = v.match(COLON_RE))) {
        key = m[1].toLowerCase();
        n = parseInt(m[2], 10);
      } else if ((m = v.match(PAREN_RE))) {
        key = m[2].toLowerCase();
        n = parseInt(m[1], 10);
      } else if ((m = v.match(BARE_RE))) {
        key = m[1].toLowerCase();
        n = 0;
      }
      if (key && key in counts) {
        // First match wins per category; bare-zero shouldn't overwrite a count.
        if (!seen[key] || (seen[key] && counts[key] === 0 && n > 0)) {
          counts[key] = n;
          seen[key] = true;
        }
      }
    }
  }
  return counts;
}

function fetchGvoice() {
  execFile(
    PEEKABOO_PATH,
    ['see', '--app', 'Google Voice', '--json', '--path', SNAPSHOT_PATH],
    { timeout: 15000, maxBuffer: 32 * 1024 * 1024 },
    (err, stdout, stderr) => {
      if (err) {
        let parsed = null;
        for (const blob of [stdout, stderr]) {
          if (!blob) continue;
          try {
            const j = JSON.parse(blob);
            if (j && j.error) { parsed = j.error; break; }
          } catch (_) {}
        }
        const stderrSnippet = (stderr || '').slice(0, 800).trim();
        const stdoutSnippet = (stdout || '').slice(0, 800).trim();
        const exitCode = err.code != null ? err.code : null;
        const signal = err.signal || null;
        lastError = {
          message: parsed
            ? `${parsed.code || 'ERROR'}: ${parsed.message || err.message}`
            : `${err.message} (exit=${exitCode}, signal=${signal})${stderrSnippet ? ` | stderr: ${stderrSnippet}` : ''}${!stderrSnippet && stdoutSnippet ? ` | stdout: ${stdoutSnippet}` : ''}`,
          code: parsed && parsed.code ? parsed.code : null,
          at: new Date().toISOString(),
        };
        return;
      }
      try {
        gvoiceCache = parsePeekabooOutput(stdout);
        lastFetchedAt = new Date().toISOString();
        lastError = null;
      } catch (e) {
        lastError = { message: e.message, code: null, at: new Date().toISOString() };
      }
    }
  );
}

function sendJson(res, status, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
    'Cache-Control': 'no-store',
  });
  res.end(body);
}

const server = http.createServer((req, res) => {
  if (req.method !== 'GET') {
    return sendJson(res, 405, { error: 'method not allowed' });
  }
  const url = req.url.split('?')[0];
  if (url === '/api/gvoice') {
    return sendJson(res, 200, { ...gvoiceCache, lastFetchedAt });
  }
  if (url === '/api/summary') {
    return sendJson(res, 200, { gvoice: gvoiceCache, lastFetchedAt });
  }
  if (url === '/api/health') {
    const status = lastError && !lastFetchedAt ? 'error' : 'ok';
    return sendJson(res, 200, {
      status,
      uptime: Math.floor((Date.now() - startTime) / 1000),
      lastFetchedAt,
      lastError,
    });
  }
  return sendJson(res, 404, { error: 'not found' });
});

server.listen(PORT, BIND, () => {
  console.log(`canopy-gvoice listening on ${BIND}:${PORT}`);
  fetchGvoice();
  setInterval(fetchGvoice, POLL_INTERVAL_MS);
});
