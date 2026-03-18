from sqlalchemy import String, Boolean
from sqlalchemy.orm import Mapped, mapped_column
from app.core.database import Base
import uuid

class Resource(Base):
    __tablename__ = "resources"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    name: Mapped[str] = mapped_column(String)
    resource_type: Mapped[str] = mapped_column(String)
    country: Mapped[str] = mapped_column(String)
    phone: Mapped[str | None] = mapped_column(String, nullable=True)
    url: Mapped[str | None] = mapped_column(String, nullable=True)
    languages: Mapped[str] = mapped_column(String, default="en")
    is_free: Mapped[bool] = mapped_column(Boolean, default=True)
    description: Mapped[str | None] = mapped_column(String, nullable=True)
