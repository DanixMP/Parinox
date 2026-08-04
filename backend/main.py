"""Team App FastAPI entrypoint — mounts routers, CORS, startup tasks."""

from __future__ import annotations

from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from config import get_settings
from db import init_db
from routes import auth, chat, livekit, posts, stories, users
from routes.upload import ensure_media_dirs
from scheduler import start_scheduler, stop_scheduler


@asynccontextmanager
async def lifespan(_app: FastAPI):
    init_db()
    ensure_media_dirs()
    start_scheduler()
    yield
    stop_scheduler()


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(title="Team App", version="0.1.0", lifespan=lifespan)

    origins = [o.strip() for o in settings.cors_origins.split(",") if o.strip()]
    app.add_middleware(
        CORSMiddleware,
        allow_origins=origins if origins != ["*"] else ["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Routes without /api prefix; nginx should strip /api/ when proxying
    # (see deploy/nginx.conf: proxy_pass .../ with trailing slash).
    for mod in (auth, users, chat, posts, stories, livekit):
        app.include_router(mod.router)

    media_path = Path(settings.media_root)
    media_path.mkdir(parents=True, exist_ok=True)
    app.mount("/media", StaticFiles(directory=str(media_path)), name="media")

    @app.get("/health")
    def health() -> dict:
        return {"status": "ok"}

    return app


app = create_app()
