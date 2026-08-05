"""Team App FastAPI entrypoint — mounts routers, CORS, startup tasks."""

from __future__ import annotations

from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from config import assert_secure_settings, get_settings
from db import init_db
from routes import auth, chat, livekit, media, posts, stories, users
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
    assert_secure_settings(settings)

    docs = None if settings.is_production or not settings.allow_insecure_defaults else "/docs"
    redoc = None if settings.is_production or not settings.allow_insecure_defaults else "/redoc"
    openapi = None if settings.is_production or not settings.allow_insecure_defaults else "/openapi.json"

    app = FastAPI(
        title="Team App",
        version="0.1.0",
        lifespan=lifespan,
        docs_url=docs,
        redoc_url=redoc,
        openapi_url=openapi,
    )

    origins = [o.strip() for o in settings.cors_origins.split(",") if o.strip()]
    wildcard = origins == ["*"]
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"] if wildcard else origins,
        # Credentials + wildcard origins is unsafe; disable credentials when open.
        allow_credentials=not wildcard,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.middleware("http")
    async def security_headers(request, call_next):
        response = await call_next(request)
        response.headers.setdefault("X-Content-Type-Options", "nosniff")
        response.headers.setdefault("X-Frame-Options", "DENY")
        response.headers.setdefault("Referrer-Policy", "no-referrer")
        if settings.is_production:
            response.headers.setdefault(
                "Strict-Transport-Security",
                "max-age=31536000; includeSubDomains",
            )
        return response

    # Routes without /api prefix; nginx should strip /api/ when proxying
    # (see deploy/nginx.conf: proxy_pass .../ with trailing slash).
    for mod in (auth, users, chat, posts, stories, livekit, media):
        app.include_router(mod.router)

    media_path = Path(settings.media_root)
    media_path.mkdir(parents=True, exist_ok=True)
    # Media is served via authenticated routes.media — not public StaticFiles.

    @app.get("/health")
    def health() -> dict:
        return {"status": "ok"}

    return app


app = create_app()
