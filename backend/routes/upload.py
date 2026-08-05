"""Shared image upload: re-encode with Pillow, strip EXIF, cap dimensions."""

from __future__ import annotations

import uuid
from pathlib import Path

from fastapi import HTTPException, UploadFile, status
from PIL import Image, UnidentifiedImageError

from config import get_settings
from media_access import ALLOWED_FILE_EXTS, BLOCKED_FILE_EXTS

ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp", "image/gif"}


def ensure_media_dirs() -> None:
    root = Path(get_settings().media_root)
    for sub in ("avatars", "banners", "chat", "posts", "stories", "rooms"):
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


async def save_chat_attachment(file: UploadFile) -> dict:
    """Save chat image / video / audio / generic file under media/chat/.

    Returns dict with media_path, media_type, file_name, and optional width/height.
    """
    settings = get_settings()
    content_type = (file.content_type or "").lower()
    original_name = Path(file.filename or "file").name
    ext = Path(original_name).suffix.lower()
    data = await file.read()
    max_bytes = settings.max_upload_bytes * 4  # ~32MB for video/files
    if len(data) > max_bytes:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="File too large")

    ensure_media_dirs()

    image_exts = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp"}
    video_exts = {".mp4", ".webm", ".mov", ".m4v", ".avi"}
    audio_exts = {".mp3", ".m4a", ".aac", ".wav", ".ogg", ".flac", ".opus", ".wma"}

    is_image = content_type in ALLOWED_IMAGE_TYPES or content_type.startswith("image/") or ext in image_exts
    is_video = content_type.startswith("video/") or ext in video_exts
    is_audio = content_type.startswith("audio/") or ext in audio_exts

    if is_image and not is_video:
        from io import BytesIO

        try:
            img = Image.open(BytesIO(data))
            img.load()
        except (UnidentifiedImageError, OSError) as exc:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid image") from exc
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
        rel_path = f"chat/{filename}"
        img.save(Path(settings.media_root) / rel_path, format="JPEG", quality=85, optimize=True)
        return {
            "media_path": rel_path,
            "media_type": "image",
            "file_name": original_name,
            "width": w,
            "height": h,
        }

    if is_video:
        out_ext = ext if ext in video_exts else ".mp4"
        filename = f"{uuid.uuid4().hex}{out_ext}"
        rel_path = f"chat/{filename}"
        (Path(settings.media_root) / rel_path).write_bytes(data)
        return {
            "media_path": rel_path,
            "media_type": "video",
            "file_name": original_name,
        }

    if is_audio:
        out_ext = ext if ext in audio_exts else ".mp3"
        filename = f"{uuid.uuid4().hex}{out_ext}"
        rel_path = f"chat/{filename}"
        (Path(settings.media_root) / rel_path).write_bytes(data)
        return {
            "media_path": rel_path,
            "media_type": "audio",
            "file_name": original_name,
        }

    # Generic attachment — allowlist only (block HTML/SVG/executables)
    if ext in BLOCKED_FILE_EXTS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File type not allowed",
        )
    if ext and ext not in ALLOWED_FILE_EXTS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File type not allowed — use pdf, office docs, zip, or text",
        )
    out_ext = ext if ext in ALLOWED_FILE_EXTS else ".bin"
    filename = f"{uuid.uuid4().hex}{out_ext}"
    rel_path = f"chat/{filename}"
    (Path(settings.media_root) / rel_path).write_bytes(data)
    return {
        "media_path": rel_path,
        "media_type": "file",
        "file_name": original_name,
    }


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

