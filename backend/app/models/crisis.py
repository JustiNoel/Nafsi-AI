from sqlalchemy import String, DateTime, Float, ForeignKey, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.core.database import Base
import uuid

class CrisisEvent(Base):
    __tablename__ = "crisis_events"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String, ForeignKey("users.id"))
    severity: Mapped[str] = mapped_column(String)
    trigger_text: Mapped[str] = mapped_column(Text)
    crisis_score: Mapped[float] = mapped_column(Float)
    resolved: Mapped[bool] = mapped_column(default=False)
    detected_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    user = relationship("User", back_populates="crisis_events")
