"""JWT auth, password hashing, and FastAPI dependencies."""

from __future__ import annotations

import time
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from typing import Annotated, Any

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from passlib.context import CryptContext

from config import Settings, get_settings
from db import fetchone, row_to_dict

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
bearer_scheme = HTTPBearer(auto_error=False)

# Simple in-memory rate limiter for /login (enough for ~20 users).
_login_attempts: dict[str, list[float]] = defaultdict(list)
_LOGIN_WINDOW_SEC = 60
_LOGIN_MAX_ATTEMPTS = 10


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


def create_access_token(user_id: int, username: str, settings: Settings | None = None) -> str:
    settings = settings or get_settings()
    expire = datetime.now(timezone.utc) + timedelta(days=settings.jwt_expire_days)
    payload = {
        "sub": str(user_id),
        "username": username,
        "exp": expire,
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")


def decode_token(token: str, settings: Settings | None = None) -> dict[str, Any]:
    settings = settings or get_settings()
    try:
        return jwt.decode(token, settings.jwt_secret, algorithms=["HS256"])
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        ) from exc


def check_login_rate_limit(key: str) -> None:
    now = time.time()
    window_start = now - _LOGIN_WINDOW_SEC
    attempts = [t for t in _login_attempts[key] if t >= window_start]
    _login_attempts[key] = attempts
    if len(attempts) >= _LOGIN_MAX_ATTEMPTS:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many login attempts, try again later",
        )
    _login_attempts[key].append(now)


def get_user_by_id(user_id: int) -> dict[str, Any] | None:
    row = fetchone(
        "SELECT id, username, display_name, bio, avatar_path, created_at FROM users WHERE id = ?",
        (user_id,),
    )
    return row_to_dict(row)


def get_user_auth_row(username: str) -> dict[str, Any] | None:
    row = fetchone(
        "SELECT id, username, password_hash, display_name, bio, avatar_path, created_at "
        "FROM users WHERE username = ?",
        (username,),
    )
    return row_to_dict(row)


def verify_jwt_token(token: str) -> dict[str, Any]:
    """Verify JWT and return the user dict. Raises HTTPException on failure."""
    payload = decode_token(token)
    try:
        user_id = int(payload["sub"])
    except (KeyError, TypeError, ValueError) as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload",
        ) from exc
    user = get_user_by_id(user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )
    return user


async def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
) -> dict[str, Any]:
    if credentials is None or not credentials.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
        )
    return verify_jwt_token(credentials.credentials)


CurrentUser = Annotated[dict[str, Any], Depends(get_current_user)]
