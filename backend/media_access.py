"""Media path validation, upload registry, signed WS tickets, file cleanup."""

from __future__ import annotations

import hashlib
import hmac
import secrets
import time
from pathlib import Path

from fastapi import HTTPException, status

from config import get_settings

MAX_MESSAGE_CONTENT_CHARS = 8000

# Chat generic attachments — block executable / active content types.
ALLOWED_FILE_EXTS = frozenset(
    {
        ".pdf",
        ".txt",
        ".csv",
        ".json",
        ".zip",
        ".doc",
        ".docx",
        ".xls",
        ".xlsx",
        ".ppt",
        ".pptx",
        ".md",
        ".rtf",
        ".odt",
        ".ods",
    }
)
BLOCKED_FILE_EXTS = frozenset(
    {
        ".html",
        ".htm",
        ".svg",
        ".xhtml",
        ".js",
        ".mjs",
        ".exe",
        ".bat",
        ".cmd",
        ".ps1",
        ".sh",
        ".php",
        ".asp",
        ".aspx",
        ".jsp",
        ".wasm",
        ".dll",
        ".so",
        ".apk",
        ".msi",
        ".scr",
        ".vbs",
        ".wsf",
    }
)


def normalize_media_path(raw: str | None) -> str | None:
    """Return a safe relative media path or None. Rejects absolute URLs and traversal."""
    if raw is None:
        return None
    value = str(raw).strip().replace("\\", "/")
    if not value:
        return None
    lower = value.lower()
    if lower.startswith("http://") or lower.startswith("https://") or lower.startswith("file:"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Absolute media URLs are not allowed",
        )
    if value.startswith("/"):
        value = value.lstrip("/")
    if value.startswith("media/"):
        value = value[len("media/") :]
    parts = [p for p in value.split("/") if p and p != "."]
    if ".." in parts or not parts:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid media path")
    if len(parts) < 2:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid media path")
    category = parts[0]
    if category not in {"avatars", "banners", "chat", "posts", "stories", "rooms"}:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid media category")
    return "/".join(parts)


def media_disk_path(rel_path: str) -> Path:
    root = Path(get_settings().media_root).resolve()
    full = (root / rel_path).resolve()
    if not str(full).startswith(str(root)):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid media path")
    return full


def register_upload(conn, *, media_path: str, user_id: int, room_id: int | None) -> None:
    path = normalize_media_path(media_path)
    assert path is not None
    conn.execute(
        """
        INSERT INTO media_uploads (media_path, user_id, room_id, created_at)
        VALUES (?, ?, ?, datetime('now'))
        ON CONFLICT(media_path) DO UPDATE SET
          user_id = excluded.user_id,
          room_id = excluded.room_id,
          created_at = excluded.created_at
        """,
        (path, user_id, room_id),
    )


def assert_upload_usable(conn, *, media_path: str, user_id: int, room_id: int) -> str:
    """Ensure media_path was uploaded by this user for this room (or unscoped)."""
    path = normalize_media_path(media_path)
    assert path is not None
    row = conn.execute(
        """
        SELECT user_id, room_id FROM media_uploads WHERE media_path = ?
        """,
        (path,),
    ).fetchone()
    if not row:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unknown media_path — upload the file first",
        )
    if int(row["user_id"]) != int(user_id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="media_path not owned by you")
    uploaded_room = row["room_id"]
    if uploaded_room is not None and int(uploaded_room) != int(room_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="media_path was uploaded for a different room",
        )
    return path


def user_can_access_media(conn, *, rel_path: str, user_id: int) -> bool:
    path = normalize_media_path(rel_path)
    if path is None:
        return False
    category = path.split("/", 1)[0]
    if category in {"avatars", "banners", "posts", "stories", "rooms"}:
        return True
    if category != "chat":
        return False
    # Owner of the upload
    owned = conn.execute(
        "SELECT 1 FROM media_uploads WHERE media_path = ? AND user_id = ?",
        (path, user_id),
    ).fetchone()
    if owned:
        return True
    # Member of a room that still references this media
    row = conn.execute(
        """
        SELECT 1 FROM messages m
        JOIN room_members rm ON rm.room_id = m.room_id AND rm.user_id = ?
        WHERE m.deleted_at IS NULL
          AND (m.media_path = ? OR m.image_path = ?)
        LIMIT 1
        """,
        (user_id, path, path),
    ).fetchone()
    if row:
        return True
    # Member of the room it was uploaded for (pre-send / pending)
    pending = conn.execute(
        """
        SELECT 1 FROM media_uploads u
        JOIN room_members rm ON rm.room_id = u.room_id AND rm.user_id = ?
        WHERE u.media_path = ?
        LIMIT 1
        """,
        (user_id, path),
    ).fetchone()
    return bool(pending)


def delete_media_file_if_orphaned(conn, rel_path: str | None) -> None:
    if not rel_path:
        return
    try:
        path = normalize_media_path(rel_path)
    except HTTPException:
        return
    if path is None:
        return
    still = conn.execute(
        """
        SELECT 1 FROM messages
        WHERE deleted_at IS NULL AND (media_path = ? OR image_path = ?)
        LIMIT 1
        """,
        (path, path),
    ).fetchone()
    if still:
        return
    # Keep profile/post/story assets unless explicitly cleared by those routes
    if not path.startswith("chat/"):
        return
    disk = media_disk_path(path)
    try:
        if disk.is_file():
            disk.unlink()
    except OSError:
        pass
    conn.execute("DELETE FROM media_uploads WHERE media_path = ?", (path,))


def new_invite_token() -> str:
    return secrets.token_urlsafe(18)


def create_ws_ticket(*, user_id: int, room_id: int, ttl_seconds: int = 120) -> str:
    exp = int(time.time()) + ttl_seconds
    payload = f"{user_id}:{room_id}:{exp}"
    sig = hmac.new(
        get_settings().jwt_secret.encode("utf-8"),
        payload.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()
    return f"{user_id}.{room_id}.{exp}.{sig}"


def verify_ws_ticket(ticket: str, *, room_id: int) -> int:
    """Return user_id if ticket is valid for room_id."""
    try:
        uid_s, rid_s, exp_s, sig = ticket.split(".", 3)
        user_id = int(uid_s)
        ticket_room = int(rid_s)
        exp = int(exp_s)
    except (ValueError, AttributeError) as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid WS ticket") from exc
    if ticket_room != room_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="WS ticket room mismatch")
    if exp < int(time.time()):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="WS ticket expired")
    payload = f"{user_id}:{ticket_room}:{exp}"
    expected = hmac.new(
        get_settings().jwt_secret.encode("utf-8"),
        payload.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()
    if not hmac.compare_digest(expected, sig):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid WS ticket")
    return user_id


def clamp_message_content(content: str | None) -> str | None:
    if content is None:
        return None
    text = str(content)
    if len(text) > MAX_MESSAGE_CONTENT_CHARS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Message too long (max {MAX_MESSAGE_CONTENT_CHARS} characters)",
        )
    return text
