const http = require('http');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { spawn } = require('child_process');

const PORT = parseInt(process.env.CLAUDE_USAGE_PORT || '7779', 10);
const BIND = '127.0.0.1';

const DATA_DIR = path.join(os.homedir(), '.config', 'claude-usage');
const TOKENS_PATH = path.join(DATA_DIR, 'tokens.json');
const CONFIG_PATH = path.join(DATA_DIR, 'config.json');
const SECRET_PATH = path.join(DATA_DIR, '.secret');

const DEFAULT_CLIENT_ID = '9d1c250a-e61b-44d9-88ed-5944d1962f5e';
const OAUTH_SCOPES = 'user:profile user:inference';
const OAUTH_REDIRECT_URI = 'https://console.anthropic.com/oauth/code/callback';
const DEFAULT_POLL_INTERVAL_MS = 5 * 60 * 1000; // 5 minutes
const TOKEN_REFRESH_BUFFER_MS = 30 * 60 * 1000; // 30 minutes before expiry

const startTime = Date.now();

// ---------------------------------------------------------------------------
// Encryption helpers
// ---------------------------------------------------------------------------

function ensureDataDir() {
  if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true, mode: 0o700 });
  }
}

function getEncryptionKey() {
  ensureDataDir();
  let secret = process.env.CLAUDE_USAGE_SECRET;
  if (!secret) {
    if (fs.existsSync(SECRET_PATH)) {
      secret = fs.readFileSync(SECRET_PATH, 'utf8').trim();
    } else {
      secret = crypto.randomBytes(32).toString('hex');
      fs.writeFileSync(SECRET_PATH, secret, { mode: 0o600 });
    }
  }
  return crypto.scryptSync(secret, 'claude-usage-salt', 32);
}

function encrypt(text) {
  const key = getEncryptionKey();
  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  let encrypted = cipher.update(text, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  const tag = cipher.getAuthTag().toString('hex');
  return `${iv.toString('hex')}:${tag}:${encrypted}`;
}

function decrypt(data) {
  const key = getEncryptionKey();
  const [ivHex, tagHex, encrypted] = data.split(':');
  const iv = Buffer.from(ivHex, 'hex');
  const tag = Buffer.from(tagHex, 'hex');
  const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAuthTag(tag);
  let decrypted = decipher.update(encrypted, 'hex', 'utf8');
  decrypted += decipher.final('utf8');
  return decrypted;
}

// ---------------------------------------------------------------------------
// Data file helpers
// ---------------------------------------------------------------------------

function readTokens() {
  if (!fs.existsSync(TOKENS_PATH)) return null;
  try {
    const raw = JSON.parse(fs.readFileSync(TOKENS_PATH, 'utf8'));
    return {
      refreshToken: raw.refreshToken ? decrypt(raw.refreshToken) : null,
      accessToken: raw.accessToken ? decrypt(raw.accessToken) : null,
      expiresAt: raw.expiresAt,
      clientId: raw.clientId || DEFAULT_CLIENT_ID,
      lastUpdated: raw.lastUpdated,
    };
  } catch (err) {
    console.error('Failed to read tokens:', err.message);
    return null;
  }
}

function writeTokens(tokens) {
  ensureDataDir();
  const encrypted = {
    refreshToken: tokens.refreshToken ? encrypt(tokens.refreshToken) : null,
    accessToken: tokens.accessToken ? encrypt(tokens.accessToken) : null,
    expiresAt: tokens.expiresAt,
    clientId: tokens.clientId || DEFAULT_CLIENT_ID,
    lastUpdated: new Date().toISOString(),
  };
  fs.writeFileSync(TOKENS_PATH, JSON.stringify(encrypted, null, 2), { mode: 0o600 });
}

function readConfig() {
  if (!fs.existsSync(CONFIG_PATH)) {
    return { pollIntervalMs: DEFAULT_POLL_INTERVAL_MS, clientId: DEFAULT_CLIENT_ID };
  }
  try {
    return JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
  } catch {
    return { pollIntervalMs: DEFAULT_POLL_INTERVAL_MS, clientId: DEFAULT_CLIENT_ID };
  }
}

function writeConfig(config) {
  ensureDataDir();
  fs.writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2));
}

// ---------------------------------------------------------------------------
// PKCE helpers
// ---------------------------------------------------------------------------

function base64urlEncode(buffer) {
  return buffer.toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');
}

function generatePKCE() {
  const verifier = base64urlEncode(crypto.randomBytes(32));
  const challenge = base64urlEncode(
    crypto.createHash('sha256').update(verifier).digest()
  );
  return { verifier, challenge };
}

// Pending OAuth session (only one at a time)
let pendingOAuth = null;

function handleOAuthStart() {
  const clientId = readConfig().clientId || DEFAULT_CLIENT_ID;
  const pkce = generatePKCE();
  const state = crypto.randomBytes(16).toString('hex');

  pendingOAuth = { verifier: pkce.verifier, state, createdAt: Date.now() };

  const params = new URLSearchParams({
    code: 'true',
    client_id: clientId,
    response_type: 'code',
    redirect_uri: OAUTH_REDIRECT_URI,
    scope: OAUTH_SCOPES,
    code_challenge: pkce.challenge,
    code_challenge_method: 'S256',
    state,
  });

  const authorizeUrl = `https://claude.ai/login?selectAccount=true&returnTo=${encodeURIComponent('/oauth/authorize?' + params.toString())}`;

  return { authorizeUrl };
}

async function handleOAuthCallback(body) {
  const { code } = body;

  if (!code) {
    return { status: 400, body: { error: 'code is required' } };
  }

  if (!pendingOAuth) {
    return { status: 400, body: { error: 'No pending OAuth session. Click "Authorize" first.' } };
  }

  // Expire after 10 minutes
  if (Date.now() - pendingOAuth.createdAt > 10 * 60 * 1000) {
    pendingOAuth = null;
    return { status: 400, body: { error: 'OAuth session expired. Click "Authorize" again.' } };
  }

  const { verifier } = pendingOAuth;
  const clientId = readConfig().clientId || DEFAULT_CLIENT_ID;

  // The code from Anthropic's callback page comes as "code#state"
  const parts = code.split('#');
  const actualCode = parts[0];
  const state = parts[1] || '';

  try {
    const response = await fetch('https://console.anthropic.com/v1/oauth/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        code: actualCode,
        state,
        grant_type: 'authorization_code',
        client_id: clientId,
        redirect_uri: OAUTH_REDIRECT_URI,
        code_verifier: verifier,
      }),
    });

    if (!response.ok) {
      let errorMsg = response.statusText;
      try {
        const err = await response.json();
        errorMsg = err.error_description || err.error || err.message || errorMsg;
      } catch {}
      return { status: 400, body: { error: `Token exchange failed: ${response.status} ${errorMsg}` } };
    }

    const json = await response.json();
    pendingOAuth = null;

    const tokens = {
      refreshToken: json.refresh_token,
      accessToken: json.access_token,
      expiresAt: Date.now() + json.expires_in * 1000,
      clientId,
    };
    writeTokens(tokens);
    console.log('OAuth complete, access token expires at', new Date(tokens.expiresAt).toISOString());

    restartPolling();

    return {
      status: 200,
      body: { ok: true, message: 'Authorized successfully', expiresAt: tokens.expiresAt },
    };
  } catch (err) {
    return { status: 500, body: { error: `Token exchange error: ${err.message}` } };
  }
}

// ---------------------------------------------------------------------------
// Token refresh
// ---------------------------------------------------------------------------

let refreshing = false;

async function refreshAccessToken() {
  if (refreshing) return null;
  refreshing = true;

  try {
    const tokens = readTokens();
    if (!tokens || !tokens.refreshToken) {
      console.error('No refresh token available');
      return null;
    }

    const clientId = tokens.clientId || readConfig().clientId || DEFAULT_CLIENT_ID;

    console.log('Refreshing access token...');
    const response = await fetch('https://console.anthropic.com/v1/oauth/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        grant_type: 'refresh_token',
        refresh_token: tokens.refreshToken,
        client_id: clientId,
      }),
    });

    if (!response.ok) {
      let errorMsg = response.statusText;
      try {
        const err = await response.json();
        errorMsg = err.error_description || err.error || err.message || errorMsg;
      } catch {}
      console.error(`Token refresh failed: ${response.status} ${errorMsg}`);
      return null;
    }

    const json = await response.json();
    const newRefreshToken = json.refresh_token || tokens.refreshToken;

    if (!json.refresh_token) {
      console.warn('Server did not return a new refresh_token - keeping previous one');
    }

    const updated = {
      refreshToken: newRefreshToken,
      accessToken: json.access_token,
      expiresAt: Date.now() + json.expires_in * 1000,
      clientId,
    };
    writeTokens(updated);
    console.log('Access token refreshed, expires at', new Date(updated.expiresAt).toISOString());
    return updated;
  } catch (err) {
    console.error('Token refresh error:', err.message);
    return null;
  } finally {
    refreshing = false;
  }
}

async function ensureValidToken() {
  const tokens = readTokens();
  if (!tokens || !tokens.accessToken) return null;

  if (tokens.expiresAt && tokens.expiresAt - Date.now() < TOKEN_REFRESH_BUFFER_MS) {
    console.log('Token expiring soon, proactively refreshing...');
    const refreshed = await refreshAccessToken();
    return refreshed || tokens;
  }

  return tokens;
}

// ---------------------------------------------------------------------------
// Usage polling
// ---------------------------------------------------------------------------

let cachedUsage = null;
let lastFetchAt = null;
let pollTimer = null;
let consecutiveRateLimits = 0;
const BACKOFF_INTERVALS_MS = [10 * 60 * 1000, 15 * 60 * 1000, 20 * 60 * 1000]; // 10m, 15m, 20m

async function callUsageApi(accessToken) {
  const response = await fetch('https://api.anthropic.com/api/oauth/usage', {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'anthropic-beta': 'oauth-2025-04-20',
      Accept: 'application/json',
    },
  });
  return response;
}

async function fetchUsage() {
  const tokens = await ensureValidToken();
  if (!tokens || !tokens.accessToken) {
    console.warn('No valid access token, skipping usage fetch');
    return;
  }

  try {
    let response = await callUsageApi(tokens.accessToken);

    // Per-token rate limit workaround: refresh token to get a fresh rate limit window
    if (response.status === 429) {
      console.log('Got 429 - refreshing token for fresh rate limit window...');
      const refreshed = await refreshAccessToken();
      if (refreshed && refreshed.accessToken) {
        response = await callUsageApi(refreshed.accessToken);
      }
    }

    if (!response.ok) {
      const errText = await response.text().catch(() => '');
      console.error(`Usage fetch failed: ${response.status} ${response.statusText}`, errText);

      if (response.status === 401) {
        console.log('Got 401 - will refresh token for next poll');
        await refreshAccessToken();
      }

      if (response.status === 429) {
        consecutiveRateLimits++;
        const backoffIdx = Math.min(consecutiveRateLimits - 1, BACKOFF_INTERVALS_MS.length - 1);
        const backoffMs = BACKOFF_INTERVALS_MS[backoffIdx];
        console.log(`Rate limited (${consecutiveRateLimits}x) even after token refresh, backing off to ${backoffMs / 60000}m`);
        restartPollingWithInterval(backoffMs);
      }
      return;
    }

    if (consecutiveRateLimits > 0) {
      console.log(`Rate limit cleared after ${consecutiveRateLimits} consecutive 429s, resuming normal polling`);
      consecutiveRateLimits = 0;
      restartPollingWithInterval(null);
    }

    cachedUsage = await response.json();
    lastFetchAt = new Date().toISOString();
    console.log('Usage data fetched at', lastFetchAt);
  } catch (err) {
    console.error('Usage fetch error:', err.message);
  }
}

function getMaxUtilization(usage) {
  if (!usage) return null;

  const utilizations = [];
  for (const [key, value] of Object.entries(usage)) {
    if (value && typeof value === 'object' && 'utilization' in value && typeof value.utilization === 'number') {
      utilizations.push(value.utilization);
    }
    if (key === 'extra_usage' && value && typeof value === 'object' && 'utilization' in value && typeof value.utilization === 'number') {
      utilizations.push(value.utilization);
    }
  }
  return utilizations.length > 0 ? Math.max(...utilizations) : 0;
}

function getLimitingWindow(usage) {
  if (!usage) return null;

  let maxUtil = -1;
  let windowName = null;
  for (const [key, value] of Object.entries(usage)) {
    if (value && typeof value === 'object' && 'utilization' in value && typeof value.utilization === 'number') {
      if (value.utilization > maxUtil) {
        maxUtil = value.utilization;
        windowName = key;
      }
    }
  }
  return windowName;
}

function startPolling() {
  if (pollTimer) clearInterval(pollTimer);
  const config = readConfig();
  const interval = config.pollIntervalMs || DEFAULT_POLL_INTERVAL_MS;

  fetchUsage();

  pollTimer = setInterval(fetchUsage, interval);
  console.log(`Polling every ${interval / 1000}s`);
}

function restartPollingWithInterval(overrideMs) {
  if (pollTimer) clearInterval(pollTimer);
  const config = readConfig();
  const interval = overrideMs || config.pollIntervalMs || DEFAULT_POLL_INTERVAL_MS;
  pollTimer = setInterval(fetchUsage, interval);
  console.log(`Polling every ${interval / 1000}s`);
}

function restartPolling() {
  startPolling();
}

// ---------------------------------------------------------------------------
// OpenAI / Codex usage polling
// ---------------------------------------------------------------------------
//
// ChatGPT's usage backend (chatgpt.com/backend-api/codex/usage) sits behind a
// Cloudflare bot challenge that a plain HTTP client can't pass. The Codex CLI
// itself can, so we shell out to its local app-server (JSON-RPC over stdio)
// and ask it for the same rate-limit snapshot it shows in its own status line.

const CODEX_EXTRA_PATH_DIRS = ['/opt/homebrew/bin', '/usr/local/bin'];

function resolveCodexEnv() {
  const extra = CODEX_EXTRA_PATH_DIRS.filter((dir) => fs.existsSync(dir));
  const currentPath = process.env.PATH || '';
  const pathParts = new Set(currentPath.split(path.delimiter).filter(Boolean));
  for (const dir of extra) pathParts.add(dir);
  return { ...process.env, PATH: [...pathParts].join(path.delimiter) };
}

function callCodexAppServer() {
  return new Promise((resolve, reject) => {
    let proc;
    try {
      proc = spawn(process.env.CODEX_BIN || 'codex', ['app-server'], {
        stdio: ['pipe', 'pipe', 'pipe'],
        env: resolveCodexEnv(),
      });
    } catch (err) {
      reject(err);
      return;
    }

    let buffer = '';
    let settled = false;
    let stderr = '';

    const finish = (fn, arg) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      proc.kill();
      fn(arg);
    };

    const timer = setTimeout(() => {
      finish(reject, new Error('codex app-server timed out'));
    }, 10000);

    proc.stdout.on('data', (chunk) => {
      buffer += chunk.toString();
      let idx;
      while ((idx = buffer.indexOf('\n')) !== -1) {
        const line = buffer.slice(0, idx);
        buffer = buffer.slice(idx + 1);
        if (!line.trim()) continue;
        let msg;
        try {
          msg = JSON.parse(line);
        } catch {
          continue;
        }
        if (msg.id === 2) {
          if (msg.error) {
            finish(reject, new Error(msg.error.message || 'codex rate-limit read failed'));
          } else {
            finish(resolve, msg.result);
          }
        }
      }
    });

    proc.stderr.on('data', (chunk) => {
      stderr += chunk.toString();
    });

    proc.on('error', (err) => {
      finish(reject, err.code === 'ENOENT' ? new Error('codex CLI not found') : err);
    });

    proc.on('exit', (code) => {
      finish(reject, new Error(`codex app-server exited with code ${code}: ${stderr.trim()}`));
    });

    const send = (obj) => proc.stdin.write(JSON.stringify(obj) + '\n');
    send({
      id: 1,
      method: 'initialize',
      params: { clientInfo: { name: 'claude-usage-api', title: 'claude-usage-api', version: '1.0.0' } },
    });
    send({ id: 2, method: 'account/rateLimits/read', params: null });
  });
}

let cachedCodexUsage = null;
let codexLastFetchAt = null;
let codexError = null;
let codexPollTimer = null;

async function fetchCodexUsage() {
  try {
    const result = await callCodexAppServer();
    cachedCodexUsage = result;
    codexLastFetchAt = new Date().toISOString();
    codexError = null;
  } catch (err) {
    codexError = err.message;
    console.error('Codex usage fetch error:', err.message);
  }
}

function startCodexPolling() {
  if (codexPollTimer) clearInterval(codexPollTimer);
  const config = readConfig();
  const interval = config.pollIntervalMs || DEFAULT_POLL_INTERVAL_MS;
  fetchCodexUsage();
  codexPollTimer = setInterval(fetchCodexUsage, interval);
}

function handleOpenaiUsage() {
  return {
    data: cachedCodexUsage,
    fetchedAt: codexLastFetchAt,
    ageMs: codexLastFetchAt ? Date.now() - new Date(codexLastFetchAt).getTime() : null,
    error: codexError,
  };
}

// ---------------------------------------------------------------------------
// Request body parser
// ---------------------------------------------------------------------------

function parseBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (chunk) => chunks.push(chunk));
    req.on('end', () => {
      try {
        const body = Buffer.concat(chunks).toString();
        resolve(body ? JSON.parse(body) : {});
      } catch (err) {
        reject(err);
      }
    });
    req.on('error', reject);
  });
}

// ---------------------------------------------------------------------------
// Route handlers
// ---------------------------------------------------------------------------

function handleHealth() {
  const tokens = readTokens();
  const tokenHealth = !tokens ? 'not_configured'
    : (tokens.expiresAt && tokens.expiresAt > Date.now()) ? 'valid'
    : tokens.accessToken ? 'expired'
    : 'not_configured';

  return {
    ok: true,
    service: 'claude-usage',
    tokenConfigured: !!(tokens?.refreshToken || tokens?.accessToken),
    tokenValid: tokenHealth === 'valid',
    lastFetch: lastFetchAt,
    uptime: Math.floor((Date.now() - startTime) / 1000),
  };
}

function handleStatus() {
  const tokens = readTokens();
  const hasToken = tokens?.refreshToken || tokens?.accessToken;
  const tokenHealth = !hasToken ? 'not_configured'
    : (tokens.expiresAt && tokens.expiresAt > Date.now()) ? 'valid'
    : 'expired';

  if (!cachedUsage) {
    return {
      remaining: null,
      maxUtilization: null,
      limitingWindow: null,
      resetsAt: null,
      resetsInMinutes: null,
      tokenHealth,
      fetchedAt: lastFetchAt,
    };
  }

  const maxUtil = getMaxUtilization(cachedUsage);
  const remaining = maxUtil !== null ? Math.round(maxUtil) : null;
  const limitingWindow = getLimitingWindow(cachedUsage);

  let resetsAt = null;
  let resetsInMinutes = null;
  if (cachedUsage.five_hour && cachedUsage.five_hour.resets_at) {
    resetsAt = cachedUsage.five_hour.resets_at;
    resetsInMinutes = Math.max(0, Math.round((new Date(resetsAt).getTime() - Date.now()) / 60000));
  }

  return {
    remaining,
    maxUtilization: maxUtil !== null ? Math.round(maxUtil) : null,
    limitingWindow,
    resetsAt,
    resetsInMinutes,
    tokenHealth,
    fetchedAt: lastFetchAt,
  };
}

function handleUsage() {
  if (!cachedUsage) {
    return { data: null, fetchedAt: null, ageMs: null };
  }
  return {
    data: cachedUsage,
    fetchedAt: lastFetchAt,
    ageMs: Date.now() - new Date(lastFetchAt).getTime(),
  };
}

function handleGetConfig() {
  return readConfig();
}

function handlePutConfig(body) {
  const config = readConfig();
  const { pollIntervalMs, clientId } = body;

  if (pollIntervalMs !== undefined) {
    const ms = Number(pollIntervalMs);
    if (ms < 60000 || ms > 300000) {
      return { status: 400, body: { error: 'pollIntervalMs must be between 60000 (1 min) and 300000 (5 min)' } };
    }
    config.pollIntervalMs = ms;
  }

  if (clientId !== undefined) {
    config.clientId = clientId;
  }

  writeConfig(config);

  if (pollIntervalMs !== undefined) {
    restartPolling();
    startCodexPolling();
  }

  return { status: 200, body: config };
}

function serveIndexHtml(res) {
  const htmlPath = path.join(__dirname, 'index.html');
  try {
    const html = fs.readFileSync(htmlPath, 'utf8');
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(html);
  } catch {
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'index.html not found' }));
  }
}

// ---------------------------------------------------------------------------
// HTTP Server
// ---------------------------------------------------------------------------

function sendJson(res, statusCode, data) {
  res.writeHead(statusCode, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(data));
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const { pathname } = url;
  const method = req.method;

  // CORS headers for the HTML page
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  try {
    // Serve index.html at root
    if (pathname === '/' && method === 'GET') {
      serveIndexHtml(res);
      return;
    }

    if (pathname === '/health' && method === 'GET') {
      sendJson(res, 200, handleHealth());
      return;
    }

    if (pathname === '/api/status' && method === 'GET') {
      sendJson(res, 200, handleStatus());
      return;
    }

    if (pathname === '/api/usage' && method === 'GET') {
      sendJson(res, 200, handleUsage());
      return;
    }

    if (pathname === '/api/openai/usage' && method === 'GET') {
      sendJson(res, 200, handleOpenaiUsage());
      return;
    }

    if (pathname === '/api/oauth/start' && method === 'POST') {
      sendJson(res, 200, handleOAuthStart());
      return;
    }

    if (pathname === '/api/oauth/callback' && method === 'POST') {
      const body = await parseBody(req);
      const result = await handleOAuthCallback(body);
      sendJson(res, result.status, result.body);
      return;
    }

    if (pathname === '/api/config' && method === 'GET') {
      sendJson(res, 200, handleGetConfig());
      return;
    }

    if (pathname === '/api/config' && method === 'PUT') {
      const body = await parseBody(req);
      const result = handlePutConfig(body);
      sendJson(res, result.status, result.body);
      return;
    }

    sendJson(res, 404, { error: 'not found' });
  } catch (err) {
    console.error(`Error handling ${method} ${pathname}:`, err.message);
    sendJson(res, 500, { error: 'internal error' });
  }
});

// ---------------------------------------------------------------------------
// Startup
// ---------------------------------------------------------------------------

server.listen(PORT, BIND, () => {
  console.log(`claude-usage-api listening on ${BIND}:${PORT}`);
  console.log(`Data dir: ${DATA_DIR}`);

  ensureDataDir();

  const tokens = readTokens();
  if (tokens && tokens.refreshToken) {
    console.log('Token found, starting usage polling...');
    startPolling();
  } else {
    console.log('No token configured. Visit http://localhost:' + PORT + ' to authorize.');
  }

  console.log('Starting Codex (OpenAI) usage polling...');
  startCodexPolling();
});
