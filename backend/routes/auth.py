"""Auth routes: login + admin user creation."""

from __future__ import annotations

from fastapi import APIRouter, Header, HTTPException, Request, status

from auth import (
    check_login_rate_limit,
    create_access_token,
    get_user_auth_row,
    hash_password,
    verify_password,
)
from config import get_settings
from db import execute, fetchone
from models import AdminCreateUser, LoginRequest, TokenResponse, UserPublic

router = APIRouter(tags=["auth"])


@router.post("/login", response_model=TokenResponse)
def login(body: LoginRequest, request: Request) -> TokenResponse:
    client = request.client.host if request.client else "unknown"
    check_login_rate_limit(f"{client}:{body.username}")

    user = get_user_auth_row(body.username)
    if user is None or not verify_password(body.password, user["password_hash"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
        )
    token = create_access_token(user["id"], user["username"])
    return TokenResponse(access_token=token)


@router.post("/admin/users", response_model=UserPublic, status_code=status.HTTP_201_CREATED)
def admin_create_user(
    body: AdminCreateUser,
    x_admin_token: str | None = Header(default=None),
) -> UserPublic:
    settings = get_settings()
    if not x_admin_token or x_admin_token != settings.admin_token:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")

    existing = fetchone("SELECT id FROM users WHERE username = ?", (body.username,))
    if existing is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Username taken")

    user_id = execute(
        "INSERT INTO users (username, password_hash, display_name, bio) VALUES (?, ?, ?, ?)",
        (body.username, hash_password(body.password), body.display_name, body.bio),
    )
    row = fetchone(
        "SELECT id, username, display_name, bio, avatar_path, created_at FROM users WHERE id = ?",
        (user_id,),
    )
    assert row is not None
    return UserPublic(**dict(row))
