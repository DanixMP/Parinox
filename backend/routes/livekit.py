"""LiveKit token minting — reuses app JWT identity."""

from __future__ import annotations

from fastapi import APIRouter

from auth import CurrentUser
from config import get_settings
from models import LiveKitTokenRequest, LiveKitTokenResponse

router = APIRouter(tags=["livekit"])


@router.post("/livekit/token", response_model=LiveKitTokenResponse)
def get_livekit_token(body: LiveKitTokenRequest, user: CurrentUser) -> LiveKitTokenResponse:
    settings = get_settings()
    try:
        from livekit.api import AccessToken, VideoGrants
    except ImportError:
        # Fallback minimal JWT-like stub for environments without livekit-api
        # Prefer real SDK when installed.
        raise RuntimeError("livekit-api is required for token minting")

    token = (
        AccessToken(settings.livekit_api_key, settings.livekit_api_secret)
        .with_identity(user["username"])
        .with_name(user["display_name"])
        .with_grants(VideoGrants(room_join=True, room=body.room))
    )
    return LiveKitTokenResponse(token=token.to_jwt(), url=settings.livekit_ws_url)
