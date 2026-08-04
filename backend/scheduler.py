"""APScheduler jobs — story expiry cleanup."""

from __future__ import annotations

import logging
from pathlib import Path

from apscheduler.schedulers.background import BackgroundScheduler

from config import get_settings
from db import fetchall, execute

logger = logging.getLogger(__name__)
_scheduler: BackgroundScheduler | None = None


def expire_stories() -> None:
    settings = get_settings()
    rows = fetchall(
        "SELECT id, media_path FROM stories WHERE expires_at < datetime('now')"
    )
    if not rows:
        return
    for row in rows:
        media_path = row["media_path"]
        if media_path:
            full = Path(settings.media_root) / media_path
            try:
                if full.is_file():
                    full.unlink()
            except OSError as exc:
                logger.warning("Failed to delete story media %s: %s", full, exc)
        execute("DELETE FROM stories WHERE id = ?", (row["id"],))
    logger.info("Expired %d stories", len(rows))


def start_scheduler() -> None:
    global _scheduler
    if _scheduler is not None and _scheduler.running:
        return
    _scheduler = BackgroundScheduler()
    _scheduler.add_job(expire_stories, "interval", minutes=15, id="expire_stories")
    _scheduler.start()


def stop_scheduler() -> None:
    global _scheduler
    if _scheduler is None:
        return
    if _scheduler.running:
        try:
            _scheduler.shutdown(wait=False)
        except Exception as exc:  # pragma: no cover
            logger.warning("Scheduler shutdown: %s", exc)
    _scheduler = None
