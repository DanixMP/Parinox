"""WebSocket connection manager for chat rooms."""

from __future__ import annotations

from collections import defaultdict

from fastapi import WebSocket


class ConnectionManager:
    def __init__(self) -> None:
        # room_id -> list of (websocket, user_id)
        self._rooms: dict[int, list[tuple[WebSocket, int]]] = defaultdict(list)

    async def connect(self, ws: WebSocket, room_id: int, user_id: int) -> None:
        self._rooms[room_id].append((ws, user_id))

    def disconnect(self, ws: WebSocket, room_id: int) -> None:
        peers = self._rooms.get(room_id, [])
        self._rooms[room_id] = [(s, uid) for s, uid in peers if s is not ws]
        if not self._rooms[room_id]:
            self._rooms.pop(room_id, None)

    async def broadcast(self, room_id: int, payload: dict) -> None:
        dead: list[WebSocket] = []
        for ws, _uid in list(self._rooms.get(room_id, [])):
            try:
                await ws.send_json(payload)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.disconnect(ws, room_id)

    def room_user_ids(self, room_id: int) -> list[int]:
        return [uid for _ws, uid in self._rooms.get(room_id, [])]


manager = ConnectionManager()
