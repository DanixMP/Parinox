# Imagine Just Pulling 25k Code and spend 8h to just review 💀...
# I will change the Readme soon.. Just wait.
# Team App (Parinox)

Private team app for ~10–20 users: chat, calls, explore, stories, profiles.

**Source of truth:** [`DESIGN (5).md`](./DESIGN%20(5).md)

## Build phases

| Phase | Status | Scope |
|------|--------|--------|
| 1. Core chat | Done | Schema, JWT, WS resync, Flutter chat + local cache |
| 2. Calls | Done | LiveKit token (membership-gated), call screen, chat entry points |
| 3. Profiles | Done | `/me`, avatar, public profile + posts grid, Flutter profile UI |
| 4. Explore/Posts | Done | Masonry feed, create post, likes, comments, pagination |
| 5. Stories | **Done** | 24h expiry, strip on Explore, tap-through viewer |

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

Phase 2: voice/video buttons in the chat app bar open `CallScreen`, which mints a LiveKit token via `POST /livekit/token` for `room_{chatRoomId}`. See `flutter_app/PLATFORM_PERMISSIONS.md` for camera/mic manifests after `flutter create .`.

Phase 3: bottom nav **Profile** tab — avatar, display name, bio, own-posts grid, edit screen (gallery avatar upload). Tap a sender name in chat to open their public profile (`GET /users/{id}` returns profile + posts).

Phase 4: **Explore** tab — Pinterest-style masonry grid sized from stored `width`/`height`, infinite scroll via `before_id`, create post, likes, and comments on post detail.

Phase 5: Stories strip atop Explore (unseen ring), create story (photo/video), fullscreen tap-through viewer with progress bars + auto-advance, 24h expiry job.

## Calls (LiveKit)

```bash
# From deploy/ — start LiveKit (host networking for TURN/TLS)
docker compose up livekit
```

1. Set `LIVEKIT_API_KEY` / `LIVEKIT_API_SECRET` / `LIVEKIT_WS_URL` in `backend/.env` to match `deploy/livekit.yaml`.
2. Point `turn.yourhost.ir` DNS + certbot certs; uncomment `cert_file` / `key_file` in `livekit.yaml`.
3. Prefer TURN TLS on 443 — plain UDP fails on many restricted networks (DESIGN §6).

Room names: `room_{id}` (chat-tied) or `dm_{min}_{max}` (1:1). Token minting checks membership before issuing.

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
