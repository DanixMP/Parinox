"""Stories routes — 24h expiry, seen/unseen tracking."""

from __future__ import annotations

from fastapi import APIRouter, File, HTTPException, UploadFile, status
from starlette.responses import Response

from auth import CurrentUser
from db import get_db
from routes.upload import save_media_raw

router = APIRouter(tags=["stories"])


@router.get("/stories")
def list_stories(user: CurrentUser) -> list[dict]:
    """Active stories grouped by user, each with viewed flag for current user."""
    with get_db() as conn:
        rows = conn.execute(
            """
            SELECT s.*, u.display_name, u.username, u.avatar_path,
                   CASE WHEN sv.user_id IS NOT NULL THEN 1 ELSE 0 END AS viewed
            FROM stories s
            JOIN users u ON u.id = s.user_id
            LEFT JOIN story_views sv ON sv.story_id = s.id AND sv.user_id = ?
            WHERE s.expires_at > datetime('now')
            ORDER BY s.user_id, s.created_at ASC
            """,
            (user["id"],),
        ).fetchall()

    grouped: dict[int, dict] = {}
    for r in rows:
        d = dict(r)
        uid = d["user_id"]
        if uid not in grouped:
            grouped[uid] = {
                "user_id": uid,
                "username": d["username"],
                "display_name": d["display_name"],
                "avatar_path": d["avatar_path"],
                "has_unseen": False,
                "stories": [],
            }
        story = {
            "id": d["id"],
            "media_path": d["media_path"],
            "is_video": bool(d["is_video"]),
            "created_at": d["created_at"],
            "expires_at": d["expires_at"],
            "viewed": bool(d["viewed"]),
        }
        if not story["viewed"]:
            grouped[uid]["has_unseen"] = True
        grouped[uid]["stories"].append(story)

    # Unseen rings first, then alphabetical
    result = list(grouped.values())
    result.sort(key=lambda g: (not g["has_unseen"], g["display_name"].lower()))
    return result


@router.post("/stories", status_code=status.HTTP_201_CREATED)
async def create_story(
    user: CurrentUser,
    media: UploadFile = File(...),
) -> dict:
    rel, is_video = await save_media_raw(media, "stories", allow_video=True)
    with get_db() as conn:
        cur = conn.execute(
            """
            INSERT INTO stories (user_id, media_path, is_video, expires_at)
            VALUES (?, ?, ?, datetime('now', '+24 hours'))
            """,
            (user["id"], rel, int(is_video)),
        )
        sid = cur.lastrowid
        row = conn.execute("SELECT * FROM stories WHERE id = ?", (sid,)).fetchone()
    d = dict(row)
    return {
        "id": d["id"],
        "user_id": d["user_id"],
        "media_path": d["media_path"],
        "is_video": bool(d["is_video"]),
        "created_at": d["created_at"],
        "expires_at": d["expires_at"],
        "viewed": False,
        "display_name": user["display_name"],
        "username": user["username"],
    }


@router.delete("/stories/{story_id}", status_code=status.HTTP_204_NO_CONTENT, response_class=Response)
def delete_own_story(story_id: int, user: CurrentUser) -> Response:
    """Allow a user to remove their own active story early."""
    from pathlib import Path

    from config import get_settings

    settings = get_settings()
    with get_db() as conn:
        row = conn.execute(
            "SELECT * FROM stories WHERE id = ? AND user_id = ?",
            (story_id, user["id"]),
        ).fetchone()
        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Story not found")
        conn.execute("DELETE FROM stories WHERE id = ?", (story_id,))
        path = Path(settings.media_root) / row["media_path"]
        try:
            if path.is_file():
                path.unlink()
        except OSError:
            pass
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/stories/{story_id}/view")
def view_story(story_id: int, user: CurrentUser) -> dict:
    with get_db() as conn:
        story = conn.execute(
            "SELECT id FROM stories WHERE id = ? AND expires_at > datetime('now')",
            (story_id,),
        ).fetchone()
        if not story:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Story not found")
        conn.execute(
            """
            INSERT OR IGNORE INTO story_views (story_id, user_id) VALUES (?, ?)
            """,
            (story_id, user["id"]),
        )
    return {"ok": True}
