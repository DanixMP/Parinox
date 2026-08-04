"""Phase 2 tests: LiveKit token minting + room membership checks."""

from __future__ import annotations

import os
import tempfile
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

_tmp = tempfile.mkdtemp(prefix="teamapp_lk_")
os.environ["DATABASE_PATH"] = str(Path(_tmp) / "test.db")
os.environ["MEDIA_ROOT"] = str(Path(_tmp) / "media")
os.environ["JWT_SECRET"] = "test-secret-livekit-phase2-long-enough"
os.environ["ADMIN_TOKEN"] = "test-admin"
os.environ["LIVEKIT_API_KEY"] = "devkey"
os.environ["LIVEKIT_API_SECRET"] = "secret-that-is-long-enough-for-jwt!!"
os.environ["LIVEKIT_WS_URL"] = "ws://127.0.0.1:7880"

from config import get_settings  # noqa: E402

get_settings.cache_clear()

from livekit_rooms import chat_room_name, dm_room_name, parse_room_name  # noqa: E402
from main import create_app  # noqa: E402


@pytest.fixture()
def client():
    get_settings.cache_clear()
    app = create_app()
    with TestClient(app) as c:
        yield c


def _create_user(client: TestClient, username: str) -> dict:
    r = client.post(
        "/admin/users",
        json={"username": username, "password": "password123", "display_name": username.title()},
        headers={"X-Admin-Token": "test-admin"},
    )
    assert r.status_code == 201, r.text
    return r.json()


def _login(client: TestClient, username: str) -> str:
    r = client.post("/login", json={"username": username, "password": "password123"})
    assert r.status_code == 200, r.text
    return r.json()["access_token"]


def test_room_name_helpers():
    assert chat_room_name(42) == "room_42"
    assert dm_room_name(5, 2) == "dm_2_5"
    assert parse_room_name("room_7") == ("room", (7,))
    assert parse_room_name("dm_1_9") == ("dm", (1, 9))
    with pytest.raises(ValueError):
        parse_room_name("dm_9_1")  # must be sorted
    with pytest.raises(ValueError):
        parse_room_name("lobby")


def test_livekit_token_for_member(client: TestClient):
    a = _create_user(client, "alice_lk")
    b = _create_user(client, "bob_lk")
    token = _login(client, "alice_lk")
    headers = {"Authorization": f"Bearer {token}"}

    room = client.post(
        "/rooms",
        json={"name": "call-me", "member_ids": [b["id"]], "is_dm": False},
        headers=headers,
    ).json()

    res = client.post(
        "/livekit/token",
        json={"room": f"room_{room['id']}"},
        headers=headers,
    )
    assert res.status_code == 200, res.text
    body = res.json()
    assert "token" in body and body["token"]
    assert body["url"] == "ws://127.0.0.1:7880"


def test_livekit_token_rejects_non_member(client: TestClient):
    _create_user(client, "alice_lk2")
    _create_user(client, "bob_lk2")
    outsider = _create_user(client, "eve_lk2")

    alice_token = _login(client, "alice_lk2")
    room = client.post(
        "/rooms",
        json={"name": "private", "member_ids": [], "is_dm": False},
        headers={"Authorization": f"Bearer {alice_token}"},
    ).json()

    eve_token = _login(client, "eve_lk2")
    res = client.post(
        "/livekit/token",
        json={"room": f"room_{room['id']}"},
        headers={"Authorization": f"Bearer {eve_token}"},
    )
    assert res.status_code == 403
    assert outsider["id"]  # silence unused if assert path differs


def test_livekit_dm_token(client: TestClient):
    a = _create_user(client, "alice_dm")
    b = _create_user(client, "bob_dm")
    token = _login(client, "alice_dm")
    room_name = dm_room_name(a["id"], b["id"])

    res = client.post(
        "/livekit/token",
        json={"room": room_name},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res.status_code == 200, res.text

    # Stranger cannot join dm room
    eve = _create_user(client, "eve_dm")
    eve_token = _login(client, "eve_dm")
    bad = client.post(
        "/livekit/token",
        json={"room": room_name},
        headers={"Authorization": f"Bearer {eve_token}"},
    )
    assert bad.status_code == 403
    assert eve["id"]


def test_livekit_rejects_bad_room_name(client: TestClient):
    _create_user(client, "alice_bad")
    token = _login(client, "alice_bad")
    res = client.post(
        "/livekit/token",
        json={"room": "not-a-valid-room"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res.status_code == 400
