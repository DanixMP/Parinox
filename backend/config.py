"""Application settings loaded from environment variables."""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict

_DEV_JWT = "dev-secret-change-me"
_DEV_ADMIN = "dev-admin-token"
_DEV_LK_SECRET = "secret"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_env: str = "development"  # development | production
    allow_insecure_defaults: bool = True
    jwt_secret: str = _DEV_JWT
    jwt_expire_days: int = 7
    admin_token: str = _DEV_ADMIN
    livekit_api_key: str = "devkey"
    livekit_api_secret: str = _DEV_LK_SECRET
    livekit_ws_url: str = "ws://127.0.0.1:7880"
    media_root: str = "media"
    database_path: str = "team_app.db"
    cors_origins: str = "*"
    max_upload_bytes: int = 8 * 1024 * 1024
    max_image_edge: int = 2000

    @property
    def is_production(self) -> bool:
        return self.app_env.strip().lower() == "production"


def assert_secure_settings(settings: Settings) -> None:
    """Refuse known-weak secrets outside local insecure mode."""
    if settings.allow_insecure_defaults and not settings.is_production:
        return
    weak: list[str] = []
    if settings.jwt_secret in {_DEV_JWT, "change-me-to-a-long-random-string"} or len(settings.jwt_secret) < 24:
        weak.append("JWT_SECRET")
    if settings.admin_token in {_DEV_ADMIN, "change-me-admin-bootstrap-token"} or len(settings.admin_token) < 16:
        weak.append("ADMIN_TOKEN")
    if settings.livekit_api_secret in {_DEV_LK_SECRET, "devsecret"}:
        weak.append("LIVEKIT_API_SECRET")
    if weak:
        raise RuntimeError(
            "Insecure settings for production: "
            + ", ".join(weak)
            + ". Set strong secrets and ALLOW_INSECURE_DEFAULTS=false."
        )


@lru_cache
def get_settings() -> Settings:
    return Settings()
