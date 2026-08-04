# Team App — DESIGN.md

Source of truth for an AI coding agent building this system. Team size: 10 users, headroom for 20. Optimize for simplicity, low maintenance, and reliability over unreliable networks — never for scale.

---

## 1. Product Scope

Four features, one backend, one Flutter client:

1. **Chat** — rooms/DMs, text + images, WebSocket live, reconnect-safe.
2. **Calls** — voice/video via self-hosted LiveKit, token-gated by app auth.
3. **Explore** — Pinterest-style masonry feed of posts (image + caption), likes, comments.
4. **Stories** — 24h-expiring media strip at the top of Explore, seen/unseen tracking.
5. **Profiles** — avatar, display name, bio, own-posts grid, settings.

Non-goals: public signup, horizontal scaling, push notification infra beyond simple polling/WS, content moderation pipelines, multi-tenant anything.

---

## 2. Stack

| Layer | Choice | Why |
|---|---|---|
| Backend | FastAPI (Python) | async, native WebSocket support, fast to build |
| DB | SQLite, WAL mode | single file, atomic writes, zero ops, plenty for 20 users |
| Realtime | Native WebSocket (`/ws`) | bidirectional, needed for typing/presence, pairs with resync protocol |
| Calls | LiveKit OSS, self-hosted (docker-compose) | free, full control, TURN/TLS for restricted networks |
| Media storage | Local disk, served by nginx | no object storage needed at this scale |
| Client | Flutter (Riverpod, sqflite local cache) | one codebase, team already fluent in it |
| Auth | JWT, issued by FastAPI, shared across WS + REST + LiveKit token minting | one identity, one login |
| Reverse proxy / TLS | nginx + certbot | standard, cheap to maintain |

Deploy target: one VPS or `rose` home server (whichever has the more stable/lower-jitter uplink — test both before deciding, this matters more for LiveKit than chat).

---

## 3. Database Schema (SQLite, WAL)

```sql
PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

-- ===== Identity =====
CREATE TABLE users (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    username      TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    display_name  TEXT NOT NULL,
    bio           TEXT DEFAULT '',
    avatar_path   TEXT,
    created_at    TEXT DEFAULT (datetime('now'))
);

-- ===== Chat =====
CREATE TABLE rooms (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    name       TEXT NOT NULL,
    is_dm      INTEGER DEFAULT 0,        -- 1 = 1:1 DM room
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE room_members (
    room_id INTEGER REFERENCES rooms(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    PRIMARY KEY (room_id, user_id)
);

CREATE TABLE messages (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,   -- global cursor for resync
    room_id    INTEGER REFERENCES rooms(id) ON DELETE CASCADE,
    sender_id  INTEGER REFERENCES users(id),
    content    TEXT,
    image_path TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);
CREATE INDEX idx_messages_room_id ON messages(room_id, id);

-- ===== Explore / Posts (Pinterest-style) =====
CREATE TABLE posts (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id    INTEGER REFERENCES users(id) ON DELETE CASCADE,
    caption    TEXT DEFAULT '',
    image_path TEXT NOT NULL,
    width      INTEGER NOT NULL,   -- stored at upload time, drives masonry layout client-side
    height     INTEGER NOT NULL,
    created_at TEXT DEFAULT (datetime('now'))
);
CREATE INDEX idx_posts_created_at ON posts(created_at DESC);

CREATE TABLE post_likes (
    post_id INTEGER REFERENCES posts(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    PRIMARY KEY (post_id, user_id)
);

CREATE TABLE post_comments (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    post_id    INTEGER REFERENCES posts(id) ON DELETE CASCADE,
    user_id    INTEGER REFERENCES users(id),
    content    TEXT NOT NULL,
    created_at TEXT DEFAULT (datetime('now'))
);

-- ===== Stories =====
CREATE TABLE stories (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id    INTEGER REFERENCES users(id) ON DELETE CASCADE,
    media_path TEXT NOT NULL,
    is_video   INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now')),
    expires_at TEXT NOT NULL          -- created_at + 24h, computed at insert
);
CREATE INDEX idx_stories_expires ON stories(expires_at);

CREATE TABLE story_views (
    story_id INTEGER REFERENCES stories(id) ON DELETE CASCADE,
    user_id  INTEGER REFERENCES users(id) ON DELETE CASCADE,
    viewed_at TEXT DEFAULT (datetime('now')),
    PRIMARY KEY (story_id, user_id)
);
```

**Notes**
- `messages.id` and story/post ids are the resync cursors — this is the entire reliability mechanism, don't replace with UUIDs.
- No `follows` table: with 10-20 people, Explore shows everyone's posts and Stories shows everyone's stories. Don't build a social graph nobody needs.
- Expired stories: a lightweight cron (APScheduler job in FastAPI, runs every 15 min) deletes rows where `expires_at < now()` and their media files. No message queue needed.

---

## 4. Backend Structure

```
backend/
├── main.py                 # app init, router mounting, CORS, startup tasks
├── db.py                   # SQLite connection (WAL), schema init
├── auth.py                 # JWT issue/verify, password hashing (bcrypt)
├── ws_manager.py            # ConnectionManager: dict[room_id, list[WebSocket]]
├── scheduler.py             # APScheduler: expire stories every 15 min
├── models.py                 # Pydantic schemas
├── routes/
│   ├── auth.py               # POST /login
│   ├── users.py               # GET/PATCH /me, GET /users/{id}, avatar upload
│   ├── chat.py                 # /rooms, /rooms/{id}/history, WS /ws/{room_id}
│   ├── posts.py                 # /posts (feed, create), /posts/{id}/like, /comments
│   ├── stories.py                 # /stories (active feed), POST /stories, /stories/{id}/view
│   ├── upload.py                   # shared image upload handler (posts/stories/avatars/chat)
│   └── livekit.py                   # POST /livekit/token
└── media/                             # uploaded files, served by nginx directly
    ├── avatars/
    ├── chat/
    ├── posts/
    └── stories/
```

### Key endpoints

```
POST   /login                       → {access_token}
GET    /me                          → current user profile
PATCH  /me                          → update display_name / bio / avatar
GET    /users/{id}                  → public profile + their posts

GET    /rooms                       → rooms current user is a member of
GET    /rooms/{id}/history?after=0  → REST fallback / initial load
WS     /ws/{room_id}?token=&last_id=  → live chat + resync (see §5)

GET    /posts?before_id=&limit=30   → paginated explore feed, newest first
POST   /posts                       → multipart: image + caption
POST   /posts/{id}/like             → toggle like
GET    /posts/{id}/comments
POST   /posts/{id}/comments

GET    /stories                     → active (non-expired) stories, grouped by user,
                                        each with viewed:boolean for current user
POST   /stories                     → multipart: media (image/short video)
POST   /stories/{id}/view           → mark viewed by current user

POST   /livekit/token               → {token} scoped to a room name
```

Image uploads: server re-encodes/strips EXIF on the way in (Pillow), enforces a max dimension (e.g. 2000px long edge) and max file size (e.g. 8MB) before writing to disk — keeps storage predictable without a CDN or resizing service.

---

## 5. Chat Reliability Protocol (the part that actually matters)

The old system's failure mode: connection drops, client has no way to know what it missed. Fix is a resync handshake on every connect, not a transport choice.

```python
@app.websocket("/ws/{room_id}")
async def ws_endpoint(ws: WebSocket, room_id: int, token: str, last_id: int = 0):
    user = verify_jwt(token)          # reject BEFORE accept if invalid
    await ws.accept()
    manager.connect(ws, room_id, user.id)

    # resync: replay everything the client missed since last_id
    missed = db.execute(
        "SELECT * FROM messages WHERE room_id=? AND id>? ORDER BY id",
        (room_id, last_id)
    ).fetchall()
    for m in missed:
        await ws.send_json(serialize(m))

    try:
        while True:
            data = await ws.receive_json()
            msg = db.insert_message(room_id, user.id, data)
            await manager.broadcast(room_id, serialize(msg))
    except WebSocketDisconnect:
        manager.disconnect(ws, room_id)
```

Client contract:
- Persist `last_message_id` locally (sqflite), not just in memory.
- On reconnect, always pass the persisted `last_id` — never trust the socket to have delivered everything while it was open, either.
- Exponential backoff on reconnect: 1s → 2s → 5s → 10s cap.
- Outgoing messages sent while disconnected queue locally and flush on reconnect (mark as "sending" in UI until server ack).

Same cursor pattern applies to Explore (`before_id` pagination) and Stories (expiry-driven, not cursor-driven, since it's a small always-fresh set).

---

## 6. LiveKit Integration

- Self-hosted via docker-compose, one node — comfortably handles 20 users across a few simultaneous rooms.
- **Force TURN over TLS on port 443.** Given team members are likely behind restrictive/throttled networks, plain UDP will be unreliable for some of them; TLS on 443 looks like normal HTTPS and traverses almost everything.
- Room naming: `dm_{user_a}_{user_b}` for 1:1 calls, `room_{room_id}` for group calls tied to a chat room.
- Token minting reuses the same JWT session as chat — no separate LiveKit login.

```python
@app.post("/livekit/token")
def get_token(user: User = Depends(verify_jwt), room: str = Body(...)):
    token = AccessToken(LIVEKIT_KEY, LIVEKIT_SECRET) \
        .with_identity(user.username) \
        .with_name(user.display_name) \
        .with_grants(VideoGrants(room_join=True, room=room))
    return {"token": token.to_jwt(), "url": LIVEKIT_WS_URL}
```

docker-compose sketch:
```yaml
services:
  livekit:
    image: livekit/livekit-server:latest
    command: --config /etc/livekit.yaml
    network_mode: host
    volumes:
      - ./livekit.yaml:/etc/livekit.yaml
```
`livekit.yaml` enables the built-in TURN server with `tls_port: 443` and a cert from the same certbot cert nginx uses (or a dedicated subdomain like `turn.yourhost.ir`).

---

## 7. Flutter Client Structure

```
lib/
├── main.dart
├── services/
│   ├── api_service.dart        # dio: auth, posts, stories, profile REST calls
│   ├── ws_service.dart          # chat WS + reconnect + last_id persistence
│   ├── livekit_service.dart      # livekit_client wrapper
│   └── local_cache.dart           # sqflite: messages, posts, stories cache
├── providers/                       # Riverpod
│   ├── auth_provider.dart
│   ├── chat_provider.dart
│   ├── explore_provider.dart
│   ├── stories_provider.dart
│   └── profile_provider.dart
├── models/
│   ├── message.dart
│   ├── post.dart
│   ├── story.dart
│   └── user.dart
└── screens/
    ├── auth/login_screen.dart
    ├── chat/
    │   ├── room_list_screen.dart
    │   └── chat_screen.dart
    ├── explore/
    │   ├── explore_screen.dart      # masonry grid + stories strip on top
    │   └── post_detail_screen.dart
    ├── stories/story_viewer_screen.dart   # fullscreen tap-through viewer
    ├── call/call_screen.dart
    └── profile/
        ├── profile_screen.dart        # own posts grid, avatar, bio, settings
        └── edit_profile_screen.dart
```

### Explore screen
- Masonry grid via `flutter_staggered_grid_view`, using stored `width`/`height` from the post row to size tiles before the image loads — no layout jump.
- Stories strip: horizontal `ListView` at top, circular avatars with an unseen-ring indicator (based on `viewed` flag from `/stories`), tapping opens `story_viewer_screen` (tap-through, auto-advance, progress bars per story like standard story UIs).
- Pagination via `before_id` cursor, infinite scroll.

### Local cache (sqflite)
Mirrors server tables for: last N messages per room, last-seen posts page, current stories. This is what makes reconnect feel instant — app opens showing cached content immediately, then reconciles in the background rather than showing a spinner.

---

## 8. nginx Routing

```nginx
server {
    listen 443 ssl;
    server_name yourhost.ir;

    location /ws/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location /api/ {
        proxy_pass http://127.0.0.1:8000;
    }

    location /media/ {
        alias /srv/app/backend/media/;
        expires 7d;
    }
}

server {
    listen 443 ssl;
    server_name turn.yourhost.ir;
    location / {
        proxy_pass http://127.0.0.1:7880;   # LiveKit
    }
}
```

---

## 9. Security Baseline

- Passwords: bcrypt, never plaintext, never logged.
- JWT: short-lived access token (e.g. 7 days for this low-churn team), signed with a secret in an env var, never committed.
- All uploads: re-encoded server-side (strip EXIF, cap dimensions) — closes off both metadata leaks and disk-filling attacks.
- No public registration endpoint — accounts created manually by admin (a `POST /admin/users` endpoint gated by a separate admin flag, or literally a CLI script, given 10-20 fixed users).
- Rate-limit `/login` (basic in-memory counter is enough at this scale) to blunt brute force.
- TLS everywhere — chat WS, REST, and LiveKit's TURN, all on 443, all through the same certbot cert.

---

## 10. Build Phases

1. **Core chat** — schema, JWT auth, WS + resync protocol, Flutter chat screen with reconnect + local cache. Ship this alone first; it's the highest-value, most-tested piece.
2. **Calls** — LiveKit docker-compose, token endpoint, `call_screen.dart`, TURN/TLS verified from a real restricted-network device.
3. **Profiles** — `/me`, avatar upload, `profile_screen.dart`.
4. **Explore/Posts** — schema, upload pipeline, masonry feed, likes/comments.
5. **Stories** — schema, expiry scheduler, story strip + viewer.

Each phase is independently shippable and testable with the full 10-person team before moving on — don't build all four features before anyone uses any of them.
