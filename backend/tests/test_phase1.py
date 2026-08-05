"""Phase 1 tests: auth, rooms, history, WebSocket resync."""

from __future__ import annotations

import os
import tempfile
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

# Isolate DB + media before importing app
_tmp = tempfile.mkdtemp(prefix="teamapp_")
os.environ["DATABASE_PATH"] = str(Path(_tmp) / "test.db")
os.environ["MEDIA_ROOT"] = str(Path(_tmp) / "media")
os.environ["JWT_SECRET"] = "test-secret"
os.environ["ADMIN_TOKEN"] = "test-admin"

from config import get_settings  # noqa: E402

get_settings.cache_clear()

from main import create_app  # noqa: E402


@pytest.fixture()
def client():
    get_settings.cache_clear()
    app = create_app()
    with TestClient(app) as c:
        yield c


def _create_user(client: TestClient, username: str, password: str = "password123") -> dict:
    r = client.post(
        "/admin/users",
        json={"username": username, "password": password, "display_name": username.title()},
        headers={"X-Admin-Token": "test-admin"},
    )
    assert r.status_code == 201, r.text
    return r.json()


def _login(client: TestClient, username: str, password: str = "password123") -> str:
    r = client.post("/login", json={"username": username, "password": password})
    assert r.status_code == 200, r.text
    return r.json()["access_token"]


def test_health(client: TestClient):
    assert client.get("/health").json()["status"] == "ok"


def test_signup_requires_recovery_and_saves(client: TestClient):
    # Missing email and phone
    bad = client.post(
        "/signup",
        json={"username": "newbie", "password": "password123", "display_name": "Newbie"},
    )
    assert bad.status_code == 422

    ok = client.post(
        "/signup",
        json={
            "username": "newbie",
            "password": "password123",
            "display_name": "Newbie",
            "email": "newbie@example.com",
        },
    )
    assert ok.status_code == 201, ok.text
    token = ok.json()["access_token"]
    me = client.get("/me", headers={"Authorization": f"Bearer {token}"})
    assert me.status_code == 200
    body = me.json()
    assert body["username"] == "newbie"
    assert body["email"] == "newbie@example.com"
    assert body["phone"] is None

    phone_user = client.post(
        "/signup",
        json={
            "username": "phoneme",
            "password": "password123",
            "display_name": "Phone Me",
            "phone": "+989121234567",
        },
    )
    assert phone_user.status_code == 201
    token2 = phone_user.json()["access_token"]
    me2 = client.get("/me", headers={"Authorization": f"Bearer {token2}"}).json()
    assert me2["phone"] == "+989121234567"
    assert me2["email"] is None

    # Duplicate email
    dup = client.post(
        "/signup",
        json={
            "username": "other",
            "password": "password123",
            "display_name": "Other",
            "email": "newbie@example.com",
        },
    )
    assert dup.status_code == 409



def test_login_and_me(client: TestClient):
    _create_user(client, "alice")
    token = _login(client, "alice")
    me = client.get("/me", headers={"Authorization": f"Bearer {token}"})
    assert me.status_code == 200
    assert me.json()["username"] == "alice"


def test_invalid_login(client: TestClient):
    _create_user(client, "bob")
    r = client.post("/login", json={"username": "bob", "password": "wrong"})
    assert r.status_code == 401


def test_rooms_and_history(client: TestClient):
    a = _create_user(client, "alice2")
    b = _create_user(client, "bob2")
    token = _login(client, "alice2")
    headers = {"Authorization": f"Bearer {token}"}

    room = client.post(
        "/rooms",
        json={"name": "general", "member_ids": [b["id"]], "is_dm": False},
        headers=headers,
    )
    assert room.status_code == 201
    room_id = room.json()["id"]

    rooms = client.get("/rooms", headers=headers)
    assert rooms.status_code == 200
    assert any(r["id"] == room_id for r in rooms.json())

    hist = client.get(f"/rooms/{room_id}/history?after=0", headers=headers)
    assert hist.status_code == 200
    assert hist.json() == []


def test_ws_resync(client: TestClient):
    a = _create_user(client, "alice3")
    b = _create_user(client, "bob3")
    token_a = _login(client, "alice3")
    token_b = _login(client, "bob3")
    headers = {"Authorization": f"Bearer {token_a}"}

    room = client.post(
        "/rooms",
        json={"name": "dm", "member_ids": [b["id"]], "is_dm": True},
        headers=headers,
    ).json()
    room_id = room["id"]

    # Alice connects and sends a message
    with client.websocket_connect(f"/ws/{room_id}?token={token_a}&last_id=0") as ws_a:
        ws_a.send_json({"content": "hello bob"})
        msg = ws_a.receive_json()
        assert msg["content"] == "hello bob"
        assert msg["sender_id"] == a["id"]
        last_id = msg["id"]

    # Bob connects with last_id=0 and should receive the missed message via resync
    with client.websocket_connect(f"/ws/{room_id}?token={token_b}&last_id=0") as ws_b:
        missed = ws_b.receive_json()
        assert missed["id"] == last_id
        assert missed["content"] == "hello bob"

    # Bob reconnects with last_id set — should NOT get the old message again before new ones
    with client.websocket_connect(f"/ws/{room_id}?token={token_b}&last_id={last_id}") as ws_b:
        # Send a new message from bob; he should get it via broadcast, not as stale resync
        ws_b.send_json({"content": "hi alice"})
        msg = ws_b.receive_json()
        assert msg["content"] == "hi alice"
        assert msg["id"] > last_id


def test_ws_rejects_bad_token(client: TestClient):
    a = _create_user(client, "alice4")
    token = _login(client, "alice4")
    room = client.post(
        "/rooms",
        json={"name": "solo", "member_ids": [], "is_dm": False},
        headers={"Authorization": f"Bearer {token}"},
    ).json()
    with pytest.raises(WebSocketDisconnect):
        with client.websocket_connect(f"/ws/{room['id']}?token=not-a-token&last_id=0") as ws:
            ws.receive_json()


def test_dm_reuse(client: TestClient):
    a = _create_user(client, "alice5")
    b = _create_user(client, "bob5")
    token = _login(client, "alice5")
    headers = {"Authorization": f"Bearer {token}"}
    r1 = client.post(
        "/rooms",
        json={"name": "DM", "member_ids": [b["id"]], "is_dm": True},
        headers=headers,
    ).json()
    r2 = client.post(
        "/rooms",
        json={"name": "DM again", "member_ids": [b["id"]], "is_dm": True},
        headers=headers,
    ).json()
    assert r1["id"] == r2["id"]
    assert r1["kind"] == "dm"


def test_channel_group_and_dm_kinds(client: TestClient):
    a = _create_user(client, "alice6")
    b = _create_user(client, "bob6")
    c = _create_user(client, "carol6")
    token = _login(client, "alice6")
    headers = {"Authorization": f"Bearer {token}"}

    channel = client.post(
        "/rooms",
        json={"name": "general", "kind": "channel", "description": "Team channel"},
        headers=headers,
    )
    assert channel.status_code == 201
    ch = channel.json()
    assert ch["kind"] == "channel"
    assert {m["id"] for m in ch["members"]} >= {a["id"], b["id"], c["id"]}

    group = client.post(
        "/rooms",
        json={"name": "Project X", "kind": "group", "member_ids": [b["id"]]},
        headers=headers,
    )
    assert group.status_code == 201
    g = group.json()
    assert g["kind"] == "group"
    assert {m["id"] for m in g["members"]} == {a["id"], b["id"]}

    dm = client.post("/dms", json={"user_id": b["id"]}, headers=headers)
    assert dm.status_code == 201
    assert dm.json()["kind"] == "dm"
    dm2 = client.post("/dms", json={"user_id": b["id"]}, headers=headers)
    assert dm2.json()["id"] == dm.json()["id"]

    rooms = client.get("/rooms", headers=headers).json()
    kinds = {r["id"]: r["kind"] for r in rooms}
    assert kinds[ch["id"]] == "channel"
    assert kinds[g["id"]] == "group"
    assert kinds[dm.json()["id"]] == "dm"

    filtered = client.get("/rooms?kind=channel", headers=headers).json()
    assert all(r["kind"] == "channel" for r in filtered)
    assert any(r["id"] == ch["id"] for r in filtered)

    # Channels are invite-only — new users are not auto-joined
    d = _create_user(client, "dave6")
    token_d = _login(client, "dave6")
    d_headers = {"Authorization": f"Bearer {token_d}"}
    d_rooms = client.get("/rooms?kind=channel", headers=d_headers).json()
    assert not any(r["id"] == ch["id"] for r in d_rooms)

    invite = client.get(f"/rooms/{ch['id']}/invite", headers=headers)
    assert invite.status_code == 200
    token = invite.json()["invite_token"]
    joined = client.post(f"/rooms/join/{token}", headers=d_headers)
    assert joined.status_code == 200
    assert joined.json()["id"] == ch["id"]
    d_rooms2 = client.get("/rooms?kind=channel", headers=d_headers).json()
    assert any(r["id"] == ch["id"] for r in d_rooms2)

    # Add member to group
    added = client.post(
        f"/rooms/{g['id']}/members",
        json={"user_ids": [c["id"]]},
        headers=headers,
    )
    assert added.status_code == 200
    assert {m["id"] for m in added.json()["members"]} == {a["id"], b["id"], c["id"]}
