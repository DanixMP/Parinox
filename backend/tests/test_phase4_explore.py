"""Phase 4 tests: explore posts, likes, comments, get-by-id."""

from __future__ import annotations

import io
import os
import tempfile
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from PIL import Image

_tmp = tempfile.mkdtemp(prefix="teamapp_p4_")
os.environ["DATABASE_PATH"] = str(Path(_tmp) / "test.db")
os.environ["MEDIA_ROOT"] = str(Path(_tmp) / "media")
os.environ["JWT_SECRET"] = "test-secret-phase4-explore-long-enough"
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


def _login(client: TestClient, username: str) -> dict:
    r = client.post("/login", json={"username": username, "password": "password123"})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _jpeg(size=(120, 80), color=(30, 90, 140)) -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", size, color).save(buf, format="JPEG")
    return buf.getvalue()


def _create_post(client: TestClient, headers: dict, caption: str = "hi", size=(100, 150)) -> dict:
    r = client.post(
        "/posts",
        headers=headers,
        data={"caption": caption},
        files={"image": ("p.jpg", _jpeg(size=size), "image/jpeg")},
    )
    assert r.status_code == 201, r.text
    return r.json()


def test_create_and_list_posts_newest_first(client: TestClient):
    _create_user(client, "alice_ex")
    headers = _login(client, "alice_ex")
    p1 = _create_post(client, headers, "first", size=(80, 120))
    p2 = _create_post(client, headers, "second", size=(100, 60))

    feed = client.get("/posts", headers=headers).json()
    assert len(feed) >= 2
    assert feed[0]["id"] == p2["id"]
    assert feed[1]["id"] == p1["id"]
    # Masonry dimensions preserved
    assert feed[0]["width"] > 0 and feed[0]["height"] > 0


def test_before_id_pagination(client: TestClient):
    bob = _create_user(client, "bob_ex")
    headers = _login(client, "bob_ex")
    ids = [_create_post(client, headers, f"n{i}")["id"] for i in range(3)]
    page = client.get(
        f"/posts?user_id={bob['id']}&before_id={ids[-1]}&limit=10",
        headers=headers,
    ).json()
    assert all(p["id"] < ids[-1] for p in page)
    assert {p["id"] for p in page} == set(ids[:-1])


def test_get_post_like_and_comment(client: TestClient):
    a = _create_user(client, "carol_ex")
    _create_user(client, "dave_ex")
    ha = _login(client, "carol_ex")
    hd = _login(client, "dave_ex")

    post = _create_post(client, ha, "like me")
    pid = post["id"]

    got = client.get(f"/posts/{pid}", headers=hd).json()
    assert got["id"] == pid
    assert got["liked"] is False
    assert got["like_count"] == 0
    assert got["user_id"] == a["id"]

    like = client.post(f"/posts/{pid}/like", headers=hd).json()
    assert like["liked"] is True
    assert like["like_count"] == 1

    # Toggle off
    unlike = client.post(f"/posts/{pid}/like", headers=hd).json()
    assert unlike["liked"] is False
    assert unlike["like_count"] == 0

    client.post(f"/posts/{pid}/like", headers=hd)
    comment = client.post(
        f"/posts/{pid}/comments",
        headers=hd,
        json={"content": "nice shot"},
    )
    assert comment.status_code == 201, comment.text
    assert comment.json()["content"] == "nice shot"

    comments = client.get(f"/posts/{pid}/comments", headers=ha).json()
    assert len(comments) == 1
    assert comments[0]["display_name"] == "Dave_Ex" or comments[0]["username"] == "dave_ex"

    detail = client.get(f"/posts/{pid}", headers=ha).json()
    assert detail["like_count"] == 1
    assert detail["comment_count"] == 1


def test_get_missing_post(client: TestClient):
    _create_user(client, "erin_ex")
    headers = _login(client, "erin_ex")
    assert client.get("/posts/99999", headers=headers).status_code == 404
