from sqlalchemy import String, DateTime, Integer, ForeignKey, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.core.database import Base
import uuid

class MoodEntry(Base):
    __tablename__ = "mood_entries"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String, ForeignKey("users.id"))
    score: Mapped[int] = mapped_column(Integer)
    emotion_tags: Mapped[str] = mapped_column(String, default="")
    journal_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    user = relationship("User", back_populates="moods")
