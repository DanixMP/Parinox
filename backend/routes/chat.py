"""Chat rooms, history, and WebSocket with resync protocol."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, Query, WebSocket, WebSocketDisconnect, status

from auth import CurrentUser, verify_jwt_token
from db import get_db, row_to_dict
from models import MessageOut, RoomCreate, RoomOut, UserPublic
from ws_manager import manager

router = APIRouter(tags=["chat"])


def _user_public(row: dict) -> UserPublic:
    return UserPublic(
        id=row["id"],
        username=row["username"],
        display_name=row["display_name"],
        bio=row.get("bio") or "",
        avatar_path=row.get("avatar_path"),
        created_at=row.get("created_at"),
    )


def _serialize_message(row: dict) -> dict:
    return {
        "id": row["id"],
        "room_id": row["room_id"],
        "sender_id": row["sender_id"],
        "content": row.get("content"),
        "image_path": row.get("image_path"),
        "created_at": row["created_at"],
        "sender_display_name": row.get("sender_display_name"),
        "type": "message",
    }


def _is_member(conn, room_id: int, user_id: int) -> bool:
    row = conn.execute(
        "SELECT 1 FROM room_members WHERE room_id = ? AND user_id = ?",
        (room_id, user_id),
    ).fetchone()
    return row is not None


def _room_with_members(conn, room_id: int) -> RoomOut | None:
    room = conn.execute("SELECT * FROM rooms WHERE id = ?", (room_id,)).fetchone()
    if not room:
        return None
    members = conn.execute(
        """
        SELECT u.id, u.username, u.display_name, u.bio, u.avatar_path, u.created_at
        FROM users u
        JOIN room_members rm ON rm.user_id = u.id
        WHERE rm.room_id = ?
        ORDER BY u.display_name
        """,
        (room_id,),
    ).fetchall()
    return RoomOut(
        id=room["id"],
        name=room["name"],
        is_dm=bool(room["is_dm"]),
        created_at=room["created_at"],
        members=[_user_public(dict(m)) for m in members],
    )


@router.get("/rooms", response_model=list[RoomOut])
def list_rooms(user: CurrentUser) -> list[RoomOut]:
    with get_db() as conn:
        rows = conn.execute(
            """
            SELECT r.id FROM rooms r
            JOIN room_members rm ON rm.room_id = r.id
            WHERE rm.user_id = ?
            ORDER BY r.created_at DESC
            """,
            (user["id"],),
        ).fetchall()
        return [_room_with_members(conn, r["id"]) for r in rows]  # type: ignore[misc]


@router.post("/rooms", response_model=RoomOut, status_code=status.HTTP_201_CREATED)
def create_room(body: RoomCreate, user: CurrentUser) -> RoomOut:
    member_ids = set(body.member_ids) | {user["id"]}

    with get_db() as conn:
        # For DMs: reuse existing 1:1 room if present
        if body.is_dm and len(member_ids) == 2:
            a, b = sorted(member_ids)
            existing = conn.execute(
                """
                SELECT r.id FROM rooms r
                JOIN room_members m1 ON m1.room_id = r.id AND m1.user_id = ?
                JOIN room_members m2 ON m2.room_id = r.id AND m2.user_id = ?
                WHERE r.is_dm = 1
                AND (SELECT COUNT(*) FROM room_members WHERE room_id = r.id) = 2
                LIMIT 1
                """,
                (a, b),
            ).fetchone()
            if existing:
                room = _room_with_members(conn, existing["id"])
                assert room is not None
                return room

        # Validate members exist
        placeholders = ",".join("?" * len(member_ids))
        found = conn.execute(
            f"SELECT id FROM users WHERE id IN ({placeholders})",
            tuple(member_ids),
        ).fetchall()
        if len(found) != len(member_ids):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Unknown member id")

        cur = conn.execute(
            "INSERT INTO rooms (name, is_dm) VALUES (?, ?)",
            (body.name, int(body.is_dm)),
        )
        room_id = cur.lastrowid
        conn.executemany(
            "INSERT INTO room_members (room_id, user_id) VALUES (?, ?)",
            [(room_id, mid) for mid in member_ids],
        )
        room = _room_with_members(conn, room_id)  # type: ignore[arg-type]
        assert room is not None
        return room


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
            SELECT m.*, u.display_name AS sender_display_name
            FROM messages m
            LEFT JOIN users u ON u.id = m.sender_id
            WHERE m.room_id = ? AND m.id > ?
            ORDER BY m.id ASC
            LIMIT ?
            """,
            (room_id, after, limit),
        ).fetchall()
    return [MessageOut(**_serialize_message(dict(r))) for r in rows]


@router.websocket("/ws/{room_id}")
async def ws_endpoint(
    ws: WebSocket,
    room_id: int,
    token: str = Query(...),
    last_id: int = Query(default=0, ge=0),
) -> None:
    # Reject BEFORE accept if invalid — design §5
    try:
        user = verify_jwt_token(token)
    except HTTPException:
        await ws.close(code=4401)
        return

    with get_db() as conn:
        if not _is_member(conn, room_id, user["id"]):
            await ws.close(code=4403)
            return

    await ws.accept()
    await manager.connect(ws, room_id, user["id"])

    # Resync: replay everything the client missed since last_id
    with get_db() as conn:
        missed = conn.execute(
            """
            SELECT m.*, u.display_name AS sender_display_name
            FROM messages m
            LEFT JOIN users u ON u.id = m.sender_id
            WHERE m.room_id = ? AND m.id > ?
            ORDER BY m.id ASC
            """,
            (room_id, last_id),
        ).fetchall()
    for m in missed:
        await ws.send_json(_serialize_message(dict(m)))

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

            content = data.get("content")
            image_path = data.get("image_path")
            if not content and not image_path:
                continue

            with get_db() as conn:
                cur = conn.execute(
                    """
                    INSERT INTO messages (room_id, sender_id, content, image_path)
                    VALUES (?, ?, ?, ?)
                    """,
                    (room_id, user["id"], content, image_path),
                )
                msg_id = cur.lastrowid
                row = conn.execute(
                    """
                    SELECT m.*, u.display_name AS sender_display_name
                    FROM messages m
                    LEFT JOIN users u ON u.id = m.sender_id
                    WHERE m.id = ?
                    """,
                    (msg_id,),
                ).fetchone()
            payload = _serialize_message(dict(row))
            await manager.broadcast(room_id, payload)
    except WebSocketDisconnect:
        manager.disconnect(ws, room_id)
    except Exception:
        manager.disconnect(ws, room_id)
        try:
            await ws.close()
        except Exception:
            pass
