"""LiveKit room naming helpers — DESIGN.md §6."""

from __future__ import annotations

import re

ROOM_RE = re.compile(r"^room_(\d+)$")
DM_RE = re.compile(r"^dm_(\d+)_(\d+)$")


def chat_room_name(room_id: int) -> str:
    """Group (or any chat-tied) call room name."""
    return f"room_{room_id}"


def dm_room_name(user_a: int, user_b: int) -> str:
    """1:1 call room name — ids sorted for stability."""
    a, b = sorted((user_a, user_b))
    return f"dm_{a}_{b}"


def parse_room_name(room: str) -> tuple[str, tuple[int, ...]]:
    """Return ('room'|'dm', ids). Raises ValueError if invalid."""
    m = ROOM_RE.match(room)
    if m:
        return "room", (int(m.group(1)),)
    m = DM_RE.match(room)
    if m:
        a, b = int(m.group(1)), int(m.group(2))
        if a >= b:
            raise ValueError("dm room ids must be sorted ascending")
        return "dm", (a, b)
    raise ValueError("room must be room_{id} or dm_{a}_{b}")
