"""User profile routes."""

from __future__ import annotations

from fastapi import APIRouter, File, HTTPException, UploadFile, status

from auth import CurrentUser
from db import get_db, row_to_dict
from models import UserPublic, UserUpdate
from routes.upload import save_image

router = APIRouter(tags=["users"])


def _public(user: dict) -> UserPublic:
    return UserPublic(
        id=user["id"],
        username=user["username"],
        display_name=user["display_name"],
        bio=user.get("bio") or "",
        avatar_path=user.get("avatar_path"),
        created_at=user.get("created_at"),
    )


@router.get("/me", response_model=UserPublic)
def get_me(user: CurrentUser) -> UserPublic:
    return _public(user)


@router.patch("/me", response_model=UserPublic)
def patch_me_json(user: CurrentUser, body: UserUpdate) -> UserPublic:
    """Update display_name / bio via JSON."""
    updates: list[str] = []
    params: list = []
    if body.display_name is not None:
        updates.append("display_name = ?")
        params.append(body.display_name)
    if body.bio is not None:
        updates.append("bio = ?")
        params.append(body.bio)
    if not updates:
        return _public(user)
    params.append(user["id"])
    with get_db() as conn:
        conn.execute(f"UPDATE users SET {', '.join(updates)} WHERE id = ?", params)
        row = conn.execute("SELECT * FROM users WHERE id = ?", (user["id"],)).fetchone()
    updated = row_to_dict(row)
    assert updated is not None
    return _public(updated)


@router.post("/me/avatar", response_model=UserPublic)
async def upload_avatar(user: CurrentUser, avatar: UploadFile = File(...)) -> UserPublic:
    rel, _w, _h = await save_image(avatar, "avatars")
    with get_db() as conn:
        conn.execute("UPDATE users SET avatar_path = ? WHERE id = ?", (rel, user["id"]))
        row = conn.execute("SELECT * FROM users WHERE id = ?", (user["id"],)).fetchone()
    updated = row_to_dict(row)
    assert updated is not None
    return _public(updated)


@router.get("/users/{user_id}", response_model=UserPublic)
def get_user(user_id: int, _user: CurrentUser) -> UserPublic:
    with get_db() as conn:
        row = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    found = row_to_dict(row)
    if not found:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return _public(found)


@router.get("/users", response_model=list[UserPublic])
def list_users(_user: CurrentUser) -> list[UserPublic]:
    with get_db() as conn:
        rows = conn.execute(
            "SELECT id, username, display_name, bio, avatar_path, created_at FROM users ORDER BY display_name"
        ).fetchall()
    return [_public(dict(r)) for r in rows]
