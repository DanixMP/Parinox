"""Explore / posts routes."""

from __future__ import annotations

from fastapi import APIRouter, File, Form, HTTPException, Query, UploadFile, status

from auth import CurrentUser
from db import execute, fetchall, fetchone
from routes.upload import save_image

router = APIRouter(tags=["posts"])


def _post_dict(row, liked: bool, like_count: int, comment_count: int) -> dict:
    return {
        "id": row["id"],
        "user_id": row["user_id"],
        "caption": row["caption"],
        "image_path": row["image_path"],
        "width": row["width"],
        "height": row["height"],
        "created_at": row["created_at"],
        "username": row["username"] if "username" in row.keys() else None,
        "display_name": row["display_name"] if "display_name" in row.keys() else None,
        "liked": liked,
        "like_count": like_count,
        "comment_count": comment_count,
    }


@router.get("/posts")
def list_posts(
    user: CurrentUser,
    before_id: int | None = Query(default=None),
    limit: int = Query(default=30, ge=1, le=100),
) -> list[dict]:
    if before_id is not None:
        rows = fetchall(
            "SELECT p.*, u.username, u.display_name FROM posts p "
            "JOIN users u ON u.id = p.user_id "
            "WHERE p.id < ? ORDER BY p.id DESC LIMIT ?",
            (before_id, limit),
        )
    else:
        rows = fetchall(
            "SELECT p.*, u.username, u.display_name FROM posts p "
            "JOIN users u ON u.id = p.user_id "
            "ORDER BY p.id DESC LIMIT ?",
            (limit,),
        )

    result = []
    for row in rows:
        like_count = fetchone(
            "SELECT COUNT(*) AS c FROM post_likes WHERE post_id = ?", (row["id"],)
        )["c"]
        comment_count = fetchone(
            "SELECT COUNT(*) AS c FROM post_comments WHERE post_id = ?", (row["id"],)
        )["c"]
        liked = (
            fetchone(
                "SELECT 1 FROM post_likes WHERE post_id = ? AND user_id = ?",
                (row["id"], user["id"]),
            )
            is not None
        )
        result.append(_post_dict(row, liked, like_count, comment_count))
    return result


@router.post("/posts", status_code=status.HTTP_201_CREATED)
async def create_post(
    user: CurrentUser,
    caption: str = Form(default=""),
    image: UploadFile = File(...),
) -> dict:
    rel, width, height = await save_image(image, "posts")
    post_id = execute(
        "INSERT INTO posts (user_id, caption, image_path, width, height) VALUES (?, ?, ?, ?, ?)",
        (user["id"], caption, rel, width, height),
    )
    row = fetchone(
        "SELECT p.*, u.username, u.display_name FROM posts p "
        "JOIN users u ON u.id = p.user_id WHERE p.id = ?",
        (post_id,),
    )
    assert row is not None
    return _post_dict(row, False, 0, 0)


@router.post("/posts/{post_id}/like")
def toggle_like(post_id: int, user: CurrentUser) -> dict:
    if fetchone("SELECT id FROM posts WHERE id = ?", (post_id,)) is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Post not found")
    existing = fetchone(
        "SELECT 1 FROM post_likes WHERE post_id = ? AND user_id = ?",
        (post_id, user["id"]),
    )
    if existing:
        execute(
            "DELETE FROM post_likes WHERE post_id = ? AND user_id = ?",
            (post_id, user["id"]),
        )
        liked = False
    else:
        execute(
            "INSERT INTO post_likes (post_id, user_id) VALUES (?, ?)",
            (post_id, user["id"]),
        )
        liked = True
    like_count = fetchone(
        "SELECT COUNT(*) AS c FROM post_likes WHERE post_id = ?", (post_id,)
    )["c"]
    return {"post_id": post_id, "liked": liked, "like_count": like_count}


@router.get("/posts/{post_id}/comments")
def list_comments(post_id: int, _user: CurrentUser) -> list[dict]:
    if fetchone("SELECT id FROM posts WHERE id = ?", (post_id,)) is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Post not found")
    rows = fetchall(
        "SELECT c.id, c.post_id, c.user_id, c.content, c.created_at, "
        "u.username, u.display_name "
        "FROM post_comments c JOIN users u ON u.id = c.user_id "
        "WHERE c.post_id = ? ORDER BY c.id ASC",
        (post_id,),
    )
    return [dict(r) for r in rows]


@router.post("/posts/{post_id}/comments", status_code=status.HTTP_201_CREATED)
def add_comment(post_id: int, user: CurrentUser, content: str = Form(...)) -> dict:
    if fetchone("SELECT id FROM posts WHERE id = ?", (post_id,)) is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Post not found")
    if not content.strip():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Empty comment")
    cid = execute(
        "INSERT INTO post_comments (post_id, user_id, content) VALUES (?, ?, ?)",
        (post_id, user["id"], content.strip()),
    )
    row = fetchone(
        "SELECT c.id, c.post_id, c.user_id, c.content, c.created_at, "
        "u.username, u.display_name "
        "FROM post_comments c JOIN users u ON u.id = c.user_id WHERE c.id = ?",
        (cid,),
    )
    assert row is not None
    return dict(row)
