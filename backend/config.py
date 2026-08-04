"""Application settings loaded from environment variables."""

from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

BACKEND_DIR = Path(__file__).resolve().parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=BACKEND_DIR / ".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    jwt_secret: str = "dev-insecure-change-me"
    jwt_expire_days: int = 7
    database_path: str = str(BACKEND_DIR / "data" / "parinox.db")
    media_root: str = str(BACKEND_DIR / "media")
    cors_origins: str = "*"
    livekit_api_key: str = "devkey"
    livekit_api_secret: str = "secret"
    livekit_ws_url: str = "ws://127.0.0.1:7880"
    admin_token: str = "dev-admin-token"
    max_upload_bytes: int = 8 * 1024 * 1024
    max_image_edge: int = 2000

    @property
    def cors_origin_list(self) -> list[str]:
        if self.cors_origins.strip() == "*":
            return ["*"]
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
