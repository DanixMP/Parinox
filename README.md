# Parinox

Team app for ~10–20 users: chat, calls (LiveKit), Explore posts, and Stories.

Source of truth: [`DESIGN (5).md`](./DESIGN%20(5).md).

## Phase 1 status

Implemented and tested:

- FastAPI backend with SQLite (WAL), JWT auth, rooms/DMs, REST history, WebSocket resync (`last_id`)
- Image upload pipeline (Pillow re-encode / EXIF strip)
- Admin user creation (`POST /admin/users` + CLI)
- Explore / Stories / LiveKit token endpoints (API ready; client polish in later phases)
- Flutter client scaffold: login, room list, chat with reconnect + sqflite `last_id` cache

## Quick start (backend)

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # set JWT_SECRET and ADMIN_TOKEN
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Create users:

```bash
# CLI
python scripts/create_user.py alice 'secret' 'Alice'

# or HTTP
curl -X POST http://127.0.0.1:8000/admin/users \
  -H 'Content-Type: application/json' \
  -H 'X-Admin-Token: change-me-admin-token' \
  -d '{"username":"alice","password":"secret","display_name":"Alice"}'
```

Login:

```bash
curl -X POST http://127.0.0.1:8000/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"alice","password":"secret"}'
```

Tests:

```bash
cd backend && python -m pytest tests/ -v
```

## Flutter client

```bash
cd client
flutter pub get
flutter run --dart-define=API_BASE=http://YOUR_HOST:8000
```

Set `API_BASE` to your FastAPI origin (no trailing slash). WebSocket URLs are derived from it (`ws`/`wss` + `/ws/{room_id}`).

## Deploy notes

- `deploy/nginx.conf.example` — TLS, `/api/`, `/ws/`, `/media/`
- `docker-compose.yml` + `deploy/livekit.yaml` — LiveKit for Phase 2 (force TURN/TLS on 443 in production)

## Build phases (from design)

1. **Core chat** ← this PR
2. Calls (LiveKit + TURN/TLS)
3. Profiles polish
4. Explore / posts masonry
5. Stories strip + viewer + expiry
