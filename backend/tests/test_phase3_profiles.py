"""Phase 3 tests: profiles, avatar, public profile + posts grid."""

from __future__ import annotations

import io
import os
import tempfile
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from PIL import Image

_tmp = tempfile.mkdtemp(prefix="teamapp_p3_")
os.environ["DATABASE_PATH"] = str(Path(_tmp) / "test.db")
os.environ["MEDIA_ROOT"] = str(Path(_tmp) / "media")
os.environ["JWT_SECRET"] = "test-secret-phase3-profiles-long-enough"
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


def _jpeg_bytes(color=(20, 120, 80), size=(64, 48)) -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", size, color).save(buf, format="JPEG")
    return buf.getvalue()


def test_patch_me(client: TestClient):
    _create_user(client, "alice_p")
    token = _login(client, "alice_p")
    headers = {"Authorization": f"Bearer {token}"}

    res = client.patch(
        "/me",
        json={"display_name": "Alice P", "bio": "Hello team"},
        headers=headers,
    )
    assert res.status_code == 200, res.text
    body = res.json()
    assert body["display_name"] == "Alice P"
    assert body["bio"] == "Hello team"

    me = client.get("/me", headers=headers).json()
    assert me["display_name"] == "Alice P"


def test_avatar_upload_and_clear(client: TestClient):
    _create_user(client, "bob_p")
    token = _login(client, "bob_p")
    headers = {"Authorization": f"Bearer {token}"}

    res = client.post(
        "/me/avatar",
        headers=headers,
        files={"avatar": ("a.jpg", _jpeg_bytes(), "image/jpeg")},
    )
    assert res.status_code == 200, res.text
    path = res.json()["avatar_path"]
    assert path and path.startswith("avatars/")

    # Media is served
    media = client.get(f"/media/{path}")
    assert media.status_code == 200
    assert media.headers["content-type"].startswith("image/")

    cleared = client.delete("/me/avatar", headers=headers)
    assert cleared.status_code == 200
    assert cleared.json()["avatar_path"] is None


def test_public_profile_includes_posts(client: TestClient):
    a = _create_user(client, "carol_p")
    token = _login(client, "carol_p")
    headers = {"Authorization": f"Bearer {token}"}

    # Create two posts
    for i, color in enumerate([(200, 50, 50), (50, 50, 200)]):
        r = client.post(
            "/posts",
            headers=headers,
            data={"caption": f"post {i}"},
            files={"image": (f"{i}.jpg", _jpeg_bytes(color=color, size=(80, 100 + i * 10)), "image/jpeg")},
        )
        assert r.status_code == 201, r.text

    profile = client.get(f"/users/{a['id']}", headers=headers)
    assert profile.status_code == 200, profile.text
    body = profile.json()
    assert body["username"] == "carol_p"
    assert body["post_count"] == 2
    assert len(body["posts"]) == 2
    assert body["posts"][0]["id"] > body["posts"][1]["id"]  # newest first

    mine = client.get("/me/profile", headers=headers)
    assert mine.status_code == 200
    assert mine.json()["post_count"] == 2


def test_posts_filter_by_user(client: TestClient):
    a = _create_user(client, "dave_p")
    b = _create_user(client, "erin_p")
    ta = _login(client, "dave_p")
    tb = _login(client, "erin_p")

    client.post(
        "/posts",
        headers={"Authorization": f"Bearer {ta}"},
        data={"caption": "dave"},
        files={"image": ("d.jpg", _jpeg_bytes(), "image/jpeg")},
    )
    client.post(
        "/posts",
        headers={"Authorization": f"Bearer {tb}"},
        data={"caption": "erin"},
        files={"image": ("e.jpg", _jpeg_bytes(color=(10, 10, 10)), "image/jpeg")},
    )

    only_dave = client.get(
        f"/posts?user_id={a['id']}",
        headers={"Authorization": f"Bearer {tb}"},
    ).json()
    assert len(only_dave) == 1
    assert only_dave[0]["user_id"] == a["id"]


def test_patch_rejects_empty_display_name(client: TestClient):
    _create_user(client, "fran_p")
    token = _login(client, "fran_p")
    res = client.patch(
        "/me",
        json={"display_name": "   "},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res.status_code == 400
