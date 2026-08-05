"""Authenticated media serving — replaces public StaticFiles mount."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from fastapi.responses import FileResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from auth import verify_jwt_token
from db import get_db
from media_access import media_disk_path, normalize_media_path, user_can_access_media

router = APIRouter(tags=["media"])
_bearer = HTTPBearer(auto_error=False)


def _user_from_request(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None,
    access_token: str | None,
) -> dict:
    token = None
    if credentials and credentials.credentials:
        token = credentials.credentials
    elif access_token:
        token = access_token
    elif request.query_params.get("token"):
        # Legacy alias — prefer access_token
        token = request.query_params.get("token")
    if not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Authentication required")
    return verify_jwt_token(token)


@router.get("/media/{file_path:path}")
def get_media(
    file_path: str,
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    access_token: str | None = Query(default=None),
):
    user = _user_from_request(request, credentials, access_token)
    try:
        rel = normalize_media_path(file_path)
    except HTTPException:
        raise
    if rel is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")

    with get_db() as conn:
        if not user_can_access_media(conn, rel_path=rel, user_id=user["id"]):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")

    disk = media_disk_path(rel)
    if not disk.is_file():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")

    # Force download for non-image chat files to reduce XSS risk of served HTML/SVG leftovers
    media_type = None
    suffix = disk.suffix.lower()
    as_attachment = suffix in {".html", ".htm", ".svg", ".js", ".mjs", ".wasm"} or (
        rel.startswith("chat/") and suffix not in {".jpg", ".jpeg", ".png", ".webp", ".gif", ".mp4", ".webm", ".mov", ".mp3", ".m4a", ".aac", ".wav", ".ogg"}
    )
    headers = {
        "X-Content-Type-Options": "nosniff",
        "Cache-Control": "private, max-age=3600",
    }
    if as_attachment:
        headers["Content-Disposition"] = f'attachment; filename="{disk.name}"'

    return FileResponse(
        path=str(disk),
        media_type=media_type,
        headers=headers,
        filename=disk.name if as_attachment else None,
    )
