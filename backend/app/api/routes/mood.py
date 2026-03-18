from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.core.security import get_current_user
from app.schemas.mood import MoodCreate, MoodOut
from app.services import mood_service

router = APIRouter(prefix="/mood", tags=["mood"])

@router.post("/", response_model=MoodOut, status_code=201)
async def log_mood(data: MoodCreate, user_id: str = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    return await mood_service.create_mood(db, user_id, data)

@router.get("/history", response_model=list[MoodOut])
async def mood_history(user_id: str = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    return await mood_service.get_mood_history(db, user_id)
