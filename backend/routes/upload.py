"""Shared image upload processing — re-encode, strip EXIF, cap dimensions."""

from __future__ import annotations

import uuid
from io import BytesIO
from pathlib import Path

from fastapi import HTTPException, UploadFile, status
from PIL import Image, UnidentifiedImageError

from config import get_settings

ALLOWED_CONTENT_TYPES = {
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/gif",
}


async def save_image(upload: UploadFile, category: str) -> tuple[str, int, int]:
    """
    Save an uploaded image under media/{category}/.

    Returns (relative_path, width, height).
    """
    settings = get_settings()
    if upload.content_type and upload.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported image type: {upload.content_type}",
        )

    data = await upload.read()
    if not data:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Empty file")
    if len(data) > settings.max_upload_bytes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File exceeds {settings.max_upload_bytes} bytes",
        )

    try:
        image = Image.open(BytesIO(data))
        image.load()
    except UnidentifiedImageError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid image file",
        ) from exc

    # Convert to RGB (strips EXIF / alpha quirks for JPEG output)
    if image.mode not in ("RGB", "L"):
        image = image.convert("RGB")
    elif image.mode == "L":
        image = image.convert("RGB")

    # Cap long edge
    max_edge = settings.max_image_edge
    w, h = image.size
    long_edge = max(w, h)
    if long_edge > max_edge:
        scale = max_edge / float(long_edge)
        image = image.resize(
            (max(1, int(w * scale)), max(1, int(h * scale))),
            Image.Resampling.LANCZOS,
        )

    width, height = image.size
    filename = f"{uuid.uuid4().hex}.jpg"
    rel_path = f"{category}/{filename}"
    dest = Path(settings.media_root) / rel_path
    dest.parent.mkdir(parents=True, exist_ok=True)
    image.save(dest, format="JPEG", quality=85, optimize=True)
    return rel_path, width, height
