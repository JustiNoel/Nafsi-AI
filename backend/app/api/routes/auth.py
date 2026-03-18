from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.database import get_db
from app.core.security import hash_password, verify_password, create_access_token
from app.models.user import User
from app.schemas.user import UserCreate, Token, UserOut
import uuid

router = APIRouter(prefix="/auth", tags=["auth"])

@router.post("/register", response_model=Token, status_code=201)
async def register(data: UserCreate, db: AsyncSession = Depends(get_db)):
    existing = await db.execute(select(User).where(User.email == data.email))
    if existing.scalar_one_or_none():
        raise HTTPException(400, "Email already registered")
    user = User(id=str(uuid.uuid4()), email=data.email, full_name=data.full_name,
                hashed_password=hash_password(data.password), preferred_language=data.preferred_language)
    db.add(user); await db.commit(); await db.refresh(user)
    return Token(access_token=create_access_token({"sub": user.id}), user=UserOut.model_validate(user))

@router.post("/login", response_model=Token)
async def login(data: UserCreate, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == data.email))
    user = result.scalar_one_or_none()
    if not user or not verify_password(data.password, user.hashed_password):
        raise HTTPException(401, "Invalid credentials")
    return Token(access_token=create_access_token({"sub": user.id}), user=UserOut.model_validate(user))
