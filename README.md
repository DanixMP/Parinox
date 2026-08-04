# Team App (Parinox)

Private team app for ~10–20 users: chat, calls, explore, stories, profiles.

**Source of truth:** [`DESIGN (5).md`](./DESIGN%20(5).md)

## Build phases

| Phase | Status | Scope |
|------|--------|--------|
| 1. Core chat | Done | Schema, JWT, WS resync, Flutter chat + local cache |
| 2. Calls | **In progress** | LiveKit token (membership-gated), call screen, chat entry points |
| 3. Profiles | Partial API | `/me`, avatar upload, profile screens |
| 4. Explore/Posts | API ready | Masonry feed, likes, comments |
| 5. Stories | API ready | 24h expiry scheduler, strip + viewer |

## Quick start (backend)

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # edit JWT_SECRET + ADMIN_TOKEN
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Create users (no public signup):

```bash
# CLI
python scripts/create_user.py alice 'securepass' 'Alice'

# or HTTP with admin token
curl -X POST http://127.0.0.1:8000/admin/users \
  -H "X-Admin-Token: $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"securepass","display_name":"Alice"}'
```

Login:

```bash
curl -X POST http://127.0.0.1:8000/login \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"securepass"}'
```

## Flutter client

```bash
cd flutter_app
flutter pub get
flutter run --dart-define=API_BASE=http://127.0.0.1:8000
```

Phase 1 screens: login → room list → chat with WebSocket reconnect, `last_id` persistence (sqflite), and outbound queue while offline.

## Chat reliability (the important bit)

On every WS connect the client sends `last_id` (persisted locally). The server replays `messages WHERE room_id=? AND id>?` before accepting live traffic. See DESIGN §5.

## Tests

```bash
cd backend
pip install -r requirements.txt
pytest -q
```

## Deploy sketch

- `deploy/docker-compose.yml` — API + LiveKit
- `deploy/nginx.conf` — TLS, `/ws/` upgrade, `/media/` static
- `deploy/livekit.yaml` — TURN TLS on 443 for restricted networks

Point `yourhost.ir` / `turn.yourhost.ir` at the VPS (or `rose` home server) with the stabler uplink before relying on LiveKit.
