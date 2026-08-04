"""User profile routes."""

from __future__ import annotations

from fastapi import APIRouter, File, Form, HTTPException, UploadFile, status

from auth import CurrentUser
from db import execute, fetchall, fetchone
from models import UserPublic
from routes.upload import save_image

router = APIRouter(tags=["users"])


@router.get("/me", response_model=UserPublic)
def get_me(user: CurrentUser) -> UserPublic:
    return UserPublic(**user)


@router.patch("/me", response_model=UserPublic)
async def patch_me(
    user: CurrentUser,
    display_name: str | None = Form(default=None),
    bio: str | None = Form(default=None),
    avatar: UploadFile | None = File(default=None),
) -> UserPublic:
    if display_name is None and bio is None and avatar is None:
        return UserPublic(**user)

    avatar_path = None
    if avatar is not None:
        avatar_path, _, _ = await save_image(avatar, "avatars")

    execute(
        "UPDATE users SET "
        "display_name = COALESCE(?, display_name), "
        "bio = COALESCE(?, bio), "
        "avatar_path = COALESCE(?, avatar_path) "
        "WHERE id = ?",
        (display_name, bio, avatar_path, user["id"]),
    )
    updated = fetchone(
        "SELECT id, username, display_name, bio, avatar_path, created_at FROM users WHERE id = ?",
        (user["id"],),
    )
    assert updated is not None
    return UserPublic(**dict(updated))


@router.get("/users/{user_id}", response_model=UserPublic)
def get_user(user_id: int, _user: CurrentUser) -> UserPublic:
    row = fetchone(
        "SELECT id, username, display_name, bio, avatar_path, created_at FROM users WHERE id = ?",
        (user_id,),
    )
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return UserPublic(**dict(row))


@router.get("/users/{user_id}/posts")
def get_user_posts(user_id: int, _user: CurrentUser) -> list[dict]:
    rows = fetchall(
        "SELECT id, user_id, caption, image_path, width, height, created_at "
        "FROM posts WHERE user_id = ? ORDER BY id DESC",
        (user_id,),
    )
    return [dict(r) for r in rows]
