"""Pydantic request/response schemas."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field, model_validator

RoomKind = Literal["channel", "group", "dm"]


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
    banner_path: str | None = None
    email: str | None = None
    phone: str | None = None
    created_at: str | None = None
    is_online: bool = False
    last_seen_at: str | None = None
    role: str | None = None  # owner | admin | member when listed in a room


class UserUpdate(BaseModel):
    display_name: str | None = None
    bio: str | None = None


class RoomMemberRoleUpdate(BaseModel):
    role: Literal["admin", "member"]


class PostSummary(BaseModel):
    id: int
    user_id: int
    caption: str = ""
    image_path: str
    width: int
    height: int
    created_at: str
    like_count: int = 0
    comment_count: int = 0


class ProfileOut(BaseModel):
    """Public profile + own-posts grid (DESIGN §4 GET /users/{id})."""

    id: int
    username: str
    display_name: str
    bio: str = ""
    avatar_path: str | None = None
    banner_path: str | None = None
    created_at: str | None = None
    posts: list[PostSummary] = Field(default_factory=list)
    post_count: int = 0
    is_online: bool = False
    last_seen_at: str | None = None


class SignupRequest(BaseModel):
    """Public signup — email or phone required for account recovery."""

    username: str = Field(min_length=2, max_length=64)
    password: str = Field(min_length=6, max_length=128)
    display_name: str = Field(min_length=1, max_length=128)
    email: str | None = Field(default=None, max_length=254)
    phone: str | None = Field(default=None, max_length=32)

    @model_validator(mode="after")
    def _require_recovery_contact(self) -> SignupRequest:
        email = (self.email or "").strip().lower() or None
        phone = (self.phone or "").strip() or None
        if phone is not None:
            digits = "".join(ch for ch in phone if ch.isdigit())
            if len(digits) < 8:
                raise ValueError("Phone number looks too short")
            # Keep a normalized-ish form (+ and digits)
            cleaned = "".join(ch for ch in phone if ch.isdigit() or ch == "+")
            phone = cleaned or None
        if email is not None and ("@" not in email or "." not in email.split("@")[-1]):
            raise ValueError("Invalid email address")
        if not email and not phone:
            raise ValueError("Provide an email or phone number for account recovery")
        self.email = email
        self.phone = phone
        return self


class AdminCreateUser(BaseModel):
    username: str = Field(min_length=2, max_length=64)
    password: str = Field(min_length=6, max_length=128)
    display_name: str = Field(min_length=1, max_length=128)
    bio: str = ""
    email: str | None = None
    phone: str | None = None
    is_admin: bool = False


class RoomCreate(BaseModel):
    name: str = Field(min_length=1, max_length=128)
    member_ids: list[int] = Field(default_factory=list)
    kind: RoomKind = "group"
    description: str = Field(default="", max_length=500)
    public_id: str | None = Field(default=None, max_length=32)
    is_dm: bool | None = None  # legacy; if True forces kind=dm

    @model_validator(mode="after")
    def _legacy_is_dm(self) -> RoomCreate:
        if self.is_dm is True:
            self.kind = "dm"
        return self


class RoomUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=128)
    description: str | None = Field(default=None, max_length=500)
    public_id: str | None = Field(default=None, max_length=32)


class LastMessagePreview(BaseModel):
    id: int
    content: str | None = None
    media_type: str | None = None
    sender_id: int
    sender_display_name: str | None = None
    created_at: str
    deleted: bool = False


class RoomOut(BaseModel):
    id: int
    name: str
    kind: RoomKind
    is_dm: bool
    description: str = ""
    avatar_path: str | None = None
    public_id: str | None = None
    invite_token: str | None = None  # only for owners/admins
    created_by: int | None = None
    created_at: str | None = None
    members: list[UserPublic] = Field(default_factory=list)
    last_message: LastMessagePreview | None = None
    unread_count: int = 0
    my_role: str = "member"  # owner | admin | member
    can_post: bool = True


class DmCreate(BaseModel):
    user_id: int


class RoomMembersAdd(BaseModel):
    user_ids: list[int] = Field(min_length=1)


class RoomDeleteRequest(BaseModel):
    """Unused body shape kept for docs; delete uses query for_everyone."""

    for_everyone: bool = False


class MessageOut(BaseModel):
    id: int
    room_id: int
    sender_id: int
    content: str | None = None
    image_path: str | None = None
    media_path: str | None = None
    media_type: str | None = None  # image | video | audio | file
    file_name: str | None = None
    reply_to_id: int | None = None
    reply_preview: dict | None = None
    forwarded_from_id: int | None = None
    is_forwarded: bool = False
    deleted: bool = False
    delivery_status: str = "sent"  # sent | delivered | read
    mentions: list[dict] = Field(default_factory=list)
    created_at: str
    sender_display_name: str | None = None
    sender_avatar_path: str | None = None


class ForwardRequest(BaseModel):
    to_room_id: int


class WsIncoming(BaseModel):
    content: str | None = None
    image_path: str | None = None
    media_path: str | None = None
    media_type: str | None = None
    file_name: str | None = None
    reply_to_id: int | None = None
    type: str = "message"  # message | typing | delete | delivered | read | forward
    message_id: int | None = None
    message_ids: list[int] | None = None
    up_to_id: int | None = None
    to_room_id: int | None = None


class LiveKitTokenRequest(BaseModel):
    room: str


class LiveKitTokenResponse(BaseModel):
    token: str
    url: str


class PostCreateCaption(BaseModel):
    caption: str = ""


class CommentCreate(BaseModel):
    content: str = Field(min_length=1, max_length=2000)
