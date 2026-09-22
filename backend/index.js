const express = require('express');
const cors = require('cors');
const crypto = require('crypto');
const path = require('path');
const Database = require('better-sqlite3');

const DATA_DIR = process.env.DATA_DIR || __dirname;
const db = new Database(path.join(DATA_DIR, 'studybuddy.db'));
db.pragma('journal_mode = WAL');

db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    username TEXT PRIMARY KEY,
    token TEXT NOT NULL,
    created_at INTEGER NOT NULL
  );
  CREATE TABLE IF NOT EXISTS sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL,
    duration_seconds INTEGER NOT NULL,
    started_at INTEGER NOT NULL,
    ended_at INTEGER NOT NULL,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (username) REFERENCES users(username)
  );
  CREATE INDEX IF NOT EXISTS idx_sessions_username ON sessions(username);
  CREATE INDEX IF NOT EXISTS idx_sessions_ended_at ON sessions(ended_at);
`);

const app = express();
app.use(cors());
app.use(express.json());

const USERNAME_RE = /^[a-zA-Z0-9_]{3,20}$/;
const MAX_SESSION_SECONDS = 60 * 60 * 12; // 12 hours, sanity cap

function periodCutoff(period) {
  const now = Date.now();
  if (period === 'today') {
    const d = new Date();
    d.setHours(0, 0, 0, 0);
    return d.getTime();
  }
  if (period === 'week') {
    return now - 7 * 24 * 60 * 60 * 1000;
  }
  return 0; // all time
}

function leaderboardRows(period) {
  const cutoff = periodCutoff(period);
  return db
    .prepare(
      `SELECT username,
              COALESCE(SUM(duration_seconds), 0) AS totalSeconds,
              COUNT(*) AS sessionCount
       FROM sessions
       WHERE ended_at >= ?
       GROUP BY username
       ORDER BY totalSeconds DESC`
    )
    .all(cutoff);
}

app.get('/', (req, res) => {
  res.json({ ok: true, service: 'studybuddy-api' });
});

// Register a new username, returns a token the client must present to log sessions.
app.post('/api/register', (req, res) => {
  const username = String(req.body?.username || '').trim();
  if (!USERNAME_RE.test(username)) {
    return res.status(400).json({
      error: 'username must be 3-20 characters, letters/numbers/underscore only',
    });
  }
  const existing = db.prepare('SELECT username FROM users WHERE username = ?').get(username);
  if (existing) {
    return res.status(409).json({ error: 'username already taken' });
  }
  const token = crypto.randomBytes(24).toString('hex');
  db.prepare('INSERT INTO users (username, token, created_at) VALUES (?, ?, ?)').run(
    username,
    token,
    Date.now()
  );
  res.json({ username, token });
});

// Check whether a username exists (used by the compare picker).
app.get('/api/users/:username', (req, res) => {
  const user = db
    .prepare('SELECT username, created_at FROM users WHERE username = ?')
    .get(req.params.username);
  if (!user) return res.status(404).json({ error: 'not found' });
  res.json(user);
});

// Log a completed study session. Requires the token returned at registration.
app.post('/api/sessions', (req, res) => {
  const { username, token, durationSeconds, startedAt, endedAt } = req.body || {};
  if (!username || !token) {
    return res.status(400).json({ error: 'username and token are required' });
  }
  const user = db.prepare('SELECT token FROM users WHERE username = ?').get(username);
  if (!user || user.token !== token) {
    return res.status(401).json({ error: 'invalid username or token' });
  }
  const duration = Math.floor(Number(durationSeconds));
  if (!Number.isFinite(duration) || duration <= 0 || duration > MAX_SESSION_SECONDS) {
    return res.status(400).json({ error: 'durationSeconds must be a positive number under 12 hours' });
  }
  const now = Date.now();
  const started = Number(startedAt) || now - duration * 1000;
  const ended = Number(endedAt) || now;

  db.prepare(
    `INSERT INTO sessions (username, duration_seconds, started_at, ended_at, created_at)
     VALUES (?, ?, ?, ?, ?)`
  ).run(username, duration, started, ended, now);

  const totals = db
    .prepare(
      `SELECT COALESCE(SUM(duration_seconds), 0) AS totalSeconds, COUNT(*) AS sessionCount
       FROM sessions WHERE username = ?`
    )
    .get(username);

  res.json({ ok: true, totals });
});

// Leaderboard: ?period=all|today|week
app.get('/api/leaderboard', (req, res) => {
  const period = ['today', 'week', 'all'].includes(req.query.period) ? req.query.period : 'all';
  const rows = leaderboardRows(period).map((row, i) => ({ rank: i + 1, ...row }));
  res.json({ period, leaderboard: rows });
});

// Head-to-head comparison between two users: ?a=alice&b=bob&period=all|today|week
app.get('/api/compare', (req, res) => {
  const a = String(req.query.a || '').trim();
  const b = String(req.query.b || '').trim();
  if (!a || !b) return res.status(400).json({ error: 'query params a and b are required' });
  const period = ['today', 'week', 'all'].includes(req.query.period) ? req.query.period : 'all';
  const cutoff = periodCutoff(period);

  const totalsFor = (username) =>
    db
      .prepare(
        `SELECT COALESCE(SUM(duration_seconds), 0) AS totalSeconds, COUNT(*) AS sessionCount
         FROM sessions WHERE username = ? AND ended_at >= ?`
      )
      .get(username, cutoff);

  res.json({
    period,
    a: { username: a, ...totalsFor(a) },
    b: { username: b, ...totalsFor(b) },
  });
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
  console.log(`studybuddy-api listening on :${PORT}`);
});
