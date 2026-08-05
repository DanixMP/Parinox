"""Auth routes: login, public signup, admin user creation."""

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
from models import AdminCreateUser, LoginRequest, SignupRequest, TokenResponse, UserPublic

router = APIRouter(tags=["auth"])


def _user_public(user: dict, *, include_recovery: bool = False) -> UserPublic:
    return UserPublic(
        id=user["id"],
        username=user["username"],
        display_name=user["display_name"],
        bio=user.get("bio") or "",
        avatar_path=user.get("avatar_path"),
        banner_path=user.get("banner_path"),
        email=user.get("email") if include_recovery else None,
        phone=user.get("phone") if include_recovery else None,
        created_at=user.get("created_at"),
    )


def _assert_unique_contacts(conn, *, email: str | None, phone: str | None, exclude_user_id: int | None = None) -> None:
    if email:
        row = conn.execute("SELECT id FROM users WHERE email = ?", (email,)).fetchone()
        if row and (exclude_user_id is None or row["id"] != exclude_user_id):
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already in use")
    if phone:
        row = conn.execute("SELECT id FROM users WHERE phone = ?", (phone,)).fetchone()
        if row and (exclude_user_id is None or row["id"] != exclude_user_id):
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Phone already in use")


def _insert_user(
    conn,
    *,
    username: str,
    password: str,
    display_name: str,
    bio: str = "",
    email: str | None = None,
    phone: str | None = None,
    is_admin: bool = False,
) -> dict:
    existing = conn.execute("SELECT id FROM users WHERE username = ?", (username,)).fetchone()
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Username taken")
    _assert_unique_contacts(conn, email=email, phone=phone)

    cur = conn.execute(
        """
        INSERT INTO users (username, password_hash, display_name, bio, email, phone, is_admin)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        (username, hash_password(password), display_name, bio, email, phone, int(is_admin)),
    )
    user_id = cur.lastrowid
    # Channels are invite-link only — do not auto-join every channel.
    row = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    user = row_to_dict(row)
    assert user is not None
    return user


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


@router.post("/signup", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def signup(body: SignupRequest, request: Request) -> TokenResponse:
    """Public signup. Requires email or phone for recovery; returns JWT (auto sign-in)."""
    client = request.client.host if request.client else "unknown"
    rate_key = f"signup:{client}"
    check_login_rate_limit(rate_key)

    with get_db() as conn:
        user = _insert_user(
            conn,
            username=body.username.strip(),
            password=body.password,
            display_name=body.display_name.strip(),
            email=body.email,
            phone=body.phone,
        )

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

    email = (body.email or "").strip().lower() or None
    phone = (body.phone or "").strip() or None

    with get_db() as conn:
        user = _insert_user(
            conn,
            username=body.username.strip(),
            password=body.password,
            display_name=body.display_name.strip(),
            bio=body.bio,
            email=email,
            phone=phone,
            is_admin=body.is_admin,
        )

    return _user_public(user, include_recovery=True)
