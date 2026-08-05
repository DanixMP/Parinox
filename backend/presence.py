"""Realtime presence — online users + last_seen persistence."""

from __future__ import annotations

from collections import defaultdict
from datetime import datetime, timezone

from fastapi import WebSocket

from db import get_db
from ws_manager import manager as room_manager


def _utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


class PresenceHub:
    """Tracks how many live sockets each user has open."""

    def __init__(self) -> None:
        self._counts: dict[int, int] = defaultdict(int)

    def is_online(self, user_id: int) -> bool:
        return self._counts.get(user_id, 0) > 0

    def online_user_ids(self) -> set[int]:
        return {uid for uid, n in self._counts.items() if n > 0}

    def snapshot(self) -> dict[int, dict]:
        """user_id -> {online, last_seen_at?} for online users only."""
        return {uid: {"online": True, "last_seen_at": None} for uid in self.online_user_ids()}

    async def user_connected(self, user_id: int) -> bool:
        """Returns True if this is the first connection (went online)."""
        prev = self._counts[user_id]
        self._counts[user_id] = prev + 1
        return prev == 0

    async def user_disconnected(self, user_id: int) -> bool:
        """Returns True if user fully went offline; updates last_seen_at."""
        prev = self._counts.get(user_id, 0)
        if prev <= 1:
            self._counts.pop(user_id, None)
            now = _utc_now()
            with get_db() as conn:
                conn.execute(
                    "UPDATE users SET last_seen_at = ? WHERE id = ?",
                    (now, user_id),
                )
            return True
        self._counts[user_id] = prev - 1
        return False

    def payload_for(self, user_id: int, *, online: bool | None = None) -> dict:
        is_on = self.is_online(user_id) if online is None else online
        last_seen = None
        if not is_on:
            with get_db() as conn:
                row = conn.execute(
                    "SELECT last_seen_at FROM users WHERE id = ?",
                    (user_id,),
                ).fetchone()
                last_seen = row["last_seen_at"] if row else None
        return {
            "type": "presence",
            "user_id": user_id,
            "online": is_on,
            "last_seen_at": last_seen,
        }

    async def broadcast_presence(self, user_id: int, *, went_online: bool) -> None:
        payload = self.payload_for(user_id, online=went_online)
        # Notify every room the user is a member of
        with get_db() as conn:
            rooms = conn.execute(
                "SELECT room_id FROM room_members WHERE user_id = ?",
                (user_id,),
            ).fetchall()
        for r in rooms:
            await room_manager.broadcast(r["room_id"], payload)


presence = PresenceHub()
