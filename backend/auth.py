"""JWT auth, password hashing, and login rate limiting."""

from __future__ import annotations

import time
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from passlib.context import CryptContext

from config import get_settings
from db import get_db, row_to_dict

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
bearer_scheme = HTTPBearer(auto_error=False)

# Simple in-memory login rate limiter: username/ip -> list of attempt timestamps
_login_attempts: dict[str, list[float]] = defaultdict(list)
_LOGIN_WINDOW_SEC = 60
_LOGIN_MAX_ATTEMPTS = 10


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


def create_access_token(user_id: int, username: str) -> str:
    settings = get_settings()
    expire = datetime.now(timezone.utc) + timedelta(days=settings.jwt_expire_days)
    payload = {"sub": str(user_id), "username": username, "exp": expire}
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")


def decode_token(token: str) -> dict:
    settings = get_settings()
    try:
        return jwt.decode(token, settings.jwt_secret, algorithms=["HS256"])
    except JWTError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token") from exc


def verify_jwt_token(token: str) -> dict:
    """Verify JWT and return the user row dict. Raises HTTPException on failure."""
    payload = decode_token(token)
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    with get_db() as conn:
        row = conn.execute("SELECT * FROM users WHERE id = ?", (int(user_id),)).fetchone()
    user = row_to_dict(row)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    return user


def check_login_rate_limit(key: str) -> None:
    now = time.time()
    attempts = [t for t in _login_attempts[key] if now - t < _LOGIN_WINDOW_SEC]
    _login_attempts[key] = attempts
    if len(attempts) >= _LOGIN_MAX_ATTEMPTS:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many login attempts. Try again shortly.",
        )
    _login_attempts[key].append(now)


def clear_login_attempts(key: str) -> None:
    _login_attempts.pop(key, None)


async def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
) -> dict:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")
    return verify_jwt_token(credentials.credentials)


CurrentUser = Annotated[dict, Depends(get_current_user)]
