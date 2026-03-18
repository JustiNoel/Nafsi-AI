from pydantic import BaseModel
from datetime import datetime

class MoodCreate(BaseModel):
    score: int
    emotion_tags: list[str] = []
    journal_note: str | None = None

class MoodOut(BaseModel):
    id: str
    score: int
    emotion_tags: str
    journal_note: str | None
    created_at: datetime
    class Config:
        from_attributes = True
