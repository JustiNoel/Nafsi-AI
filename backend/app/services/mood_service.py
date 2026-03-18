from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.models.mood import MoodEntry
from app.schemas.mood import MoodCreate
import uuid

async def create_mood(db: AsyncSession, user_id: str, data: MoodCreate) -> MoodEntry:
    entry = MoodEntry(
        id=str(uuid.uuid4()),
        user_id=user_id,
        score=data.score,
        emotion_tags=",".join(data.emotion_tags),
        journal_note=data.journal_note,
    )
    db.add(entry)
    await db.commit()
    await db.refresh(entry)
    return entry

async def get_mood_history(db: AsyncSession, user_id: str, limit: int = 30) -> list[MoodEntry]:
    result = await db.execute(
        select(MoodEntry).where(MoodEntry.user_id == user_id)
        .order_by(MoodEntry.created_at.desc()).limit(limit)
    )
    return list(result.scalars().all())
