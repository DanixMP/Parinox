"""Application settings loaded from environment variables."""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    jwt_secret: str = "dev-secret-change-me"
    jwt_expire_days: int = 7
    admin_token: str = "dev-admin-token"
    livekit_api_key: str = "devkey"
    livekit_api_secret: str = "secret"
    livekit_ws_url: str = "ws://127.0.0.1:7880"
    media_root: str = "media"
    database_path: str = "team_app.db"
    cors_origins: str = "*"
    max_upload_bytes: int = 8 * 1024 * 1024
    max_image_edge: int = 2000


@lru_cache
def get_settings() -> Settings:
    return Settings()
