from groq import AsyncGroq
from app.core.config import settings

_client = None

def get_claude():
    global _client
    if _client is None:
        _client = AsyncGroq(api_key=settings.ANTHROPIC_API_KEY)
    return _client
