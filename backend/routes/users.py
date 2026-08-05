"""User profile routes — /me, avatar, public profile + posts grid."""

from __future__ import annotations

from fastapi import APIRouter, File, HTTPException, Query, UploadFile, status

from presence import presence
from auth import CurrentUser
from db import get_db, row_to_dict
from models import PostSummary, ProfileOut, UserPublic, UserUpdate
from routes.upload import save_image

router = APIRouter(tags=["users"])


def _public(user: dict, *, include_recovery: bool = False) -> UserPublic:
    uid = user["id"]
    return UserPublic(
        id=uid,
        username=user["username"],
        display_name=user["display_name"],
        bio=user.get("bio") or "",
        avatar_path=user.get("avatar_path"),
        banner_path=user.get("banner_path"),
        email=user.get("email") if include_recovery else None,
        phone=user.get("phone") if include_recovery else None,
        created_at=user.get("created_at"),
        is_online=presence.is_online(uid),
        last_seen_at=None if presence.is_online(uid) else user.get("last_seen_at"),
    )


def _profile_with_posts(conn, user_row: dict, *, post_limit: int = 60) -> ProfileOut:
    posts = conn.execute(
        """
        SELECT p.*,
               (SELECT COUNT(*) FROM post_likes pl WHERE pl.post_id = p.id) AS like_count,
               (SELECT COUNT(*) FROM post_comments pc WHERE pc.post_id = p.id) AS comment_count
        FROM posts p
        WHERE p.user_id = ?
        ORDER BY p.id DESC
        LIMIT ?
        """,
        (user_row["id"], post_limit),
    ).fetchall()
    total = conn.execute(
        "SELECT COUNT(*) AS c FROM posts WHERE user_id = ?",
        (user_row["id"],),
    ).fetchone()["c"]
    uid = user_row["id"]
    return ProfileOut(
        id=uid,
        username=user_row["username"],
        display_name=user_row["display_name"],
        bio=user_row.get("bio") or "",
        avatar_path=user_row.get("avatar_path"),
        banner_path=user_row.get("banner_path"),
        created_at=user_row.get("created_at"),
        post_count=total,
        is_online=presence.is_online(uid),
        last_seen_at=None if presence.is_online(uid) else user_row.get("last_seen_at"),
        posts=[
            PostSummary(
                id=p["id"],
                user_id=p["user_id"],
                caption=p["caption"] or "",
                image_path=p["image_path"],
                width=p["width"],
                height=p["height"],
                created_at=p["created_at"],
                like_count=p["like_count"],
                comment_count=p["comment_count"],
            )
            for p in posts
        ],
    )


@router.get("/me", response_model=UserPublic)
def get_me(user: CurrentUser) -> UserPublic:
    return _public(user, include_recovery=True)


@router.get("/me/profile", response_model=ProfileOut)
def get_my_profile(user: CurrentUser) -> ProfileOut:
    with get_db() as conn:
        row = conn.execute("SELECT * FROM users WHERE id = ?", (user["id"],)).fetchone()
        assert row is not None
        return _profile_with_posts(conn, dict(row))


@router.patch("/me", response_model=UserPublic)
def patch_me_json(user: CurrentUser, body: UserUpdate) -> UserPublic:
    """Update display_name / bio via JSON."""
    updates: list[str] = []
    params: list = []
    if body.display_name is not None:
        name = body.display_name.strip()
        if not name:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="display_name required")
        updates.append("display_name = ?")
        params.append(name)
    if body.bio is not None:
        updates.append("bio = ?")
        params.append(body.bio.strip())
    if not updates:
        return _public(user, include_recovery=True)
    params.append(user["id"])
    with get_db() as conn:
        conn.execute(f"UPDATE users SET {', '.join(updates)} WHERE id = ?", params)
        row = conn.execute("SELECT * FROM users WHERE id = ?", (user["id"],)).fetchone()
    updated = row_to_dict(row)
    assert updated is not None
    return _public(updated, include_recovery=True)


@router.post("/me/avatar", response_model=UserPublic)
async def upload_avatar(user: CurrentUser, avatar: UploadFile = File(...)) -> UserPublic:
    rel, _w, _h = await save_image(avatar, "avatars")
    with get_db() as conn:
        # Best-effort cleanup of previous avatar file is skipped — keep it simple at this scale
        conn.execute("UPDATE users SET avatar_path = ? WHERE id = ?", (rel, user["id"]))
        row = conn.execute("SELECT * FROM users WHERE id = ?", (user["id"],)).fetchone()
    updated = row_to_dict(row)
    assert updated is not None
    return _public(updated, include_recovery=True)


@router.delete("/me/avatar", response_model=UserPublic)
def clear_avatar(user: CurrentUser) -> UserPublic:
    with get_db() as conn:
        conn.execute("UPDATE users SET avatar_path = NULL WHERE id = ?", (user["id"],))
        row = conn.execute("SELECT * FROM users WHERE id = ?", (user["id"],)).fetchone()
    updated = row_to_dict(row)
    assert updated is not None
    return _public(updated, include_recovery=True)


@router.post("/me/banner", response_model=UserPublic)
async def upload_banner(user: CurrentUser, banner: UploadFile = File(...)) -> UserPublic:
    rel, _w, _h = await save_image(banner, "banners")
    with get_db() as conn:
        conn.execute("UPDATE users SET banner_path = ? WHERE id = ?", (rel, user["id"]))
        row = conn.execute("SELECT * FROM users WHERE id = ?", (user["id"],)).fetchone()
    updated = row_to_dict(row)
    assert updated is not None
    return _public(updated, include_recovery=True)


@router.delete("/me/banner", response_model=UserPublic)
def clear_banner(user: CurrentUser) -> UserPublic:
    with get_db() as conn:
        conn.execute("UPDATE users SET banner_path = NULL WHERE id = ?", (user["id"],))
        row = conn.execute("SELECT * FROM users WHERE id = ?", (user["id"],)).fetchone()
    updated = row_to_dict(row)
    assert updated is not None
    return _public(updated, include_recovery=True)


@router.get("/users/{user_id}", response_model=ProfileOut)
def get_user_profile(
    user_id: int,
    _user: CurrentUser,
    post_limit: int = Query(default=60, ge=1, le=200),
) -> ProfileOut:
    """Public profile + their posts (DESIGN endpoint)."""
    with get_db() as conn:
        row = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
        return _profile_with_posts(conn, dict(row), post_limit=post_limit)


@router.get("/users", response_model=list[UserPublic])
def list_users(_user: CurrentUser) -> list[UserPublic]:
    with get_db() as conn:
        rows = conn.execute(
            "SELECT id, username, display_name, bio, avatar_path, created_at FROM users ORDER BY display_name"
        ).fetchall()
    return [_public(dict(r)) for r in rows]
