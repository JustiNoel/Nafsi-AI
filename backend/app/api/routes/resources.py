from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.resource import Resource
from app.schemas.resource import ResourceOut

router = APIRouter(prefix="/resources", tags=["resources"])

@router.get("/", response_model=list[ResourceOut])
async def list_resources(country: str | None = Query(None), resource_type: str | None = Query(None),
                          db: AsyncSession = Depends(get_db), _: str = Depends(get_current_user)):
    q = select(Resource)
    if country: q = q.where(Resource.country.ilike(f"%{country}%"))
    if resource_type: q = q.where(Resource.resource_type == resource_type)
    result = await db.execute(q)
    return list(result.scalars().all())
