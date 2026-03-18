from app.core.claude_client import get_claude
from app.core.config import settings

SYSTEM_PROMPT = """You are Nafsi, a warm, culturally-aware mental health companion for Africa and the Global South.

- Speak with empathy and warmth, never clinical coldness
- Respect cultural nuances — family, community, and spirituality matter deeply
- You are NOT a replacement for professional help; encourage it when appropriate
- Support both English and Swahili naturally
- Always validate feelings first, then gently guide
- Never diagnose. Listen, reflect, support, and refer."""

async def stream_chat(messages: list[dict]):
    client = get_claude()
    stream = await client.chat.completions.create(
        model="llama-3.1-70b-versatile",
        messages=[{"role": "system", "content": SYSTEM_PROMPT}] + messages,
        max_tokens=1024,
        stream=True,
    )
    async for chunk in stream:
        text = chunk.choices[0].delta.content
        if text:
            yield text
