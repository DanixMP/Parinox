"""Chat rooms, history, and WebSocket with resync protocol."""

from __future__ import annotations

from typing import Any

from fastapi import (
    APIRouter,
    File,
    Form,
    HTTPException,
    Query,
    UploadFile,
    WebSocket,
    WebSocketDisconnect,
    status,
)

from auth import CurrentUser, verify_jwt_token
from db import execute, fetchall, fetchone
from models import MessageOut, RoomCreate, RoomOut
from routes.upload import save_image
from ws_manager import manager

router = APIRouter(tags=["chat"])


def _serialize_message(row: Any) -> dict[str, Any]:
    data = dict(row)
    return MessageOut(
        id=data["id"],
        room_id=data["room_id"],
        sender_id=data["sender_id"],
        content=data.get("content"),
        image_path=data.get("image_path"),
        created_at=data.get("created_at"),
        sender_username=data.get("sender_username"),
        sender_display_name=data.get("sender_display_name"),
    ).model_dump()


def _user_in_room(room_id: int, user_id: int) -> bool:
    row = fetchone(
        "SELECT 1 FROM room_members WHERE room_id = ? AND user_id = ?",
        (room_id, user_id),
    )
    return row is not None


def _get_room_member_ids(room_id: int) -> list[int]:
    rows = fetchall(
        "SELECT user_id FROM room_members WHERE room_id = ? ORDER BY user_id",
        (room_id,),
    )
    return [int(r["user_id"]) for r in rows]


@router.get("/rooms", response_model=list[RoomOut])
def list_rooms(user: CurrentUser) -> list[RoomOut]:
    rows = fetchall(
        "SELECT r.id, r.name, r.is_dm, r.created_at "
        "FROM rooms r "
        "JOIN room_members m ON m.room_id = r.id "
        "WHERE m.user_id = ? "
        "ORDER BY r.id DESC",
        (user["id"],),
    )
    result: list[RoomOut] = []
    for row in rows:
        result.append(
            RoomOut(
                id=row["id"],
                name=row["name"],
                is_dm=bool(row["is_dm"]),
                created_at=row["created_at"],
                member_ids=_get_room_member_ids(row["id"]),
            )
        )
    return result


@router.post("/rooms", response_model=RoomOut, status_code=status.HTTP_201_CREATED)
def create_room(body: RoomCreate, user: CurrentUser) -> RoomOut:
    member_ids = set(body.member_ids)
    member_ids.add(user["id"])

    if body.is_dm:
        if len(member_ids) != 2:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="DM rooms require exactly two members",
            )
        # Reuse existing DM if present
        a, b = sorted(member_ids)
        existing = fetchone(
            "SELECT r.id, r.name, r.is_dm, r.created_at FROM rooms r "
            "JOIN room_members m1 ON m1.room_id = r.id AND m1.user_id = ? "
            "JOIN room_members m2 ON m2.room_id = r.id AND m2.user_id = ? "
            "WHERE r.is_dm = 1",
            (a, b),
        )
        if existing is not None:
            return RoomOut(
                id=existing["id"],
                name=existing["name"],
                is_dm=True,
                created_at=existing["created_at"],
                member_ids=_get_room_member_ids(existing["id"]),
            )

    for mid in member_ids:
        if fetchone("SELECT id FROM users WHERE id = ?", (mid,)) is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Unknown member id: {mid}",
            )

    room_id = execute(
        "INSERT INTO rooms (name, is_dm) VALUES (?, ?)",
        (body.name, 1 if body.is_dm else 0),
    )
    for mid in sorted(member_ids):
        execute(
            "INSERT INTO room_members (room_id, user_id) VALUES (?, ?)",
            (room_id, mid),
        )
    row = fetchone(
        "SELECT id, name, is_dm, created_at FROM rooms WHERE id = ?",
        (room_id,),
    )
    assert row is not None
    return RoomOut(
        id=row["id"],
        name=row["name"],
        is_dm=bool(row["is_dm"]),
        created_at=row["created_at"],
        member_ids=_get_room_member_ids(room_id),
    )


@router.get("/rooms/{room_id}/history", response_model=list[MessageOut])
def room_history(
    room_id: int,
    user: CurrentUser,
    after: int = Query(default=0, ge=0),
    limit: int = Query(default=100, ge=1, le=500),
) -> list[MessageOut]:
    if not _user_in_room(room_id, user["id"]):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a room member")

    rows = fetchall(
        "SELECT m.id, m.room_id, m.sender_id, m.content, m.image_path, m.created_at, "
        "u.username AS sender_username, u.display_name AS sender_display_name "
        "FROM messages m "
        "LEFT JOIN users u ON u.id = m.sender_id "
        "WHERE m.room_id = ? AND m.id > ? "
        "ORDER BY m.id ASC LIMIT ?",
        (room_id, after, limit),
    )
    return [MessageOut(**_serialize_message(r)) for r in rows]


@router.post("/rooms/{room_id}/messages", response_model=MessageOut)
async def post_message(
    room_id: int,
    user: CurrentUser,
    content: str | None = Form(default=None),
    image: UploadFile | None = File(default=None),
) -> MessageOut:
    """REST fallback for sending a message (text and/or image)."""
    if not _user_in_room(room_id, user["id"]):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a room member")
    if not content and image is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Empty message")

    image_path = None
    if image is not None:
        image_path, _, _ = await save_image(image, "chat")

    msg_id = execute(
        "INSERT INTO messages (room_id, sender_id, content, image_path) VALUES (?, ?, ?, ?)",
        (room_id, user["id"], content, image_path),
    )
    row = fetchone(
        "SELECT m.id, m.room_id, m.sender_id, m.content, m.image_path, m.created_at, "
        "u.username AS sender_username, u.display_name AS sender_display_name "
        "FROM messages m LEFT JOIN users u ON u.id = m.sender_id WHERE m.id = ?",
        (msg_id,),
    )
    assert row is not None
    payload = _serialize_message(row)
    await manager.broadcast(room_id, {"type": "message", "message": payload})
    return MessageOut(**payload)


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
        await ws.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    if fetchone("SELECT id FROM rooms WHERE id = ?", (room_id,)) is None:
        await ws.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    if not _user_in_room(room_id, user["id"]):
        await ws.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    await ws.accept()
    await manager.connect(ws, room_id, user["id"])

    # Resync: replay everything missed since last_id
    missed = fetchall(
        "SELECT m.id, m.room_id, m.sender_id, m.content, m.image_path, m.created_at, "
        "u.username AS sender_username, u.display_name AS sender_display_name "
        "FROM messages m LEFT JOIN users u ON u.id = m.sender_id "
        "WHERE m.room_id = ? AND m.id > ? ORDER BY m.id ASC",
        (room_id, last_id),
    )
    for row in missed:
        await ws.send_json({"type": "message", "message": _serialize_message(row)})

    await ws.send_json({"type": "resync_complete", "last_id": last_id, "count": len(missed)})

    try:
        while True:
            data = await ws.receive_json()
            msg_type = data.get("type", "message")

            if msg_type == "ping":
                await ws.send_json({"type": "pong"})
                continue

            if msg_type == "typing":
                await manager.broadcast(
                    room_id,
                    {
                        "type": "typing",
                        "user_id": user["id"],
                        "username": user["username"],
                    },
                )
                continue

            content = data.get("content")
            image_path = data.get("image_path")
            if not content and not image_path:
                await ws.send_json({"type": "error", "detail": "Empty message"})
                continue

            msg_id = execute(
                "INSERT INTO messages (room_id, sender_id, content, image_path) "
                "VALUES (?, ?, ?, ?)",
                (room_id, user["id"], content, image_path),
            )
            row = fetchone(
                "SELECT m.id, m.room_id, m.sender_id, m.content, m.image_path, m.created_at, "
                "u.username AS sender_username, u.display_name AS sender_display_name "
                "FROM messages m LEFT JOIN users u ON u.id = m.sender_id WHERE m.id = ?",
                (msg_id,),
            )
            assert row is not None
            payload = {"type": "message", "message": _serialize_message(row)}
            await manager.broadcast(room_id, payload)
    except WebSocketDisconnect:
        await manager.disconnect(ws, room_id)
    except Exception:
        await manager.disconnect(ws, room_id)
        try:
            await ws.close()
        except Exception:
            pass
