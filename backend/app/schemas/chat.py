from pydantic import BaseModel

class ChatMessage(BaseModel):
    content: str
    session_id: str | None = None
