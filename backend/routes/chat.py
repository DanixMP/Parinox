"""Chat rooms: channels, groups, DMs — history and WebSocket with resync."""

from __future__ import annotations

import re

from fastapi import APIRouter, File, HTTPException, Query, UploadFile, WebSocket, WebSocketDisconnect, status

from auth import CurrentUser, verify_jwt_token
from db import get_db, row_to_dict
from media_access import (
    assert_upload_usable,
    clamp_message_content,
    create_ws_ticket,
    delete_media_file_if_orphaned,
    new_invite_token,
    normalize_media_path,
    register_upload,
    verify_ws_ticket,
)
from models import (
    DmCreate,
    ForwardRequest,
    LastMessagePreview,
    MessageOut,
    RoomCreate,
    RoomMemberRoleUpdate,
    RoomMembersAdd,
    RoomOut,
    RoomUpdate,
    UserPublic,
)
from presence import presence
from ws_manager import manager

router = APIRouter(tags=["chat"])

VALID_KINDS = frozenset({"channel", "group", "dm"})
PUBLIC_ID_RE = re.compile(r"^[a-z][a-z0-9_]{2,31}$")
MENTION_RE = re.compile(r"(?<![A-Za-z0-9_])@([A-Za-z][A-Za-z0-9_]{1,31})")


def _user_public(row: dict) -> UserPublic:
    uid = row["id"]
    online = presence.is_online(uid)
    return UserPublic(
        id=uid,
        username=row["username"],
        display_name=row["display_name"],
        bio=row.get("bio") or "",
        avatar_path=row.get("avatar_path"),
        created_at=row.get("created_at"),
        is_online=online,
        last_seen_at=None if online else row.get("last_seen_at"),
    )


def _normalize_public_id(raw: str | None) -> str | None:
    if raw is None:
        return None
    value = raw.strip().lstrip("@#").lower()
    if not value:
        return None
    if not PUBLIC_ID_RE.match(value):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Public ID must be 3–32 chars: start with a letter, then letters/numbers/_",
        )
    return value


def _slug_from_name(name: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "_", name.strip().lower()).strip("_")
    if not slug or not slug[0].isalpha():
        slug = f"room_{slug}" if slug else "room"
    slug = re.sub(r"_+", "_", slug)[:32]
    if len(slug) < 3:
        slug = (slug + "_chat")[:32]
    if not PUBLIC_ID_RE.match(slug):
        slug = f"r_{slug}"[:32]
        if not PUBLIC_ID_RE.match(slug):
            slug = "room_chat"
    return slug


def _allocate_public_id(conn, base: str, *, exclude_room_id: int | None = None) -> str:
    candidate = base
    n = 1
    while True:
        row = conn.execute("SELECT id FROM rooms WHERE public_id = ?", (candidate,)).fetchone()
        if not row or (exclude_room_id is not None and row["id"] == exclude_room_id):
            return candidate
        n += 1
        suffix = f"_{n}"
        candidate = f"{base[: 32 - len(suffix)]}{suffix}"


def _assert_public_id_available(conn, public_id: str, *, exclude_room_id: int | None = None) -> None:
    row = conn.execute("SELECT id FROM rooms WHERE public_id = ?", (public_id,)).fetchone()
    if row and (exclude_room_id is None or row["id"] != exclude_room_id):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Public ID already taken")


def _serialize_message(conn, row: dict) -> dict:
    deleted = bool(row.get("deleted_at"))
    media_path = row.get("media_path") or row.get("image_path")
    media_type = row.get("media_type")
    if not media_type and row.get("image_path"):
        media_type = "image"

    reply_preview = None
    reply_to_id = row.get("reply_to_id")
    if reply_to_id:
        parent = conn.execute(
            """
            SELECT m.id, m.content, m.media_type, m.media_path, m.image_path, m.file_name,
                   m.deleted_at, u.display_name AS sender_display_name
            FROM messages m
            LEFT JOIN users u ON u.id = m.sender_id
            WHERE m.id = ?
            """,
            (reply_to_id,),
        ).fetchone()
        if parent:
            p = dict(parent)
            reply_preview = {
                "id": p["id"],
                "sender_display_name": p.get("sender_display_name"),
                "content": None if p.get("deleted_at") else p.get("content"),
                "media_type": None if p.get("deleted_at") else (p.get("media_type") or ("image" if p.get("image_path") else None)),
                "deleted": bool(p.get("deleted_at")),
            }

    delivery_status = "sent"
    sender_id = row["sender_id"]
    room_id = row["room_id"]
    other_ids = [
        r["user_id"]
        for r in conn.execute(
            "SELECT user_id FROM room_members WHERE room_id = ? AND user_id != ?",
            (room_id, sender_id),
        ).fetchall()
    ]
    if other_ids:
        receipts = conn.execute(
            f"""
            SELECT user_id, delivered_at, read_at FROM message_receipts
            WHERE message_id = ? AND user_id IN ({",".join("?" * len(other_ids))})
            """,
            (row["id"], *other_ids),
        ).fetchall()
        by_user = {r["user_id"]: dict(r) for r in receipts}
        if other_ids and all(by_user.get(uid, {}).get("delivered_at") for uid in other_ids):
            delivery_status = "delivered"
        if other_ids and all(by_user.get(uid, {}).get("read_at") for uid in other_ids):
            delivery_status = "read"
        elif other_ids and any(by_user.get(uid, {}).get("read_at") for uid in other_ids):
            # Partial read in groups still shows delivered (or read if DM with 1 other)
            if len(other_ids) == 1:
                delivery_status = "read"
            elif delivery_status == "sent" and any(by_user.get(uid, {}).get("delivered_at") for uid in other_ids):
                delivery_status = "delivered"

    mentions: list[dict] = []
    mention_rows = conn.execute(
        "SELECT kind, target_id FROM message_mentions WHERE message_id = ?",
        (row["id"],),
    ).fetchall()
    for mr in mention_rows:
        if mr["kind"] == "user":
            u = conn.execute(
                "SELECT id, username, display_name FROM users WHERE id = ?",
                (mr["target_id"],),
            ).fetchone()
            if u:
                mentions.append(
                    {
                        "kind": "user",
                        "id": u["id"],
                        "username": u["username"],
                        "display_name": u["display_name"],
                    }
                )
        elif mr["kind"] == "room":
            r = conn.execute(
                "SELECT id, name, kind, public_id FROM rooms WHERE id = ?",
                (mr["target_id"],),
            ).fetchone()
            if r:
                mentions.append(
                    {
                        "kind": "room",
                        "id": r["id"],
                        "name": r["name"],
                        "public_id": r["public_id"],
                        "room_kind": r["kind"],
                    }
                )

    return {
        "id": row["id"],
        "room_id": room_id,
        "sender_id": sender_id,
        "content": None if deleted else row.get("content"),
        "image_path": None if deleted else media_path if media_type == "image" else None,
        "media_path": None if deleted else media_path,
        "media_type": None if deleted else media_type,
        "file_name": None if deleted else row.get("file_name"),
        "reply_to_id": reply_to_id,
        "reply_preview": reply_preview,
        "forwarded_from_id": row.get("forwarded_from_id"),
        "is_forwarded": bool(row.get("forwarded_from_id")),
        "deleted": deleted,
        "delivery_status": delivery_status,
        "mentions": mentions,
        "created_at": row["created_at"],
        "sender_display_name": row.get("sender_display_name"),
        "sender_avatar_path": row.get("sender_avatar_path"),
        "type": "message",
    }


def _fetch_message(conn, message_id: int) -> dict | None:
    row = conn.execute(
        """
        SELECT m.*, u.display_name AS sender_display_name, u.avatar_path AS sender_avatar_path
        FROM messages m
        LEFT JOIN users u ON u.id = m.sender_id
        WHERE m.id = ?
        """,
        (message_id,),
    ).fetchone()
    return dict(row) if row else None


def _save_mentions(conn, message_id: int, content: str | None) -> None:
    if not content:
        return
    tokens = {m.group(1).lower() for m in MENTION_RE.finditer(content)}
    if not tokens:
        return
    for token in tokens:
        user = conn.execute(
            "SELECT id FROM users WHERE lower(username) = ?",
            (token,),
        ).fetchone()
        if user:
            conn.execute(
                "INSERT INTO message_mentions (message_id, kind, target_id) VALUES (?, 'user', ?)",
                (message_id, user["id"]),
            )
            continue
        room = conn.execute(
            "SELECT id FROM rooms WHERE public_id = ? AND kind IN ('channel', 'group')",
            (token,),
        ).fetchone()
        if room:
            conn.execute(
                "INSERT INTO message_mentions (message_id, kind, target_id) VALUES (?, 'room', ?)",
                (message_id, room["id"]),
            )


def _mark_delivered(conn, message_ids: list[int], user_id: int) -> list[int]:
    touched: list[int] = []
    for mid in message_ids:
        msg = conn.execute(
            "SELECT id, sender_id, room_id FROM messages WHERE id = ?", (mid,)
        ).fetchone()
        if not msg or msg["sender_id"] == user_id:
            continue
        if not _is_member(conn, msg["room_id"], user_id):
            continue
        existing = conn.execute(
            "SELECT delivered_at FROM message_receipts WHERE message_id = ? AND user_id = ?",
            (mid, user_id),
        ).fetchone()
        if existing and existing["delivered_at"]:
            continue
        if existing:
            conn.execute(
                "UPDATE message_receipts SET delivered_at = datetime('now') WHERE message_id = ? AND user_id = ?",
                (mid, user_id),
            )
        else:
            conn.execute(
                """
                INSERT INTO message_receipts (message_id, user_id, delivered_at)
                VALUES (?, ?, datetime('now'))
                """,
                (mid, user_id),
            )
        touched.append(mid)
    return touched


def _mark_read_up_to(conn, room_id: int, up_to_id: int, user_id: int) -> list[int]:
    rows = conn.execute(
        """
        SELECT id FROM messages
        WHERE room_id = ? AND id <= ? AND sender_id != ? AND deleted_at IS NULL
        """,
        (room_id, up_to_id, user_id),
    ).fetchall()
    touched: list[int] = []
    for r in rows:
        mid = r["id"]
        existing = conn.execute(
            "SELECT delivered_at, read_at FROM message_receipts WHERE message_id = ? AND user_id = ?",
            (mid, user_id),
        ).fetchone()
        if existing and existing["read_at"]:
            continue
        if existing:
            conn.execute(
                """
                UPDATE message_receipts
                SET delivered_at = COALESCE(delivered_at, datetime('now')),
                    read_at = datetime('now')
                WHERE message_id = ? AND user_id = ?
                """,
                (mid, user_id),
            )
        else:
            conn.execute(
                """
                INSERT INTO message_receipts (message_id, user_id, delivered_at, read_at)
                VALUES (?, ?, datetime('now'), datetime('now'))
                """,
                (mid, user_id),
            )
        touched.append(mid)
    return touched


async def _broadcast_receipt_updates(room_id: int, message_ids: list[int]) -> None:
    if not message_ids:
        return
    with get_db() as conn:
        for mid in message_ids:
            row = _fetch_message(conn, mid)
            if not row:
                continue
            payload = _serialize_message(conn, row)
            await manager.broadcast(
                room_id,
                {
                    "type": "receipts",
                    "message_id": mid,
                    "room_id": room_id,
                    "delivery_status": payload["delivery_status"],
                },
            )



def _is_member(conn, room_id: int, user_id: int) -> bool:
    row = conn.execute(
        "SELECT 1 FROM room_members WHERE room_id = ? AND user_id = ?",
        (room_id, user_id),
    ).fetchone()
    return row is not None


def _member_role(conn, room_id: int, user_id: int) -> str | None:
    row = conn.execute(
        "SELECT role FROM room_members WHERE room_id = ? AND user_id = ?",
        (room_id, user_id),
    ).fetchone()
    if not row:
        return None
    role = (row["role"] or "member").lower()
    return role if role in ("owner", "admin", "member") else "member"


def _add_members(conn, room_id: int, member_roles: dict[int, str]) -> None:
    conn.executemany(
        "INSERT OR IGNORE INTO room_members (room_id, user_id, role) VALUES (?, ?, ?)",
        [(room_id, uid, role) for uid, role in member_roles.items()],
    )


def _unhide_room(conn, user_id: int, room_id: int) -> None:
    conn.execute(
        "DELETE FROM hidden_rooms WHERE user_id = ? AND room_id = ?",
        (user_id, room_id),
    )


def _hide_room(conn, user_id: int, room_id: int) -> None:
    conn.execute(
        "INSERT OR IGNORE INTO hidden_rooms (user_id, room_id) VALUES (?, ?)",
        (user_id, room_id),
    )


def _can_post(conn, room_id: int, user_id: int) -> bool:
    """Channels: only owner/admin (or room creator). Groups/DMs: any member."""
    if not _is_member(conn, room_id, user_id):
        return False
    room = conn.execute("SELECT * FROM rooms WHERE id = ?", (room_id,)).fetchone()
    if not room:
        return False
    kind = _room_kind(dict(room))
    if kind != "channel":
        return True
    role = _member_role(conn, room_id, user_id)
    if role in ("owner", "admin"):
        return True
    if room["created_by"] == user_id:
        return True
    admin = conn.execute("SELECT is_admin FROM users WHERE id = ?", (user_id,)).fetchone()
    return bool(admin and admin["is_admin"])


def _assert_can_post(conn, room_id: int, user_id: int) -> None:
    if not _can_post(conn, room_id, user_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only channel admins can post messages",
        )


def _room_kind(row: dict) -> str:
    kind = row.get("kind") or ("dm" if row.get("is_dm") else "group")
    return kind if kind in VALID_KINDS else "group"


def _last_message_preview(conn, room_id: int) -> LastMessagePreview | None:
    row = conn.execute(
        """
        SELECT m.id, m.content, m.media_type, m.image_path, m.media_path,
               m.deleted_at, m.sender_id, m.created_at,
               u.display_name AS sender_display_name
        FROM messages m
        LEFT JOIN users u ON u.id = m.sender_id
        WHERE m.room_id = ?
        ORDER BY m.id DESC
        LIMIT 1
        """,
        (room_id,),
    ).fetchone()
    if not row:
        return None
    d = dict(row)
    deleted = bool(d.get("deleted_at"))
    media_type = d.get("media_type")
    if not media_type and d.get("image_path"):
        media_type = "image"
    return LastMessagePreview(
        id=d["id"],
        content=None if deleted else d.get("content"),
        media_type=None if deleted else media_type,
        sender_id=d["sender_id"],
        sender_display_name=d.get("sender_display_name"),
        created_at=d["created_at"],
        deleted=deleted,
    )


def _unread_count(conn, room_id: int, user_id: int) -> int:
    row = conn.execute(
        """
        SELECT COUNT(*) AS c FROM messages m
        WHERE m.room_id = ?
          AND m.sender_id != ?
          AND m.deleted_at IS NULL
          AND NOT EXISTS (
            SELECT 1 FROM message_receipts mr
            WHERE mr.message_id = m.id AND mr.user_id = ? AND mr.read_at IS NOT NULL
          )
        """,
        (room_id, user_id, user_id),
    ).fetchone()
    return int(row["c"]) if row else 0


def _role_rank(role: str | None) -> int:
    return {"owner": 3, "admin": 2, "member": 1}.get((role or "member").lower(), 0)


def _assert_can_manage_members(conn, room_id: int, user_id: int) -> str:
    role = _member_role(conn, room_id, user_id)
    if role not in ("owner", "admin"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only owners and admins can manage members",
        )
    return role or "member"


def _room_with_members(conn, room_id: int, viewer_id: int | None = None) -> RoomOut | None:
    room = conn.execute("SELECT * FROM rooms WHERE id = ?", (room_id,)).fetchone()
    if not room:
        return None
    d = dict(room)
    kind = _room_kind(d)
    members = conn.execute(
        """
        SELECT u.id, u.username, u.display_name, u.bio, u.avatar_path, u.created_at,
               rm.role AS member_role
        FROM users u
        JOIN room_members rm ON rm.user_id = u.id
        WHERE rm.room_id = ?
        ORDER BY
          CASE LOWER(COALESCE(rm.role, 'member'))
            WHEN 'owner' THEN 0
            WHEN 'admin' THEN 1
            ELSE 2
          END,
          u.display_name
        """,
        (room_id,),
    ).fetchall()
    my_role = "member"
    can_post = kind != "channel"
    invite_token = None
    if viewer_id is not None:
        my_role = _member_role(conn, room_id, viewer_id) or "member"
        can_post = _can_post(conn, room_id, viewer_id)
        if kind in ("channel", "group") and my_role in ("owner", "admin"):
            invite_token = d.get("invite_token")
    elif kind == "channel":
        can_post = False

    member_outs: list[UserPublic] = []
    for m in members:
        md = dict(m)
        pub = _user_public(md)
        pub.role = (md.get("member_role") or "member").lower()
        member_outs.append(pub)

    return RoomOut(
        id=d["id"],
        name=d["name"],
        kind=kind,  # type: ignore[arg-type]
        is_dm=kind == "dm",
        description=d.get("description") or "",
        avatar_path=d.get("avatar_path"),
        public_id=d.get("public_id"),
        invite_token=invite_token,
        created_by=d.get("created_by"),
        created_at=d.get("created_at"),
        members=member_outs,
        last_message=_last_message_preview(conn, room_id),
        unread_count=_unread_count(conn, room_id, viewer_id) if viewer_id is not None else 0,
        my_role=my_role,
        can_post=can_post,
    )


def _find_dm(conn, user_a: int, user_b: int) -> int | None:
    a, b = sorted((user_a, user_b))
    existing = conn.execute(
        """
        SELECT r.id FROM rooms r
        JOIN room_members m1 ON m1.room_id = r.id AND m1.user_id = ?
        JOIN room_members m2 ON m2.room_id = r.id AND m2.user_id = ?
        WHERE (r.kind = 'dm' OR r.is_dm = 1)
        AND (SELECT COUNT(*) FROM room_members WHERE room_id = r.id) = 2
        LIMIT 1
        """,
        (a, b),
    ).fetchone()
    return int(existing["id"]) if existing else None


def _ensure_users_exist(conn, user_ids: set[int]) -> None:
    if not user_ids:
        return
    placeholders = ",".join("?" * len(user_ids))
    found = conn.execute(
        f"SELECT id FROM users WHERE id IN ({placeholders})",
        tuple(user_ids),
    ).fetchall()
    if len(found) != len(user_ids):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Unknown member id")


def join_user_to_all_channels(conn, user_id: int) -> None:
    """Deprecated no-op: channels are invite-link only."""
    return


@router.get("/rooms", response_model=list[RoomOut])
def list_rooms(
    user: CurrentUser,
    kind: str | None = Query(default=None, pattern="^(channel|group|dm)$"),
) -> list[RoomOut]:
    with get_db() as conn:
        if kind:
            rows = conn.execute(
                """
                SELECT r.id FROM rooms r
                JOIN room_members rm ON rm.room_id = r.id
                WHERE rm.user_id = ? AND r.kind = ?
                  AND NOT EXISTS (
                    SELECT 1 FROM hidden_rooms h
                    WHERE h.user_id = ? AND h.room_id = r.id
                  )
                ORDER BY (
                  SELECT COALESCE(MAX(m.id), 0) FROM messages m WHERE m.room_id = r.id
                ) DESC, r.created_at DESC
                """,
                (user["id"], kind, user["id"]),
            ).fetchall()
        else:
            rows = conn.execute(
                """
                SELECT r.id FROM rooms r
                JOIN room_members rm ON rm.room_id = r.id
                WHERE rm.user_id = ?
                  AND NOT EXISTS (
                    SELECT 1 FROM hidden_rooms h
                    WHERE h.user_id = ? AND h.room_id = r.id
                  )
                ORDER BY (
                  SELECT COALESCE(MAX(m.id), 0) FROM messages m WHERE m.room_id = r.id
                ) DESC, r.created_at DESC
                """,
                (user["id"], user["id"]),
            ).fetchall()
        return [_room_with_members(conn, r["id"], viewer_id=user["id"]) for r in rows]  # type: ignore[misc]


@router.post("/rooms", response_model=RoomOut, status_code=status.HTTP_201_CREATED)
def create_room(body: RoomCreate, user: CurrentUser) -> RoomOut:
    kind = body.kind
    if kind not in VALID_KINDS:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid kind")

    with get_db() as conn:
        if kind == "dm":
            member_ids = set(body.member_ids) | {user["id"]}
            if len(member_ids) != 2:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="DM requires exactly one other member",
                )
            other = next(uid for uid in member_ids if uid != user["id"])
            existing_id = _find_dm(conn, user["id"], other)
            if existing_id is not None:
                _unhide_room(conn, user["id"], existing_id)
                _add_members(conn, existing_id, {user["id"]: "member", other: "member"})
                room = _room_with_members(conn, existing_id, viewer_id=user["id"])
                assert room is not None
                return room
            _ensure_users_exist(conn, member_ids)
            other_row = conn.execute(
                "SELECT display_name FROM users WHERE id = ?", (other,)
            ).fetchone()
            name = body.name if body.name and body.name.lower() != "dm" else (
                other_row["display_name"] if other_row else "DM"
            )
            cur = conn.execute(
                """
                INSERT INTO rooms (name, is_dm, kind, description, created_by)
                VALUES (?, 1, 'dm', ?, ?)
                """,
                (name, body.description or "", user["id"]),
            )
            room_id = cur.lastrowid
            _add_members(conn, room_id, {mid: "member" for mid in member_ids})
            room = _room_with_members(conn, room_id, viewer_id=user["id"])  # type: ignore[arg-type]
            assert room is not None
            return room

        if kind == "channel":
            # Invite-link channels: creator only; others join via invite URL.
            requested = _normalize_public_id(body.public_id) if body.public_id else None
            if requested:
                _assert_public_id_available(conn, requested)
                public_id = requested
            else:
                public_id = _allocate_public_id(conn, _slug_from_name(body.name))
            invite = new_invite_token()
            cur = conn.execute(
                """
                INSERT INTO rooms (name, is_dm, kind, description, public_id, invite_token, created_by)
                VALUES (?, 0, 'channel', ?, ?, ?, ?)
                """,
                (body.name.strip(), body.description.strip(), public_id, invite, user["id"]),
            )
            room_id = cur.lastrowid
            _add_members(conn, room_id, {user["id"]: "owner"})
            room = _room_with_members(conn, room_id, viewer_id=user["id"])  # type: ignore[arg-type]
            assert room is not None
            return room

        # group — creator + optional member_ids; joinable via invite URL too
        member_ids = set(body.member_ids) | {user["id"]}
        _ensure_users_exist(conn, member_ids)
        requested = _normalize_public_id(body.public_id) if body.public_id else None
        if requested:
            _assert_public_id_available(conn, requested)
            public_id = requested
        else:
            public_id = _allocate_public_id(conn, _slug_from_name(body.name))
        invite = new_invite_token()
        cur = conn.execute(
            """
            INSERT INTO rooms (name, is_dm, kind, description, public_id, invite_token, created_by)
            VALUES (?, 0, 'group', ?, ?, ?, ?)
            """,
            (body.name.strip(), body.description.strip(), public_id, invite, user["id"]),
        )
        room_id = cur.lastrowid
        roles = {mid: ("owner" if mid == user["id"] else "member") for mid in member_ids}
        _add_members(conn, room_id, roles)
        room = _room_with_members(conn, room_id, viewer_id=user["id"])  # type: ignore[arg-type]
        assert room is not None
        return room


@router.post("/dms", response_model=RoomOut, status_code=status.HTTP_201_CREATED)
def open_or_create_dm(body: DmCreate, user: CurrentUser) -> RoomOut:
    """Open (or reuse) a private 1:1 chat with another user — app integration entrypoint."""
    if body.user_id == user["id"]:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot DM yourself")
    return create_room(
        RoomCreate(name="DM", member_ids=[body.user_id], kind="dm"),
        user,
    )


@router.get("/rooms/lookup/{public_id}", response_model=RoomOut)
def lookup_room_by_public_id(public_id: str, user: CurrentUser) -> RoomOut:
    pid = _normalize_public_id(public_id)
    if not pid:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid public ID")
    with get_db() as conn:
        row = conn.execute(
            "SELECT id FROM rooms WHERE public_id = ? AND kind IN ('channel', 'group')",
            (pid,),
        ).fetchone()
        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found")
        if not _is_member(conn, row["id"], user["id"]):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Not a room member — join with an invite link",
            )
        room = _room_with_members(conn, row["id"], viewer_id=user["id"])
        assert room is not None
        return room


@router.post("/rooms/join/{invite_token}", response_model=RoomOut)
def join_room_by_invite(invite_token: str, user: CurrentUser) -> RoomOut:
    """Join a channel or group via invite URL token."""
    token = (invite_token or "").strip()
    if len(token) < 8:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid invite")
    with get_db() as conn:
        row = conn.execute(
            """
            SELECT id, kind FROM rooms
            WHERE invite_token = ? AND kind IN ('channel', 'group')
            """,
            (token,),
        ).fetchone()
        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Invite not found")
        room_id = int(row["id"])
        if _is_member(conn, room_id, user["id"]):
            _unhide_room(conn, user["id"], room_id)
        else:
            _add_members(conn, room_id, {user["id"]: "member"})
        room = _room_with_members(conn, room_id, viewer_id=user["id"])
        assert room is not None
        return room


@router.post("/rooms/{room_id}/invite/rotate", response_model=RoomOut)
def rotate_room_invite(room_id: int, user: CurrentUser) -> RoomOut:
    """Generate a new invite token (invalidates previous share links)."""
    with get_db() as conn:
        row = conn.execute("SELECT * FROM rooms WHERE id = ?", (room_id,)).fetchone()
        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found")
        kind = _room_kind(dict(row))
        if kind not in ("channel", "group"):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="DMs have no invites")
        _assert_can_manage_members(conn, room_id, user["id"])
        conn.execute(
            "UPDATE rooms SET invite_token = ? WHERE id = ?",
            (new_invite_token(), room_id),
        )
        room = _room_with_members(conn, room_id, viewer_id=user["id"])
        assert room is not None
        return room


@router.get("/rooms/{room_id}/invite")
def get_room_invite(room_id: int, user: CurrentUser) -> dict:
    """Return invite token + relative join path for owners/admins."""
    with get_db() as conn:
        row = conn.execute("SELECT * FROM rooms WHERE id = ?", (room_id,)).fetchone()
        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found")
        kind = _room_kind(dict(row))
        if kind not in ("channel", "group"):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="DMs have no invites")
        _assert_can_manage_members(conn, room_id, user["id"])
        token = row["invite_token"]
        if not token:
            token = new_invite_token()
            conn.execute("UPDATE rooms SET invite_token = ? WHERE id = ?", (token, room_id))
        return {
            "invite_token": token,
            "join_path": f"/rooms/join/{token}",
            "share_code": f"parinox://join/{token}",
        }


@router.get("/rooms/{room_id}", response_model=RoomOut)
def get_room(room_id: int, user: CurrentUser) -> RoomOut:
    with get_db() as conn:
        if not _is_member(conn, room_id, user["id"]):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a room member")
        _unhide_room(conn, user["id"], room_id)
        room = _room_with_members(conn, room_id, viewer_id=user["id"])
        if not room:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found")
        return room


@router.patch("/rooms/{room_id}", response_model=RoomOut)
def update_room(room_id: int, body: RoomUpdate, user: CurrentUser) -> RoomOut:
    with get_db() as conn:
        row = conn.execute("SELECT * FROM rooms WHERE id = ?", (room_id,)).fetchone()
        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found")
        d = dict(row)
        kind = _room_kind(d)
        if kind == "dm":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot edit a DM")
        if not _is_member(conn, room_id, user["id"]):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a room member")
        role = _member_role(conn, room_id, user["id"])
        if role not in ("owner", "admin") and d.get("created_by") != user["id"]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only owners and admins can edit this chat",
            )
        updates: list[str] = []
        params: list = []
        if body.name is not None:
            updates.append("name = ?")
            params.append(body.name.strip())
        if body.description is not None:
            updates.append("description = ?")
            params.append(body.description.strip())
        if body.public_id is not None:
            pid = _normalize_public_id(body.public_id)
            if pid is None:
                updates.append("public_id = NULL")
            else:
                _assert_public_id_available(conn, pid, exclude_room_id=room_id)
                updates.append("public_id = ?")
                params.append(pid)
        if not updates:
            room = _room_with_members(conn, room_id, viewer_id=user["id"])
            assert room is not None
            return room
        params.append(room_id)
        conn.execute(f"UPDATE rooms SET {', '.join(updates)} WHERE id = ?", params)
        room = _room_with_members(conn, room_id, viewer_id=user["id"])
        assert room is not None
        return room


@router.post("/rooms/{room_id}/avatar", response_model=RoomOut)
async def upload_room_avatar(
    room_id: int,
    user: CurrentUser,
    avatar: UploadFile = File(...),
) -> RoomOut:
    from routes.upload import save_image

    with get_db() as conn:
        row = conn.execute("SELECT * FROM rooms WHERE id = ?", (room_id,)).fetchone()
        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found")
        if _room_kind(dict(row)) == "dm":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="DMs have no avatar")
        if not _is_member(conn, room_id, user["id"]):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a room member")
        _assert_can_manage_members(conn, room_id, user["id"])
    rel, _w, _h = await save_image(avatar, "rooms")
    with get_db() as conn:
        conn.execute("UPDATE rooms SET avatar_path = ? WHERE id = ?", (rel, room_id))
        room = _room_with_members(conn, room_id, viewer_id=user["id"])
        assert room is not None
        return room


@router.delete("/rooms/{room_id}/avatar", response_model=RoomOut)
def clear_room_avatar(room_id: int, user: CurrentUser) -> RoomOut:
    with get_db() as conn:
        row = conn.execute("SELECT * FROM rooms WHERE id = ?", (room_id,)).fetchone()
        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found")
        if _room_kind(dict(row)) == "dm":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="DMs have no avatar")
        if not _is_member(conn, room_id, user["id"]):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a room member")
        _assert_can_manage_members(conn, room_id, user["id"])
        conn.execute("UPDATE rooms SET avatar_path = NULL WHERE id = ?", (room_id,))
        room = _room_with_members(conn, room_id, viewer_id=user["id"])
        assert room is not None
        return room


@router.post("/rooms/{room_id}/members", response_model=RoomOut)
def add_members(room_id: int, body: RoomMembersAdd, user: CurrentUser) -> RoomOut:
    with get_db() as conn:
        room_row = conn.execute("SELECT * FROM rooms WHERE id = ?", (room_id,)).fetchone()
        if not room_row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found")
        if not _is_member(conn, room_id, user["id"]):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a room member")
        kind = _room_kind(dict(room_row))
        if kind == "dm":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot add members to a DM")
        _assert_can_manage_members(conn, room_id, user["id"])
        ids = set(body.user_ids) - {user["id"]}
        if not ids:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No members to add")
        _ensure_users_exist(conn, ids)
        _add_members(conn, room_id, {uid: "member" for uid in ids})
        for uid in ids:
            _unhide_room(conn, uid, room_id)
        room = _room_with_members(conn, room_id, viewer_id=user["id"])
        assert room is not None
        return room


@router.delete("/rooms/{room_id}/members/{member_id}", response_model=RoomOut)
def remove_member(room_id: int, member_id: int, user: CurrentUser) -> RoomOut:
    """Kick a member from a group or channel (owner/admin)."""
    with get_db() as conn:
        room_row = conn.execute("SELECT * FROM rooms WHERE id = ?", (room_id,)).fetchone()
        if not room_row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found")
        kind = _room_kind(dict(room_row))
        if kind == "dm":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot remove members from a DM")
        if member_id == user["id"]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Use leave to remove yourself",
            )
        actor_role = _assert_can_manage_members(conn, room_id, user["id"])
        if not _is_member(conn, room_id, member_id):
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User is not a member")
        target_role = _member_role(conn, room_id, member_id) or "member"
        if _role_rank(actor_role) <= _role_rank(target_role):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Cannot remove a member with equal or higher role",
            )
        conn.execute(
            "DELETE FROM room_members WHERE room_id = ? AND user_id = ?",
            (room_id, member_id),
        )
        _hide_room(conn, member_id, room_id)
        room = _room_with_members(conn, room_id, viewer_id=user["id"])
        assert room is not None
        return room


@router.patch("/rooms/{room_id}/members/{member_id}", response_model=RoomOut)
def set_member_role(
    room_id: int,
    member_id: int,
    body: RoomMemberRoleUpdate,
    user: CurrentUser,
) -> RoomOut:
    """Promote/demote members. Only the owner can change roles."""
    with get_db() as conn:
        room_row = conn.execute("SELECT * FROM rooms WHERE id = ?", (room_id,)).fetchone()
        if not room_row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found")
        kind = _room_kind(dict(room_row))
        if kind == "dm":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="DMs have no roles")
        actor_role = _member_role(conn, room_id, user["id"])
        if actor_role != "owner" and dict(room_row).get("created_by") != user["id"]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only the owner can change member roles",
            )
        if member_id == user["id"]:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot change your own role")
        if not _is_member(conn, room_id, member_id):
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User is not a member")
        target_role = _member_role(conn, room_id, member_id) or "member"
        if target_role == "owner":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot change the owner's role")
        new_role = body.role
        conn.execute(
            "UPDATE room_members SET role = ? WHERE room_id = ? AND user_id = ?",
            (new_role, room_id, member_id),
        )
        room = _room_with_members(conn, room_id, viewer_id=user["id"])
        assert room is not None
        return room


@router.delete("/rooms/{room_id}/members/me", response_model=RoomOut | None, status_code=status.HTTP_200_OK)
def leave_room(room_id: int, user: CurrentUser) -> RoomOut | None:
    with get_db() as conn:
        room_row = conn.execute("SELECT * FROM rooms WHERE id = ?", (room_id,)).fetchone()
        if not room_row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found")
        kind = _room_kind(dict(room_row))
        if kind == "dm":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Use delete chat to remove a DM from your list",
            )
        if not _is_member(conn, room_id, user["id"]):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a room member")
        role = _member_role(conn, room_id, user["id"])
        if kind == "channel" and role == "owner":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Channel owners must delete the channel instead of leaving",
            )
        conn.execute(
            "DELETE FROM room_members WHERE room_id = ? AND user_id = ?",
            (room_id, user["id"]),
        )
        _hide_room(conn, user["id"], room_id)
        remaining = conn.execute(
            "SELECT COUNT(*) AS c FROM room_members WHERE room_id = ?",
            (room_id,),
        ).fetchone()["c"]
        if remaining == 0:
            conn.execute("DELETE FROM rooms WHERE id = ?", (room_id,))
            return None
        return _room_with_members(conn, room_id, viewer_id=user["id"])


@router.delete("/rooms/{room_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_chat(
    room_id: int,
    user: CurrentUser,
    for_everyone: bool = Query(default=False),
):
    """Remove chat from my list. Owners can pass for_everyone to destroy the room."""
    with get_db() as conn:
        room_row = conn.execute("SELECT * FROM rooms WHERE id = ?", (room_id,)).fetchone()
        if not room_row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found")
        d = dict(room_row)
        kind = _room_kind(d)
        if not _is_member(conn, room_id, user["id"]):
            # Already left — still allow hide cleanup
            _hide_room(conn, user["id"], room_id)
            return None

        role = _member_role(conn, room_id, user["id"])
        is_owner = role == "owner" or d.get("created_by") == user["id"]

        if for_everyone:
            if kind == "dm":
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Cannot delete a DM for everyone",
                )
            if not is_owner:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Only the owner can delete this chat for everyone",
                )
            conn.execute("DELETE FROM rooms WHERE id = ?", (room_id,))
            return None

        # Delete for me
        if kind == "dm":
            _hide_room(conn, user["id"], room_id)
            return None

        if kind == "channel" and is_owner:
            # Owners removing from list without for_everyone → just hide (stay owner)
            _hide_room(conn, user["id"], room_id)
            return None

        # Group / channel member: leave + hide
        conn.execute(
            "DELETE FROM room_members WHERE room_id = ? AND user_id = ?",
            (room_id, user["id"]),
        )
        _hide_room(conn, user["id"], room_id)
        remaining = conn.execute(
            "SELECT COUNT(*) AS c FROM room_members WHERE room_id = ?",
            (room_id,),
        ).fetchone()["c"]
        if remaining == 0:
            conn.execute("DELETE FROM rooms WHERE id = ?", (room_id,))
        return None


@router.get("/rooms/{room_id}/history", response_model=list[MessageOut])
def room_history(
    room_id: int,
    user: CurrentUser,
    after: int = Query(default=0, ge=0),
    limit: int = Query(default=100, ge=1, le=500),
) -> list[MessageOut]:
    with get_db() as conn:
        if not _is_member(conn, room_id, user["id"]):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a room member")
        rows = conn.execute(
            """
            SELECT m.*, u.display_name AS sender_display_name, u.avatar_path AS sender_avatar_path
            FROM messages m
            LEFT JOIN users u ON u.id = m.sender_id
            WHERE m.room_id = ? AND m.id > ?
            ORDER BY m.id ASC
            LIMIT ?
            """,
            (room_id, after, limit),
        ).fetchall()
        return [MessageOut(**_serialize_message(conn, dict(r))) for r in rows]


@router.post("/rooms/{room_id}/media")
async def upload_chat_media(
    room_id: int,
    user: CurrentUser,
    file: UploadFile = File(...),
) -> dict:
    from routes.upload import save_chat_attachment

    with get_db() as conn:
        if not _is_member(conn, room_id, user["id"]):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a room member")
        _assert_can_post(conn, room_id, user["id"])
    result = await save_chat_attachment(file)
    with get_db() as conn:
        register_upload(
            conn,
            media_path=result["media_path"],
            user_id=user["id"],
            room_id=room_id,
        )
    return result


@router.post("/rooms/{room_id}/ws-ticket")
def issue_ws_ticket(room_id: int, user: CurrentUser) -> dict:
    """Short-lived ticket for WebSocket auth (avoids putting JWT in query strings)."""
    with get_db() as conn:
        if not _is_member(conn, room_id, user["id"]):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a room member")
    ticket = create_ws_ticket(user_id=user["id"], room_id=room_id)
    return {"ticket": ticket, "expires_in": 120}


@router.delete("/rooms/{room_id}/messages/{message_id}")
async def delete_message(room_id: int, message_id: int, user: CurrentUser) -> dict:
    with get_db() as conn:
        if not _is_member(conn, room_id, user["id"]):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a room member")
        row = conn.execute(
            "SELECT * FROM messages WHERE id = ? AND room_id = ?",
            (message_id, room_id),
        ).fetchone()
        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Message not found")
        if row["sender_id"] != user["id"]:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Can only delete your messages")
        media_path = row["media_path"] or row["image_path"]
        conn.execute(
            "UPDATE messages SET deleted_at = datetime('now'), content = NULL, media_path = NULL, image_path = NULL, file_name = NULL WHERE id = ?",
            (message_id,),
        )
        delete_media_file_if_orphaned(conn, media_path)
        updated = _fetch_message(conn, message_id)
        assert updated is not None
        payload = _serialize_message(conn, updated)
    await manager.broadcast(room_id, {"type": "message_deleted", **payload})
    return payload


@router.post("/rooms/{room_id}/messages/{message_id}/forward", response_model=MessageOut)
async def forward_message(
    room_id: int,
    message_id: int,
    body: ForwardRequest,
    user: CurrentUser,
) -> MessageOut:
    with get_db() as conn:
        if not _is_member(conn, room_id, user["id"]):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a room member")
        if not _is_member(conn, body.to_room_id, user["id"]):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a member of target room")
        _assert_can_post(conn, body.to_room_id, user["id"])
        src = conn.execute(
            "SELECT * FROM messages WHERE id = ? AND room_id = ?",
            (message_id, room_id),
        ).fetchone()
        if not src or src["deleted_at"]:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Message not found")
        s = dict(src)
        media_path = s.get("media_path") or s.get("image_path")
        media_type = s.get("media_type") or ("image" if s.get("image_path") else None)
        if media_path:
            try:
                media_path = normalize_media_path(media_path)
            except HTTPException:
                media_path = None
        cur = conn.execute(
            """
            INSERT INTO messages (
                room_id, sender_id, content, image_path, media_path, media_type, file_name, forwarded_from_id
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                body.to_room_id,
                user["id"],
                clamp_message_content(s.get("content")),
                media_path if media_type == "image" else None,
                media_path,
                media_type,
                s.get("file_name"),
                message_id,
            ),
        )
        new_id = cur.lastrowid
        if media_path:
            register_upload(
                conn,
                media_path=media_path,
                user_id=user["id"],
                room_id=body.to_room_id,
            )
        _save_mentions(conn, new_id, s.get("content"))
        created = _fetch_message(conn, new_id)
        assert created is not None
        payload = _serialize_message(conn, created)
    await manager.broadcast(body.to_room_id, payload)
    return MessageOut(**payload)


@router.websocket("/ws/{room_id}")
async def ws_endpoint(
    ws: WebSocket,
    room_id: int,
    ticket: str | None = Query(default=None),
    token: str | None = Query(default=None),
    last_id: int = Query(default=0, ge=0),
) -> None:
    try:
        if ticket:
            user_id = verify_ws_ticket(ticket, room_id=room_id)
            with get_db() as conn:
                row = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
            user = row_to_dict(row)
            if not user:
                await ws.close(code=4401)
                return
        elif token:
            # Legacy fallback — prefer short-lived ?ticket=
            user = verify_jwt_token(token)
        else:
            await ws.close(code=4401)
            return
    except HTTPException:
        await ws.close(code=4401)
        return

    with get_db() as conn:
        if not _is_member(conn, room_id, user["id"]):
            await ws.close(code=4403)
            return

    await ws.accept()
    await manager.connect(ws, room_id, user["id"])

    # Resync + mark delivered for messages from others
    delivered_ids: list[int] = []
    with get_db() as conn:
        missed = conn.execute(
            """
            SELECT m.*, u.display_name AS sender_display_name, u.avatar_path AS sender_avatar_path
            FROM messages m
            LEFT JOIN users u ON u.id = m.sender_id
            WHERE m.room_id = ? AND m.id > ?
            ORDER BY m.id ASC
            """,
            (room_id, last_id),
        ).fetchall()
        payloads = []
        for m in missed:
            d = dict(m)
            payloads.append(_serialize_message(conn, d))
            if d["sender_id"] != user["id"] and not d.get("deleted_at"):
                delivered_ids.extend(_mark_delivered(conn, [d["id"]], user["id"]))
    for payload in payloads:
        await ws.send_json(payload)
    await _broadcast_receipt_updates(room_id, delivered_ids)

    # Presence: mark online + send room snapshot
    went_online = await presence.user_connected(user["id"])
    if went_online:
        await presence.broadcast_presence(user["id"], went_online=True)
    # Tell this socket who is currently online in the room
    with get_db() as conn:
        member_ids = [
            r["user_id"]
            for r in conn.execute(
                "SELECT user_id FROM room_members WHERE room_id = ?",
                (room_id,),
            ).fetchall()
        ]
    for mid in member_ids:
        await ws.send_json(presence.payload_for(mid))

    try:
        while True:
            data = await ws.receive_json()
            msg_type = data.get("type", "message")

            if msg_type == "typing":
                await manager.broadcast(
                    room_id,
                    {"type": "typing", "room_id": room_id, "user_id": user["id"]},
                )
                continue

            if msg_type == "delivered":
                ids = [int(x) for x in (data.get("message_ids") or []) if x]
                with get_db() as conn:
                    touched = _mark_delivered(conn, ids, user["id"])
                await _broadcast_receipt_updates(room_id, touched)
                continue

            if msg_type == "read":
                up_to = int(data.get("up_to_id") or 0)
                if up_to <= 0:
                    continue
                with get_db() as conn:
                    touched = _mark_read_up_to(conn, room_id, up_to, user["id"])
                await _broadcast_receipt_updates(room_id, touched)
                continue

            if msg_type == "delete":
                mid = data.get("message_id")
                if not mid:
                    continue
                with get_db() as conn:
                    row = conn.execute(
                        "SELECT * FROM messages WHERE id = ? AND room_id = ?",
                        (mid, room_id),
                    ).fetchone()
                    if not row or row["sender_id"] != user["id"]:
                        continue
                    media_path = row["media_path"] or row["image_path"]
                    conn.execute(
                        """
                        UPDATE messages
                        SET deleted_at = datetime('now'), content = NULL,
                            media_path = NULL, image_path = NULL, file_name = NULL
                        WHERE id = ?
                        """,
                        (mid,),
                    )
                    delete_media_file_if_orphaned(conn, media_path)
                    updated = _fetch_message(conn, mid)
                    payload = _serialize_message(conn, updated) if updated else None
                if payload:
                    await manager.broadcast(room_id, {"type": "message_deleted", **payload})
                continue

            content = clamp_message_content(data.get("content"))
            raw_media = data.get("media_path") or data.get("image_path")
            media_type = data.get("media_type")
            file_name = data.get("file_name")
            reply_to_id = data.get("reply_to_id")
            media_path = None
            if raw_media:
                # Validate against upload registry (blocks IDOR / absolute URLs)
                with get_db() as conn:
                    if not _can_post(conn, room_id, user["id"]):
                        await ws.send_json(
                            {
                                "type": "error",
                                "detail": "Only channel admins can post messages",
                            }
                        )
                        continue
                    try:
                        media_path = assert_upload_usable(
                            conn,
                            media_path=str(raw_media),
                            user_id=user["id"],
                            room_id=room_id,
                        )
                    except HTTPException as exc:
                        await ws.send_json({"type": "error", "detail": exc.detail})
                        continue
            if media_path and not media_type:
                media_type = "image"
            if not content and not media_path:
                continue

            with get_db() as conn:
                if not _can_post(conn, room_id, user["id"]):
                    await ws.send_json(
                        {
                            "type": "error",
                            "detail": "Only channel admins can post messages",
                        }
                    )
                    continue
                if reply_to_id:
                    parent = conn.execute(
                        "SELECT id FROM messages WHERE id = ? AND room_id = ?",
                        (reply_to_id, room_id),
                    ).fetchone()
                    if not parent:
                        reply_to_id = None
                cur = conn.execute(
                    """
                    INSERT INTO messages (
                        room_id, sender_id, content, image_path, media_path, media_type, file_name, reply_to_id
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        room_id,
                        user["id"],
                        content,
                        media_path if media_type == "image" else None,
                        media_path,
                        media_type,
                        file_name,
                        reply_to_id,
                    ),
                )
                msg_id = cur.lastrowid
                _save_mentions(conn, msg_id, content)
                row = _fetch_message(conn, msg_id)
                payload = _serialize_message(conn, row) if row else None
            if payload:
                await manager.broadcast(room_id, payload)
    except WebSocketDisconnect:
        manager.disconnect(ws, room_id)
        if await presence.user_disconnected(user["id"]):
            await presence.broadcast_presence(user["id"], went_online=False)
    except Exception:
        manager.disconnect(ws, room_id)
        if await presence.user_disconnected(user["id"]):
            await presence.broadcast_presence(user["id"], went_online=False)
        try:
            await ws.close()
        except Exception:
            pass
