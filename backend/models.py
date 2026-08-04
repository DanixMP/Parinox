"""Pydantic request/response schemas."""

from __future__ import annotations

from pydantic import BaseModel, Field


class LoginRequest(BaseModel):
    username: str = Field(min_length=1, max_length=64)
    password: str = Field(min_length=1, max_length=128)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class UserPublic(BaseModel):
    id: int
    username: str
    display_name: str
    bio: str = ""
    avatar_path: str | None = None
    created_at: str | None = None


class UserUpdate(BaseModel):
    display_name: str | None = Field(default=None, min_length=1, max_length=64)
    bio: str | None = Field(default=None, max_length=500)


class AdminCreateUser(BaseModel):
    username: str = Field(min_length=1, max_length=64)
    password: str = Field(min_length=4, max_length=128)
    display_name: str = Field(min_length=1, max_length=64)
    bio: str = ""


class RoomCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    member_ids: list[int] = Field(default_factory=list)
    is_dm: bool = False


class RoomOut(BaseModel):
    id: int
    name: str
    is_dm: bool
    created_at: str | None = None
    member_ids: list[int] = Field(default_factory=list)


class MessageOut(BaseModel):
    id: int
    room_id: int
    sender_id: int
    content: str | None = None
    image_path: str | None = None
    created_at: str | None = None
    sender_username: str | None = None
    sender_display_name: str | None = None


class WsIncoming(BaseModel):
    content: str | None = None
    image_path: str | None = None
    type: str = "message"  # message | typing | ping


class LiveKitTokenRequest(BaseModel):
    room: str = Field(min_length=1, max_length=128)


class LiveKitTokenResponse(BaseModel):
    token: str
    url: str
