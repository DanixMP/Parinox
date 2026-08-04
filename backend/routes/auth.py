"""Auth routes: login + admin user creation (no public signup)."""

from __future__ import annotations

from fastapi import APIRouter, Header, HTTPException, Request, status

from auth import (
    check_login_rate_limit,
    clear_login_attempts,
    create_access_token,
    hash_password,
    verify_password,
)
from config import get_settings
from db import get_db, row_to_dict
from models import AdminCreateUser, LoginRequest, TokenResponse, UserPublic

router = APIRouter(tags=["auth"])


@router.post("/login", response_model=TokenResponse)
def login(body: LoginRequest, request: Request) -> TokenResponse:
    client = request.client.host if request.client else "unknown"
    rate_key = f"{body.username}:{client}"
    check_login_rate_limit(rate_key)

    with get_db() as conn:
        row = conn.execute("SELECT * FROM users WHERE username = ?", (body.username,)).fetchone()
    user = row_to_dict(row)
    if not user or not verify_password(body.password, user["password_hash"]):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

    clear_login_attempts(rate_key)
    token = create_access_token(user["id"], user["username"])
    return TokenResponse(access_token=token)


@router.post("/admin/users", response_model=UserPublic, status_code=status.HTTP_201_CREATED)
def admin_create_user(
    body: AdminCreateUser,
    x_admin_token: str | None = Header(default=None),
) -> UserPublic:
    settings = get_settings()
    if not x_admin_token or x_admin_token != settings.admin_token:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin token required")

    with get_db() as conn:
        existing = conn.execute("SELECT id FROM users WHERE username = ?", (body.username,)).fetchone()
        if existing:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Username taken")
        cur = conn.execute(
            """
            INSERT INTO users (username, password_hash, display_name, bio, is_admin)
            VALUES (?, ?, ?, ?, ?)
            """,
            (body.username, hash_password(body.password), body.display_name, body.bio, int(body.is_admin)),
        )
        user_id = cur.lastrowid
        row = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()

    user = row_to_dict(row)
    assert user is not None
    return UserPublic(
        id=user["id"],
        username=user["username"],
        display_name=user["display_name"],
        bio=user["bio"] or "",
        avatar_path=user["avatar_path"],
        created_at=user["created_at"],
    )
