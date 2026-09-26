# StudyBuddy 📖

A tiny macOS menu bar widget that helps you stay accountable while studying.
Click the book icon, hit **Start Studying**, and your session gets timed. Stop
whenever you're done and your time gets logged to a shared leaderboard so you
can compare study time with friends — overall, or head-to-head.

## Features

- Lives in the menu bar (book icon) — no dock icon, no clutter
- One click to start/stop a study session, with a live timer
- Shared leaderboard (today / this week / all time) across everyone using the app
- Head-to-head comparison against any other username
- Session survives an accidental relaunch (resumes an in-progress session)

## Get it

Grab `StudyBuddy.app.zip` from the [latest release](../../releases/latest),
unzip it, and drag `StudyBuddy.app` to `/Applications`. Double-click to open —
it's signed and notarized by Apple, so there's no security warning to click
through.

Pick a username the first time it opens. That's it — click the book icon any
time you sit down to study.

## How it works

- `mac-app/` — the SwiftUI menu bar app (`MenuBarExtra`). No Xcode project
  needed; it's a plain Swift Package.
- `backend/` — a small Express + SQLite API that stores usernames, sessions,
  and serves the leaderboard/compare endpoints. Deployed on Fly.io at
  `https://studybuddy-api-lb.fly.dev`.

Everyone who downloads the app talks to the same backend, which is what makes
the leaderboard and one-on-one comparisons work across different people's
computers.

## Building from source

### Mac app

Requires Xcode Command Line Tools (macOS 13+).

```bash
cd mac-app
./build_app.sh
open StudyBuddy.app
```

To point the app at a different backend (e.g. one running locally), set
`STUDYBUDDY_API_URL` before launching:

```bash
STUDYBUDDY_API_URL=http://localhost:8080 open StudyBuddy.app
```

### Backend

```bash
cd backend
npm install
npm start          # listens on :8080, stores data/studybuddy.db
```

Deploy your own copy to Fly.io:

```bash
cd backend
fly launch          # or fly deploy if the app + volume already exist
```

## API

| Endpoint | Method | Description |
|---|---|---|
| `/api/register` | POST | `{ username }` → `{ username, token }` |
| `/api/sessions` | POST | `{ username, token, durationSeconds }` → logs a session |
| `/api/leaderboard?period=today\|week\|all` | GET | ranked list of everyone's totals |
| `/api/compare?a=user1&b=user2&period=...` | GET | head-to-head totals |

No email, password, or personal info required — just a username and a token
generated at registration, stored locally in the app.

## License

MIT
