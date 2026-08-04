"""Backend tests for auth, rooms, and WebSocket resync."""

from __future__ import annotations

import os
import tempfile
import uuid
from pathlib import Path

import pytest
from fastapi.testclient import TestClient


@pytest.fixture()
def client(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    db_path = tmp_path / f"test-{uuid.uuid4().hex}.db"
    media_path = tmp_path / "media"
    media_path.mkdir()

    monkeypatch.setenv("DATABASE_PATH", str(db_path))
    monkeypatch.setenv("MEDIA_ROOT", str(media_path))
    monkeypatch.setenv("JWT_SECRET", "test-secret")
    monkeypatch.setenv("ADMIN_TOKEN", "test-admin")

    # Import after env is set; clear caches between tests
    from config import get_settings
    from db import init_db, reset_connection

    get_settings.cache_clear()
    reset_connection()
    init_db()

    from main import create_app

    app = create_app()
    with TestClient(app) as c:
        yield c

    reset_connection()
    get_settings.cache_clear()


def _create_user(client: TestClient, username: str, password: str = "pass1234") -> dict:
    r = client.post(
        "/admin/users",
        json={
            "username": username,
            "password": password,
            "display_name": username.title(),
        },
        headers={"X-Admin-Token": "test-admin"},
    )
    assert r.status_code == 201, r.text
    return r.json()


def _login(client: TestClient, username: str, password: str = "pass1234") -> str:
    r = client.post("/login", json={"username": username, "password": password})
    assert r.status_code == 200, r.text
    return r.json()["access_token"]


def test_health(client: TestClient):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_login_and_me(client: TestClient):
    _create_user(client, "alice")
    token = _login(client, "alice")
    r = client.get("/me", headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 200
    assert r.json()["username"] == "alice"


def test_room_and_history_resync(client: TestClient):
    alice = _create_user(client, "alice")
    bob = _create_user(client, "bob")
    alice_token = _login(client, "alice")
    bob_token = _login(client, "bob")

    r = client.post(
        "/rooms",
        json={"name": "general", "member_ids": [bob["id"]], "is_dm": False},
        headers={"Authorization": f"Bearer {alice_token}"},
    )
    assert r.status_code == 201, r.text
    room_id = r.json()["id"]

    for text in ("hello", "world"):
        r = client.post(
            f"/rooms/{room_id}/messages",
            data={"content": text},
            headers={"Authorization": f"Bearer {alice_token}"},
        )
        assert r.status_code == 200, r.text

    hist = client.get(
        f"/rooms/{room_id}/history?after=0",
        headers={"Authorization": f"Bearer {bob_token}"},
    )
    assert hist.status_code == 200
    msgs = hist.json()
    assert len(msgs) == 2
    assert msgs[0]["content"] == "hello"
    first_id = msgs[0]["id"]

    hist2 = client.get(
        f"/rooms/{room_id}/history?after={first_id}",
        headers={"Authorization": f"Bearer {bob_token}"},
    )
    assert [m["content"] for m in hist2.json()] == ["world"]


def test_ws_resync(client: TestClient):
    alice = _create_user(client, "alice")
    bob = _create_user(client, "bob")
    alice_token = _login(client, "alice")
    bob_token = _login(client, "bob")

    r = client.post(
        "/rooms",
        json={"name": "dm", "member_ids": [bob["id"]], "is_dm": True},
        headers={"Authorization": f"Bearer {alice_token}"},
    )
    room_id = r.json()["id"]

    r = client.post(
        f"/rooms/{room_id}/messages",
        data={"content": "missed while offline"},
        headers={"Authorization": f"Bearer {alice_token}"},
    )
    assert r.status_code == 200
    msg_id = r.json()["id"]

    with client.websocket_connect(
        f"/ws/{room_id}?token={bob_token}&last_id=0"
    ) as ws:
        data = ws.receive_json()
        assert data["type"] == "message"
        assert data["message"]["content"] == "missed while offline"
        assert data["message"]["id"] == msg_id
        done = ws.receive_json()
        assert done["type"] == "resync_complete"
        assert done["count"] == 1

        ws.send_json({"type": "message", "content": "back online"})
        echoed = ws.receive_json()
        assert echoed["type"] == "message"
        assert echoed["message"]["content"] == "back online"
        assert echoed["message"]["sender_id"] == bob["id"]


def test_ws_rejects_bad_token(client: TestClient):
    _create_user(client, "alice")
    token = _login(client, "alice")
    r = client.post(
        "/rooms",
        json={"name": "solo", "member_ids": [], "is_dm": False},
        headers={"Authorization": f"Bearer {token}"},
    )
    room_id = r.json()["id"]

    with pytest.raises(Exception):
        with client.websocket_connect(f"/ws/{room_id}?token=bad&last_id=0") as ws:
            ws.receive_json()
