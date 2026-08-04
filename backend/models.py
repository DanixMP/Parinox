"""Pydantic request/response schemas."""

from __future__ import annotations

from pydantic import BaseModel, Field


class LoginRequest(BaseModel):
    username: str
    password: str


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
    display_name: str | None = None
    bio: str | None = None


class AdminCreateUser(BaseModel):
    username: str = Field(min_length=2, max_length=64)
    password: str = Field(min_length=6, max_length=128)
    display_name: str = Field(min_length=1, max_length=128)
    bio: str = ""
    is_admin: bool = False


class RoomCreate(BaseModel):
    name: str = Field(min_length=1, max_length=128)
    member_ids: list[int] = Field(default_factory=list)
    is_dm: bool = False


class RoomOut(BaseModel):
    id: int
    name: str
    is_dm: bool
    created_at: str | None = None
    members: list[UserPublic] = Field(default_factory=list)


class MessageOut(BaseModel):
    id: int
    room_id: int
    sender_id: int
    content: str | None = None
    image_path: str | None = None
    created_at: str
    sender_display_name: str | None = None


class WsIncoming(BaseModel):
    content: str | None = None
    image_path: str | None = None
    type: str = "message"  # message | typing


class LiveKitTokenRequest(BaseModel):
    room: str


class LiveKitTokenResponse(BaseModel):
    token: str
    url: str


class PostCreateCaption(BaseModel):
    caption: str = ""


class CommentCreate(BaseModel):
    content: str = Field(min_length=1, max_length=2000)
