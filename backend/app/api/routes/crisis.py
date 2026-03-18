from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.crisis import CrisisEvent
from pydantic import BaseModel
import uuid

router = APIRouter(prefix="/crisis", tags=["crisis"])

class CrisisReport(BaseModel):
    trigger_text: str
    crisis_score: float
    severity: str

@router.post("/report", status_code=201)
async def report_crisis(data: CrisisReport, user_id: str = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    event = CrisisEvent(id=str(uuid.uuid4()), user_id=user_id, severity=data.severity,
                        trigger_text=data.trigger_text, crisis_score=data.crisis_score)
    db.add(event); await db.commit()
    return {"message": "Crisis event logged", "id": event.id}
