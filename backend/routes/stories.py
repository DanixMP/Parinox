"""Stories routes — 24h-expiring media."""

from __future__ import annotations

from fastapi import APIRouter, File, Form, HTTPException, UploadFile, status

from auth import CurrentUser
from db import execute, fetchall, fetchone
from routes.upload import save_image

router = APIRouter(tags=["stories"])


@router.get("/stories")
def list_stories(user: CurrentUser) -> list[dict]:
    """Active stories grouped by user, each with viewed flag for current user."""
    rows = fetchall(
        "SELECT s.id, s.user_id, s.media_path, s.is_video, s.created_at, s.expires_at, "
        "u.username, u.display_name, u.avatar_path, "
        "CASE WHEN sv.user_id IS NULL THEN 0 ELSE 1 END AS viewed "
        "FROM stories s "
        "JOIN users u ON u.id = s.user_id "
        "LEFT JOIN story_views sv ON sv.story_id = s.id AND sv.user_id = ? "
        "WHERE s.expires_at > datetime('now') "
        "ORDER BY s.user_id, s.id ASC",
        (user["id"],),
    )
    grouped: dict[int, dict] = {}
    order: list[int] = []
    for row in rows:
        uid = row["user_id"]
        if uid not in grouped:
            grouped[uid] = {
                "user_id": uid,
                "username": row["username"],
                "display_name": row["display_name"],
                "avatar_path": row["avatar_path"],
                "has_unseen": False,
                "stories": [],
            }
            order.append(uid)
        story = {
            "id": row["id"],
            "media_path": row["media_path"],
            "is_video": bool(row["is_video"]),
            "created_at": row["created_at"],
            "expires_at": row["expires_at"],
            "viewed": bool(row["viewed"]),
        }
        if not story["viewed"]:
            grouped[uid]["has_unseen"] = True
        grouped[uid]["stories"].append(story)

    # Unseen first, then seen
    order.sort(key=lambda uid: (0 if grouped[uid]["has_unseen"] else 1, uid))
    return [grouped[uid] for uid in order]


@router.post("/stories", status_code=status.HTTP_201_CREATED)
async def create_story(
    user: CurrentUser,
    media: UploadFile = File(...),
    is_video: bool = Form(default=False),
) -> dict:
    if is_video:
        # Phase 5 will expand video handling; for now accept image pipeline only
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Video stories not yet supported; upload an image",
        )
    rel, _, _ = await save_image(media, "stories")
    story_id = execute(
        "INSERT INTO stories (user_id, media_path, is_video, expires_at) "
        "VALUES (?, ?, 0, datetime('now', '+24 hours'))",
        (user["id"], rel),
    )
    row = fetchone("SELECT * FROM stories WHERE id = ?", (story_id,))
    assert row is not None
    return dict(row)


@router.post("/stories/{story_id}/view")
def view_story(story_id: int, user: CurrentUser) -> dict:
    row = fetchone(
        "SELECT id FROM stories WHERE id = ? AND expires_at > datetime('now')",
        (story_id,),
    )
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Story not found")
    existing = fetchone(
        "SELECT 1 FROM story_views WHERE story_id = ? AND user_id = ?",
        (story_id, user["id"]),
    )
    if existing is None:
        execute(
            "INSERT INTO story_views (story_id, user_id) VALUES (?, ?)",
            (story_id, user["id"]),
        )
    return {"story_id": story_id, "viewed": True}
