"""SQLite connection helpers and schema initialization (WAL mode)."""

from __future__ import annotations

import re
import sqlite3
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterator

from config import get_settings

SCHEMA = """
PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    username      TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    display_name  TEXT NOT NULL,
    bio           TEXT DEFAULT '',
    avatar_path   TEXT,
    banner_path   TEXT,
    email         TEXT UNIQUE,
    phone         TEXT UNIQUE,
    is_admin      INTEGER DEFAULT 0,
    last_seen_at  TEXT,
    created_at    TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS rooms (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT NOT NULL,
    is_dm       INTEGER DEFAULT 0,
    kind        TEXT NOT NULL DEFAULT 'group',
    description TEXT DEFAULT '',
    avatar_path TEXT,
    public_id   TEXT,
    invite_token TEXT,
    created_by  INTEGER REFERENCES users(id),
    created_at  TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS room_members (
    room_id INTEGER REFERENCES rooms(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'member',
    PRIMARY KEY (room_id, user_id)
);

CREATE TABLE IF NOT EXISTS hidden_rooms (
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    room_id INTEGER REFERENCES rooms(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, room_id)
);

CREATE TABLE IF NOT EXISTS messages (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    room_id    INTEGER REFERENCES rooms(id) ON DELETE CASCADE,
    sender_id  INTEGER REFERENCES users(id),
    content    TEXT,
    image_path TEXT,
    media_path TEXT,
    media_type TEXT,
    file_name  TEXT,
    reply_to_id INTEGER REFERENCES messages(id) ON DELETE SET NULL,
    forwarded_from_id INTEGER,
    deleted_at TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_messages_room_id ON messages(room_id, id);

CREATE TABLE IF NOT EXISTS message_receipts (
    message_id  INTEGER REFERENCES messages(id) ON DELETE CASCADE,
    user_id     INTEGER REFERENCES users(id) ON DELETE CASCADE,
    delivered_at TEXT,
    read_at     TEXT,
    PRIMARY KEY (message_id, user_id)
);

CREATE TABLE IF NOT EXISTS message_mentions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    message_id INTEGER NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    kind TEXT NOT NULL,
    target_id INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_message_mentions_msg ON message_mentions(message_id);

CREATE TABLE IF NOT EXISTS media_uploads (
    media_path TEXT PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    room_id INTEGER REFERENCES rooms(id) ON DELETE SET NULL,
    created_at TEXT DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_media_uploads_room ON media_uploads(room_id, user_id);


CREATE TABLE IF NOT EXISTS posts (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id    INTEGER REFERENCES users(id) ON DELETE CASCADE,
    caption    TEXT DEFAULT '',
    image_path TEXT NOT NULL,
    width      INTEGER NOT NULL,
    height     INTEGER NOT NULL,
    created_at TEXT DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON posts(created_at DESC);

CREATE TABLE IF NOT EXISTS post_likes (
    post_id INTEGER REFERENCES posts(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    PRIMARY KEY (post_id, user_id)
);

CREATE TABLE IF NOT EXISTS post_comments (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    post_id    INTEGER REFERENCES posts(id) ON DELETE CASCADE,
    user_id    INTEGER REFERENCES users(id),
    content    TEXT NOT NULL,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS stories (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id    INTEGER REFERENCES users(id) ON DELETE CASCADE,
    media_path TEXT NOT NULL,
    is_video   INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now')),
    expires_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_stories_expires ON stories(expires_at);

CREATE TABLE IF NOT EXISTS story_views (
    story_id INTEGER REFERENCES stories(id) ON DELETE CASCADE,
    user_id  INTEGER REFERENCES users(id) ON DELETE CASCADE,
    viewed_at TEXT DEFAULT (datetime('now')),
    PRIMARY KEY (story_id, user_id)
);
"""


def get_db_path() -> Path:
    return Path(get_settings().database_path)


def connect() -> sqlite3.Connection:
    conn = sqlite3.connect(get_db_path(), check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode = WAL")
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def init_db() -> None:
    path = get_db_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    with connect() as conn:
        conn.executescript(SCHEMA)
        # Migrate older DBs that may lack is_admin
        user_cols = {row["name"] for row in conn.execute("PRAGMA table_info(users)").fetchall()}
        if "is_admin" not in user_cols:
            conn.execute("ALTER TABLE users ADD COLUMN is_admin INTEGER DEFAULT 0")
        if "email" not in user_cols:
            conn.execute("ALTER TABLE users ADD COLUMN email TEXT")
        if "phone" not in user_cols:
            conn.execute("ALTER TABLE users ADD COLUMN phone TEXT")
        # Unique indexes for recovery contacts (SQLite allows multiple NULLs)
        conn.execute(
            "CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email ON users(email) WHERE email IS NOT NULL"
        )
        conn.execute(
            "CREATE UNIQUE INDEX IF NOT EXISTS idx_users_phone ON users(phone) WHERE phone IS NOT NULL"
        )

        # Migrate rooms → channel / group / dm kinds
        room_cols = {row["name"] for row in conn.execute("PRAGMA table_info(rooms)").fetchall()}
        if "kind" not in room_cols:
            conn.execute("ALTER TABLE rooms ADD COLUMN kind TEXT NOT NULL DEFAULT 'group'")
        if "description" not in room_cols:
            conn.execute("ALTER TABLE rooms ADD COLUMN description TEXT DEFAULT ''")
        if "created_by" not in room_cols:
            conn.execute("ALTER TABLE rooms ADD COLUMN created_by INTEGER REFERENCES users(id)")
        if "avatar_path" not in room_cols:
            conn.execute("ALTER TABLE rooms ADD COLUMN avatar_path TEXT")
        if "public_id" not in room_cols:
            conn.execute("ALTER TABLE rooms ADD COLUMN public_id TEXT")

        user_cols = {row["name"] for row in conn.execute("PRAGMA table_info(users)").fetchall()}
        if "last_seen_at" not in user_cols:
            conn.execute("ALTER TABLE users ADD COLUMN last_seen_at TEXT")
        if "banner_path" not in user_cols:
            conn.execute("ALTER TABLE users ADD COLUMN banner_path TEXT")

        # room_members.role — owner/admin can post in channels
        rm_cols = {row["name"] for row in conn.execute("PRAGMA table_info(room_members)").fetchall()}
        if "role" not in rm_cols:
            conn.execute(
                "ALTER TABLE room_members ADD COLUMN role TEXT NOT NULL DEFAULT 'member'"
            )
        conn.execute(
            """
            UPDATE room_members
            SET role = 'owner'
            WHERE role = 'member'
              AND user_id = (
                SELECT created_by FROM rooms WHERE rooms.id = room_members.room_id
              )
              AND EXISTS (
                SELECT 1 FROM rooms
                WHERE rooms.id = room_members.room_id
                  AND rooms.created_by IS NOT NULL
                  AND rooms.kind IN ('channel', 'group')
              )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS hidden_rooms (
                user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
                room_id INTEGER REFERENCES rooms(id) ON DELETE CASCADE,
                PRIMARY KEY (user_id, room_id)
            )
            """
        )

        conn.execute(
            "CREATE UNIQUE INDEX IF NOT EXISTS idx_rooms_public_id ON rooms(public_id) WHERE public_id IS NOT NULL"
        )
        # Backfill kind from legacy is_dm
        conn.execute("UPDATE rooms SET kind = 'dm' WHERE is_dm = 1 AND (kind IS NULL OR kind = '' OR kind = 'group')")
        conn.execute(
            "UPDATE rooms SET kind = 'group' WHERE is_dm = 0 AND (kind IS NULL OR kind = '')"
        )
        # Backfill public IDs for channels/groups
        missing = conn.execute(
            """
            SELECT id, name FROM rooms
            WHERE kind IN ('channel', 'group') AND (public_id IS NULL OR public_id = '')
            """
        ).fetchall()
        for r in missing:
            base = re.sub(r"[^a-z0-9]+", "_", (r["name"] or "room").strip().lower()).strip("_") or "room"
            if not base[0].isalpha():
                base = f"r_{base}"
            base = re.sub(r"_+", "_", base)[:28]
            if len(base) < 3:
                base = (base + "_id")[:28]
            candidate = base
            n = 1
            while True:
                taken = conn.execute(
                    "SELECT 1 FROM rooms WHERE public_id = ?", (candidate,)
                ).fetchone()
                if not taken:
                    break
                n += 1
                candidate = f"{base}_{n}"
            conn.execute("UPDATE rooms SET public_id = ? WHERE id = ?", (candidate, r["id"]))

        # Chat message media / reply / soft-delete columns
        msg_cols = {row["name"] for row in conn.execute("PRAGMA table_info(messages)").fetchall()}
        for col, ddl in (
            ("media_path", "ALTER TABLE messages ADD COLUMN media_path TEXT"),
            ("media_type", "ALTER TABLE messages ADD COLUMN media_type TEXT"),
            ("file_name", "ALTER TABLE messages ADD COLUMN file_name TEXT"),
            ("reply_to_id", "ALTER TABLE messages ADD COLUMN reply_to_id INTEGER"),
            ("forwarded_from_id", "ALTER TABLE messages ADD COLUMN forwarded_from_id INTEGER"),
            ("deleted_at", "ALTER TABLE messages ADD COLUMN deleted_at TEXT"),
        ):
            if col not in msg_cols:
                conn.execute(ddl)
        # Backfill media_path from legacy image_path
        if "image_path" in msg_cols:
            conn.execute(
                """
                UPDATE messages
                SET media_path = image_path, media_type = 'image'
                WHERE image_path IS NOT NULL AND (media_path IS NULL OR media_path = '')
                """
            )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS message_receipts (
                message_id  INTEGER REFERENCES messages(id) ON DELETE CASCADE,
                user_id     INTEGER REFERENCES users(id) ON DELETE CASCADE,
                delivered_at TEXT,
                read_at     TEXT,
                PRIMARY KEY (message_id, user_id)
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS message_mentions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                message_id INTEGER NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
                kind TEXT NOT NULL,
                target_id INTEGER NOT NULL
            )
            """
        )
        conn.execute("CREATE INDEX IF NOT EXISTS idx_message_mentions_msg ON message_mentions(message_id)")

        # Channel/group invite tokens (join via URL — not auto-enroll everyone)
        room_cols = {row["name"] for row in conn.execute("PRAGMA table_info(rooms)").fetchall()}
        if "invite_token" not in room_cols:
            conn.execute("ALTER TABLE rooms ADD COLUMN invite_token TEXT")
        conn.execute(
            "CREATE UNIQUE INDEX IF NOT EXISTS idx_rooms_invite_token ON rooms(invite_token) WHERE invite_token IS NOT NULL"
        )

        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS media_uploads (
                media_path TEXT PRIMARY KEY,
                user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                room_id INTEGER REFERENCES rooms(id) ON DELETE SET NULL,
                created_at TEXT DEFAULT (datetime('now'))
            )
            """
        )
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_media_uploads_room ON media_uploads(room_id, user_id)"
        )

        # Backfill invite tokens for existing channels/groups
        missing_invites = conn.execute(
            """
            SELECT id FROM rooms
            WHERE kind IN ('channel', 'group')
              AND (invite_token IS NULL OR invite_token = '')
            """
        ).fetchall()
        if missing_invites:
            import secrets

            for r in missing_invites:
                conn.execute(
                    "UPDATE rooms SET invite_token = ? WHERE id = ?",
                    (secrets.token_urlsafe(18), r["id"]),
                )

        conn.commit()


@contextmanager
def get_db() -> Iterator[sqlite3.Connection]:
    conn = connect()
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def row_to_dict(row: sqlite3.Row | None) -> dict[str, Any] | None:
    if row is None:
        return None
    return dict(row)
