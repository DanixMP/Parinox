"""Phase 5 tests: stories feed, views, expiry cleanup."""

from __future__ import annotations

import io
import os
import tempfile
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from PIL import Image

_tmp = tempfile.mkdtemp(prefix="teamapp_p5_")
os.environ["DATABASE_PATH"] = str(Path(_tmp) / "test.db")
os.environ["MEDIA_ROOT"] = str(Path(_tmp) / "media")
os.environ["JWT_SECRET"] = "test-secret-phase5-stories-long-enough"
os.environ["ADMIN_TOKEN"] = "test-admin"

from config import get_settings  # noqa: E402

get_settings.cache_clear()

from db import get_db  # noqa: E402
from main import create_app  # noqa: E402
from scheduler import expire_stories  # noqa: E402


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


def _login(client: TestClient, username: str) -> dict:
    r = client.post("/login", json={"username": username, "password": "password123"})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _jpeg() -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (64, 96), (180, 40, 90)).save(buf, format="JPEG")
    return buf.getvalue()


def _post_story(client: TestClient, headers: dict) -> dict:
    r = client.post(
        "/stories",
        headers=headers,
        files={"media": ("s.jpg", _jpeg(), "image/jpeg")},
    )
    assert r.status_code == 201, r.text
    return r.json()


def test_create_and_list_stories_grouped(client: TestClient):
    alice = _create_user(client, "alice_st")
    bob = _create_user(client, "bob_st")
    ha = _login(client, "alice_st")
    hb = _login(client, "bob_st")

    s1 = _post_story(client, ha)
    s2 = _post_story(client, ha)
    _post_story(client, hb)

    feed = client.get("/stories", headers=hb).json()
    assert len(feed) == 2
    # Unseen first — both have unseen for bob
    by_user = {g["user_id"]: g for g in feed}
    assert alice["id"] in by_user
    assert bob["id"] in by_user
    assert len(by_user[alice["id"]]["stories"]) == 2
    assert by_user[alice["id"]]["has_unseen"] is True
    assert by_user[alice["id"]]["stories"][0]["id"] == s1["id"]
    assert by_user[alice["id"]]["stories"][1]["id"] == s2["id"]
    assert s1["expires_at"] > s1["created_at"]


def test_view_marks_seen(client: TestClient):
    _create_user(client, "carol_st")
    _create_user(client, "dave_st")
    hc = _login(client, "carol_st")
    hd = _login(client, "dave_st")

    story = _post_story(client, hc)
    sid = story["id"]

    before = client.get("/stories", headers=hd).json()
    carol_g = next(g for g in before if g["stories"] and g["stories"][0]["id"] == sid)
    assert carol_g["has_unseen"] is True
    assert carol_g["stories"][0]["viewed"] is False

    viewed = client.post(f"/stories/{sid}/view", headers=hd)
    assert viewed.status_code == 200

    after = client.get("/stories", headers=hd).json()
    carol_g = next(g for g in after if any(s["id"] == sid for s in g["stories"]))
    assert carol_g["stories"][0]["viewed"] is True
    assert carol_g["has_unseen"] is False


def test_delete_own_story(client: TestClient):
    _create_user(client, "erin_st")
    _create_user(client, "fran_st")
    he = _login(client, "erin_st")
    hf = _login(client, "fran_st")

    story = _post_story(client, he)
    # Fran cannot delete Erin's story
    assert client.delete(f"/stories/{story['id']}", headers=hf).status_code == 404
    assert client.delete(f"/stories/{story['id']}", headers=he).status_code == 204
    feed = client.get("/stories", headers=he).json()
    assert all(s["id"] != story["id"] for g in feed for s in g["stories"])


def test_expire_stories_job(client: TestClient):
    _create_user(client, "gina_st")
    headers = _login(client, "gina_st")
    story = _post_story(client, headers)
    sid = story["id"]
    media = Path(get_settings().media_root) / story["media_path"]
    assert media.is_file()

    with get_db() as conn:
        conn.execute(
            "UPDATE stories SET expires_at = datetime('now', '-1 hour') WHERE id = ?",
            (sid,),
        )

    # Should not appear in active feed
    feed = client.get("/stories", headers=headers).json()
    assert all(s["id"] != sid for g in feed for s in g["stories"])

    expire_stories()
    with get_db() as conn:
        row = conn.execute("SELECT id FROM stories WHERE id = ?", (sid,)).fetchone()
        assert row is None
    assert not media.exists()


def test_view_expired_story_404(client: TestClient):
    _create_user(client, "hank_st")
    headers = _login(client, "hank_st")
    story = _post_story(client, headers)
    with get_db() as conn:
        conn.execute(
            "UPDATE stories SET expires_at = datetime('now', '-1 minute') WHERE id = ?",
            (story["id"],),
        )
    assert client.post(f"/stories/{story['id']}/view", headers=headers).status_code == 404
