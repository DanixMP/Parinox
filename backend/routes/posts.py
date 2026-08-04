"""Explore / posts routes (Phase 4 scaffolding — fully wired for early use)."""

from __future__ import annotations

from fastapi import APIRouter, File, Form, HTTPException, Query, UploadFile, status

from auth import CurrentUser
from db import get_db
from models import CommentCreate
from routes.upload import save_image

router = APIRouter(tags=["posts"])


def _post_dict(row: dict, liked: bool = False, like_count: int = 0, comment_count: int = 0) -> dict:
    return {
        "id": row["id"],
        "user_id": row["user_id"],
        "caption": row.get("caption") or "",
        "image_path": row["image_path"],
        "width": row["width"],
        "height": row["height"],
        "created_at": row["created_at"],
        "display_name": row.get("display_name"),
        "username": row.get("username"),
        "liked": liked,
        "like_count": like_count,
        "comment_count": comment_count,
    }


@router.get("/posts")
def list_posts(
    user: CurrentUser,
    before_id: int | None = Query(default=None),
    user_id: int | None = Query(default=None),
    limit: int = Query(default=30, ge=1, le=100),
) -> list[dict]:
    with get_db() as conn:
        clauses = []
        params: list = []
        if user_id is not None:
            clauses.append("p.user_id = ?")
            params.append(user_id)
        if before_id is not None:
            clauses.append("p.id < ?")
            params.append(before_id)
        where = f"WHERE {' AND '.join(clauses)}" if clauses else ""
        params.append(limit)
        rows = conn.execute(
            f"""
            SELECT p.*, u.display_name, u.username
            FROM posts p JOIN users u ON u.id = p.user_id
            {where}
            ORDER BY p.id DESC LIMIT ?
            """,
            params,
        ).fetchall()

        result = []
        for r in rows:
            d = dict(r)
            like_count = conn.execute(
                "SELECT COUNT(*) AS c FROM post_likes WHERE post_id = ?", (d["id"],)
            ).fetchone()["c"]
            liked = conn.execute(
                "SELECT 1 FROM post_likes WHERE post_id = ? AND user_id = ?",
                (d["id"], user["id"]),
            ).fetchone() is not None
            comment_count = conn.execute(
                "SELECT COUNT(*) AS c FROM post_comments WHERE post_id = ?", (d["id"],)
            ).fetchone()["c"]
            result.append(_post_dict(d, liked=liked, like_count=like_count, comment_count=comment_count))
        return result


@router.post("/posts", status_code=status.HTTP_201_CREATED)
async def create_post(
    user: CurrentUser,
    caption: str = Form(default=""),
    image: UploadFile = File(...),
) -> dict:
    rel, w, h = await save_image(image, "posts")
    with get_db() as conn:
        cur = conn.execute(
            "INSERT INTO posts (user_id, caption, image_path, width, height) VALUES (?, ?, ?, ?, ?)",
            (user["id"], caption, rel, w, h),
        )
        post_id = cur.lastrowid
        row = conn.execute(
            """
            SELECT p.*, u.display_name, u.username FROM posts p
            JOIN users u ON u.id = p.user_id WHERE p.id = ?
            """,
            (post_id,),
        ).fetchone()
    return _post_dict(dict(row))


@router.get("/posts/{post_id}")
def get_post(post_id: int, user: CurrentUser) -> dict:
    with get_db() as conn:
        row = conn.execute(
            """
            SELECT p.*, u.display_name, u.username FROM posts p
            JOIN users u ON u.id = p.user_id WHERE p.id = ?
            """,
            (post_id,),
        ).fetchone()
        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Post not found")
        d = dict(row)
        like_count = conn.execute(
            "SELECT COUNT(*) AS c FROM post_likes WHERE post_id = ?", (post_id,)
        ).fetchone()["c"]
        liked = conn.execute(
            "SELECT 1 FROM post_likes WHERE post_id = ? AND user_id = ?",
            (post_id, user["id"]),
        ).fetchone() is not None
        comment_count = conn.execute(
            "SELECT COUNT(*) AS c FROM post_comments WHERE post_id = ?", (post_id,)
        ).fetchone()["c"]
        return _post_dict(d, liked=liked, like_count=like_count, comment_count=comment_count)


@router.post("/posts/{post_id}/like")
def toggle_like(post_id: int, user: CurrentUser) -> dict:
    with get_db() as conn:
        post = conn.execute("SELECT id FROM posts WHERE id = ?", (post_id,)).fetchone()
        if not post:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Post not found")
        existing = conn.execute(
            "SELECT 1 FROM post_likes WHERE post_id = ? AND user_id = ?",
            (post_id, user["id"]),
        ).fetchone()
        if existing:
            conn.execute(
                "DELETE FROM post_likes WHERE post_id = ? AND user_id = ?",
                (post_id, user["id"]),
            )
            liked = False
        else:
            conn.execute(
                "INSERT INTO post_likes (post_id, user_id) VALUES (?, ?)",
                (post_id, user["id"]),
            )
            liked = True
        like_count = conn.execute(
            "SELECT COUNT(*) AS c FROM post_likes WHERE post_id = ?", (post_id,)
        ).fetchone()["c"]
    return {"liked": liked, "like_count": like_count}


@router.get("/posts/{post_id}/comments")
def list_comments(post_id: int, _user: CurrentUser) -> list[dict]:
    with get_db() as conn:
        rows = conn.execute(
            """
            SELECT c.*, u.display_name, u.username FROM post_comments c
            JOIN users u ON u.id = c.user_id
            WHERE c.post_id = ? ORDER BY c.id ASC
            """,
            (post_id,),
        ).fetchall()
    return [dict(r) for r in rows]


@router.post("/posts/{post_id}/comments", status_code=status.HTTP_201_CREATED)
def add_comment(post_id: int, body: CommentCreate, user: CurrentUser) -> dict:
    with get_db() as conn:
        post = conn.execute("SELECT id FROM posts WHERE id = ?", (post_id,)).fetchone()
        if not post:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Post not found")
        cur = conn.execute(
            "INSERT INTO post_comments (post_id, user_id, content) VALUES (?, ?, ?)",
            (post_id, user["id"], body.content),
        )
        cid = cur.lastrowid
        row = conn.execute(
            """
            SELECT c.*, u.display_name, u.username FROM post_comments c
            JOIN users u ON u.id = c.user_id WHERE c.id = ?
            """,
            (cid,),
        ).fetchone()
    return dict(row)
