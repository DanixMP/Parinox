"""Shared image upload: re-encode with Pillow, strip EXIF, cap dimensions."""

from __future__ import annotations

import uuid
from pathlib import Path

from fastapi import HTTPException, UploadFile, status
from PIL import Image, UnidentifiedImageError

from config import get_settings

ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp", "image/gif"}


def ensure_media_dirs() -> None:
    root = Path(get_settings().media_root)
    for sub in ("avatars", "chat", "posts", "stories"):
        (root / sub).mkdir(parents=True, exist_ok=True)


async def save_image(file: UploadFile, category: str) -> tuple[str, int, int]:
    """Save an uploaded image under media/{category}/.

    Returns (relative_path, width, height).
    """
    settings = get_settings()
    if file.content_type and file.content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Unsupported image type")

    data = await file.read()
    if len(data) > settings.max_upload_bytes:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="File too large (max 8MB)")

    ensure_media_dirs()
    try:
        from io import BytesIO

        img = Image.open(BytesIO(data))
        img.load()
    except (UnidentifiedImageError, OSError) as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid image") from exc

    # Strip EXIF by rebuilding without metadata; convert to RGB for JPEG
    img = img.convert("RGB") if img.mode not in ("RGB", "L") else img
    if img.mode == "L":
        img = img.convert("RGB")

    w, h = img.size
    long_edge = max(w, h)
    if long_edge > settings.max_image_edge:
        scale = settings.max_image_edge / long_edge
        img = img.resize((max(1, int(w * scale)), max(1, int(h * scale))), Image.Resampling.LANCZOS)
        w, h = img.size

    filename = f"{uuid.uuid4().hex}.jpg"
    rel_path = f"{category}/{filename}"
    dest = Path(settings.media_root) / rel_path
    img.save(dest, format="JPEG", quality=85, optimize=True)
    return rel_path, w, h


async def save_media_raw(file: UploadFile, category: str, *, allow_video: bool = False) -> tuple[str, bool]:
    """Save image (re-encoded) or short video (raw) for stories. Returns (rel_path, is_video)."""
    settings = get_settings()
    content_type = file.content_type or ""
    is_video = content_type.startswith("video/")
    if is_video:
        if not allow_video:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Video not allowed here")
        data = await file.read()
        if len(data) > settings.max_upload_bytes * 4:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Video too large")
        ensure_media_dirs()
        ext = Path(file.filename or "clip.mp4").suffix or ".mp4"
        filename = f"{uuid.uuid4().hex}{ext}"
        rel_path = f"{category}/{filename}"
        dest = Path(settings.media_root) / rel_path
        dest.write_bytes(data)
        return rel_path, True

    rel, _w, _h = await save_image(file, category)
    return rel, False
