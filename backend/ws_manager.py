"""WebSocket connection manager keyed by room_id."""

from __future__ import annotations

import asyncio
from collections import defaultdict
from typing import Any

from fastapi import WebSocket


class ConnectionManager:
    def __init__(self) -> None:
        self._rooms: dict[int, dict[WebSocket, int]] = defaultdict(dict)
        self._lock = asyncio.Lock()

    async def connect(self, ws: WebSocket, room_id: int, user_id: int) -> None:
        async with self._lock:
            self._rooms[room_id][ws] = user_id

    async def disconnect(self, ws: WebSocket, room_id: int) -> None:
        async with self._lock:
            room = self._rooms.get(room_id)
            if room is None:
                return
            room.pop(ws, None)
            if not room:
                self._rooms.pop(room_id, None)

    async def broadcast(self, room_id: int, payload: dict[str, Any]) -> None:
        async with self._lock:
            sockets = list(self._rooms.get(room_id, {}).keys())
        stale: list[WebSocket] = []
        for ws in sockets:
            try:
                await ws.send_json(payload)
            except Exception:
                stale.append(ws)
        for ws in stale:
            await self.disconnect(ws, room_id)

    def user_ids_in_room(self, room_id: int) -> list[int]:
        return list(self._rooms.get(room_id, {}).values())


manager = ConnectionManager()
