from pydantic_settings import BaseSettings
from functools import lru_cache

class Settings(BaseSettings):
    APP_ENV: str = "development"
    SECRET_KEY: str = "dev-secret-change-me"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440
    DATABASE_URL: str = "postgresql+asyncpg://nafsi:nafsi@localhost:5432/nafsidb"
    REDIS_URL: str = "redis://localhost:6379"
    ANTHROPIC_API_KEY: str = ""
    CLAUDE_MODEL: str = "claude-sonnet-4-5"
    MAX_TOKENS: int = 1024
    class Config:
        env_file = ".env"

@lru_cache
def get_settings() -> Settings:
    return Settings()

settings = get_settings()
