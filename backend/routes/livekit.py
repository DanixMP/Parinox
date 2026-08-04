"""LiveKit token minting — reuses app JWT identity; validates room membership."""

from __future__ import annotations

from datetime import timedelta

from fastapi import APIRouter, HTTPException, status

from auth import CurrentUser
from config import get_settings
from db import get_db
from livekit_rooms import parse_room_name
from models import LiveKitTokenRequest, LiveKitTokenResponse

router = APIRouter(tags=["livekit"])


def _assert_can_join(user_id: int, room: str) -> None:
    try:
        kind, ids = parse_room_name(room)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    with get_db() as conn:
        if kind == "room":
            (room_id,) = ids
            member = conn.execute(
                "SELECT 1 FROM room_members WHERE room_id = ? AND user_id = ?",
                (room_id, user_id),
            ).fetchone()
            if not member:
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a room member")
            return

        # dm_{a}_{b}
        a, b = ids
        if user_id not in (a, b):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a DM participant")
        # Both users must exist
        found = conn.execute(
            "SELECT COUNT(*) AS c FROM users WHERE id IN (?, ?)",
            (a, b),
        ).fetchone()["c"]
        if found != 2:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Unknown DM participant")


@router.post("/livekit/token", response_model=LiveKitTokenResponse)
def get_livekit_token(body: LiveKitTokenRequest, user: CurrentUser) -> LiveKitTokenResponse:
    settings = get_settings()
    _assert_can_join(user["id"], body.room)

    try:
        from livekit.api import AccessToken, VideoGrants
    except ImportError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="livekit-api is not installed on the server",
        ) from exc

    token = (
        AccessToken(settings.livekit_api_key, settings.livekit_api_secret)
        .with_identity(user["username"])
        .with_name(user["display_name"])
        .with_ttl(timedelta(hours=6))
        .with_grants(
            VideoGrants(
                room_join=True,
                room=body.room,
                can_publish=True,
                can_subscribe=True,
                can_publish_data=True,
            )
        )
    )
    return LiveKitTokenResponse(token=token.to_jwt(), url=settings.livekit_ws_url)
