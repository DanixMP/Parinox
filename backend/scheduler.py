"""APScheduler jobs — story expiry cleanup every 15 minutes."""

from __future__ import annotations

import logging
from pathlib import Path

from apscheduler.schedulers.background import BackgroundScheduler

from config import get_settings
from db import get_db

logger = logging.getLogger(__name__)
_scheduler: BackgroundScheduler | None = None


def expire_stories() -> None:
    settings = get_settings()
    media_root = Path(settings.media_root)
    with get_db() as conn:
        rows = conn.execute(
            "SELECT id, media_path FROM stories WHERE expires_at < datetime('now')"
        ).fetchall()
        if not rows:
            return
        ids = [r["id"] for r in rows]
        placeholders = ",".join("?" * len(ids))
        conn.execute(f"DELETE FROM stories WHERE id IN ({placeholders})", ids)
        for row in rows:
            path = media_root / row["media_path"]
            try:
                if path.is_file():
                    path.unlink()
            except OSError as exc:
                logger.warning("Failed to delete expired story media %s: %s", path, exc)
        logger.info("Expired %d stories", len(ids))


def start_scheduler() -> None:
    global _scheduler
    if _scheduler is not None and _scheduler.running:
        return
    _scheduler = BackgroundScheduler()
    _scheduler.add_job(expire_stories, "interval", minutes=15, id="expire_stories", replace_existing=True)
    _scheduler.start()


def stop_scheduler() -> None:
    global _scheduler
    if _scheduler is not None and _scheduler.running:
        _scheduler.shutdown(wait=False)
    _scheduler = None
