"""Parinox FastAPI application — Team App backend."""

from __future__ import annotations

from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import APIRouter, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from config import get_settings
from db import init_db
from scheduler import start_scheduler, stop_scheduler
from routes import auth, chat, livekit, posts, stories, users


@asynccontextmanager
async def lifespan(_app: FastAPI):
    init_db()
    start_scheduler()
    try:
        yield
    finally:
        stop_scheduler()


def create_app() -> FastAPI:
    settings = get_settings()
    Path(settings.media_root).mkdir(parents=True, exist_ok=True)

    app = FastAPI(title="Parinox", version="0.1.0", lifespan=lifespan)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origin_list,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Routes live at root. nginx may expose them under /api/ by stripping the prefix
    # (see deploy/nginx.conf.example).
    api = APIRouter()
    api.include_router(auth.router)
    api.include_router(users.router)
    api.include_router(chat.router)
    api.include_router(posts.router)
    api.include_router(stories.router)
    api.include_router(livekit.router)
    app.include_router(api)
    app.include_router(api, prefix="/api")

    app.mount(
        "/media",
        StaticFiles(directory=settings.media_root),
        name="media",
    )

    @app.get("/health")
    def health() -> dict:
        return {"status": "ok"}

    return app


app = create_app()
