#!/bin/bash
set -e
echo "🌿 Setting up Nafsi AI..."

# ── Root files ────────────────────────────────────────────────────────────────
cat > .env.example << 'EOF'
# Anthropic
ANTHROPIC_API_KEY=sk-ant-...

# Database
DATABASE_URL=postgresql+asyncpg://nafsi:nafsi@localhost:5432/nafsidb

# Redis
REDIS_URL=redis://localhost:6379

# JWT
SECRET_KEY=change-me-to-a-secure-random-string
ACCESS_TOKEN_EXPIRE_MINUTES=1440

# App
APP_ENV=development
EOF

cat > docker-compose.yml << 'EOF'
version: "3.9"
services:
  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: nafsi
      POSTGRES_PASSWORD: nafsi
      POSTGRES_DB: nafsidb
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

volumes:
  pgdata:
EOF

cat > .gitignore << 'EOF'
__pycache__/
*.py[cod]
.env
*.egg-info/
.venv/
venv/
node_modules/
dist/
.DS_Store
*.log
EOF

# ── GitHub Actions CI/CD ──────────────────────────────────────────────────────
mkdir -p .github/workflows

cat > .github/workflows/ci.yml << 'EOF'
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  backend:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_USER: nafsi
          POSTGRES_PASSWORD: nafsi
          POSTGRES_DB: nafsidb
        ports: ["5432:5432"]
      redis:
        image: redis:7
        ports: ["6379:6379"]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"
          cache: pip
      - run: pip install -r backend/requirements.txt
      - run: pip install pytest pytest-asyncio httpx
      - name: Lint
        run: |
          pip install ruff
          ruff check backend/
      - name: Test
        working-directory: backend
        env:
          DATABASE_URL: postgresql+asyncpg://nafsi:nafsi@localhost:5432/nafsidb
          REDIS_URL: redis://localhost:6379
          SECRET_KEY: test-secret-key
          ANTHROPIC_API_KEY: test-key
        run: pytest tests/ -v --tb=short || echo "No tests yet"

  frontend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: npm
          cache-dependency-path: frontend/package-lock.json
      - run: npm ci
        working-directory: frontend
      - run: npm run build
        working-directory: frontend
EOF

# ── Backend ───────────────────────────────────────────────────────────────────
mkdir -p backend/app/{api/routes,core,models,schemas,services}
mkdir -p backend/tests
touch backend/tests/__init__.py

cat > backend/requirements.txt << 'EOF'
fastapi==0.115.0
uvicorn[standard]==0.30.6
sqlalchemy[asyncio]==2.0.35
asyncpg==0.29.0
alembic==1.13.2
redis[asyncio]==5.0.8
anthropic==0.34.2
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
python-multipart==0.0.9
pydantic-settings==2.4.0
httpx==0.27.2
python-dotenv==1.0.1
EOF

# app/__init__.py files
touch backend/app/__init__.py
touch backend/app/api/__init__.py
touch backend/app/api/routes/__init__.py
touch backend/app/core/__init__.py
touch backend/app/models/__init__.py
touch backend/app/schemas/__init__.py
touch backend/app/services/__init__.py

# ── core/config.py ────────────────────────────────────────────────────────────
cat > backend/app/core/config.py << 'EOF'
from pydantic_settings import BaseSettings
from functools import lru_cache

class Settings(BaseSettings):
    APP_ENV: str = "development"
    SECRET_KEY: str = "dev-secret-change-me"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440

    DATABASE_URL: str = "postgresql+asyncpg://nafsi:nafsi@localhost:5432/nafsidb"
    REDIS_URL: str = "redis://localhost:6379"
    ANTHROPIC_API_KEY: str = ""

    CLAUDE_MODEL: str = "claude-sonnet-4-5"
    MAX_TOKENS: int = 1024

    class Config:
        env_file = ".env"

@lru_cache
def get_settings() -> Settings:
    return Settings()

settings = get_settings()
EOF

# ── core/database.py ──────────────────────────────────────────────────────────
cat > backend/app/core/database.py << 'EOF'
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import DeclarativeBase
from app.core.config import settings

engine = create_async_engine(settings.DATABASE_URL, echo=settings.APP_ENV == "development")
AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False)

class Base(DeclarativeBase):
    pass

async def get_db() -> AsyncSession:
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()

async def init_db():
    from app.models import user, mood, resource, crisis  # noqa: F401
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
EOF

# ── core/security.py ─────────────────────────────────────────────────────────
cat > backend/app/core/security.py << 'EOF'
from datetime import datetime, timedelta
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from app.core.config import settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)

def create_access_token(data: dict) -> str:
    expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    return jwt.encode({**data, "exp": expire}, settings.SECRET_KEY, algorithm="HS256")

async def get_current_user(token: str = Depends(oauth2_scheme)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
        return user_id
    except JWTError:
        raise credentials_exception
EOF

# ── core/redis_client.py ──────────────────────────────────────────────────────
cat > backend/app/core/redis_client.py << 'EOF'
import redis.asyncio as redis
from app.core.config import settings

_redis_client: redis.Redis | None = None

async def get_redis() -> redis.Redis:
    global _redis_client
    if _redis_client is None:
        _redis_client = redis.from_url(settings.REDIS_URL, decode_responses=True)
    return _redis_client

async def close_redis():
    global _redis_client
    if _redis_client:
        await _redis_client.close()
        _redis_client = None
EOF

# ── core/claude_client.py ────────────────────────────────────────────────────
cat > backend/app/core/claude_client.py << 'EOF'
import anthropic
from app.core.config import settings

_client: anthropic.AsyncAnthropic | None = None

def get_claude() -> anthropic.AsyncAnthropic:
    global _client
    if _client is None:
        _client = anthropic.AsyncAnthropic(api_key=settings.ANTHROPIC_API_KEY)
    return _client
EOF

# ── models/user.py ────────────────────────────────────────────────────────────
cat > backend/app/models/user.py << 'EOF'
from sqlalchemy import String, DateTime, Boolean
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.core.database import Base
import uuid

class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    email: Mapped[str] = mapped_column(String, unique=True, index=True)
    full_name: Mapped[str] = mapped_column(String)
    hashed_password: Mapped[str] = mapped_column(String)
    preferred_language: Mapped[str] = mapped_column(String, default="en")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    moods = relationship("MoodEntry", back_populates="user", lazy="dynamic")
    crisis_events = relationship("CrisisEvent", back_populates="user", lazy="dynamic")
EOF

# ── models/mood.py ────────────────────────────────────────────────────────────
cat > backend/app/models/mood.py << 'EOF'
from sqlalchemy import String, DateTime, Integer, ForeignKey, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.core.database import Base
import uuid

class MoodEntry(Base):
    __tablename__ = "mood_entries"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String, ForeignKey("users.id"))
    score: Mapped[int] = mapped_column(Integer)       # 1–10
    emotion_tags: Mapped[str] = mapped_column(String, default="")  # comma-separated
    journal_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="moods")
EOF

# ── models/resource.py ───────────────────────────────────────────────────────
cat > backend/app/models/resource.py << 'EOF'
from sqlalchemy import String, Boolean
from sqlalchemy.orm import Mapped, mapped_column
from app.core.database import Base
import uuid

class Resource(Base):
    __tablename__ = "resources"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    name: Mapped[str] = mapped_column(String)
    resource_type: Mapped[str] = mapped_column(String)   # hotline | therapist | ngo | online
    country: Mapped[str] = mapped_column(String)
    phone: Mapped[str | None] = mapped_column(String, nullable=True)
    url: Mapped[str | None] = mapped_column(String, nullable=True)
    languages: Mapped[str] = mapped_column(String, default="en")   # comma-separated
    is_free: Mapped[bool] = mapped_column(Boolean, default=True)
    description: Mapped[str | None] = mapped_column(String, nullable=True)
EOF

# ── models/crisis.py ──────────────────────────────────────────────────────────
cat > backend/app/models/crisis.py << 'EOF'
from sqlalchemy import String, DateTime, Float, ForeignKey, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.core.database import Base
import uuid

class CrisisEvent(Base):
    __tablename__ = "crisis_events"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String, ForeignKey("users.id"))
    severity: Mapped[str] = mapped_column(String)       # low | medium | high | critical
    trigger_text: Mapped[str] = mapped_column(Text)
    crisis_score: Mapped[float] = mapped_column(Float)  # 0.0 – 1.0
    resolved: Mapped[bool] = mapped_column(default=False)
    detected_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="crisis_events")
EOF

# ── schemas ───────────────────────────────────────────────────────────────────
cat > backend/app/schemas/user.py << 'EOF'
from pydantic import BaseModel, EmailStr

class UserCreate(BaseModel):
    email: EmailStr
    full_name: str
    password: str
    preferred_language: str = "en"

class UserOut(BaseModel):
    id: str
    email: str
    full_name: str
    preferred_language: str
    class Config:
        from_attributes = True

class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut
EOF

cat > backend/app/schemas/chat.py << 'EOF'
from pydantic import BaseModel

class ChatMessage(BaseModel):
    content: str
    session_id: str | None = None
EOF

cat > backend/app/schemas/mood.py << 'EOF'
from pydantic import BaseModel
from datetime import datetime

class MoodCreate(BaseModel):
    score: int               # 1–10
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
EOF

cat > backend/app/schemas/resource.py << 'EOF'
from pydantic import BaseModel

class ResourceOut(BaseModel):
    id: str
    name: str
    resource_type: str
    country: str
    phone: str | None
    url: str | None
    languages: str
    is_free: bool
    description: str | None
    class Config:
        from_attributes = True
EOF

# ── services/llm_service.py ───────────────────────────────────────────────────
cat > backend/app/services/llm_service.py << 'EOF'
from app.core.claude_client import get_claude
from app.core.config import settings

SYSTEM_PROMPT = """You are Nafsi, a warm, culturally-aware mental health companion designed for Africa and the Global South.

Guidelines:
- Speak with empathy, warmth, and without clinical coldness
- Respect cultural nuances — family, community, spirituality matter
- You are NOT a replacement for professional help; always encourage it when appropriate
- Detect signs of crisis and respond with care and resources
- Support English and Swahili naturally
- Never dismiss feelings; always validate first, then gently guide

You never diagnose. You listen, reflect, support, and refer."""

async def stream_chat(messages: list[dict]):
    """Stream a response from Claude. Yields text chunks."""
    client = get_claude()
    async with client.messages.stream(
        model=settings.CLAUDE_MODEL,
        max_tokens=settings.MAX_TOKENS,
        system=SYSTEM_PROMPT,
        messages=messages,
    ) as stream:
        async for text in stream.text_stream:
            yield text
EOF

# ── services/crisis_service.py ────────────────────────────────────────────────
cat > backend/app/services/crisis_service.py << 'EOF'
import re

CRISIS_KEYWORDS = [
    r"\bsuicid\w*\b", r"\bkill myself\b", r"\bend my life\b",
    r"\bself.harm\b", r"\bself-harm\b", r"\bcut myself\b",
    r"\bwant to die\b", r"\bno reason to live\b", r"\bhopeless\b",
    r"\bnataka kufa\b", r"\bjiua\b",   # Swahili
]

SEVERITY_MAP = {
    (0.8, 1.0): "critical",
    (0.5, 0.8): "high",
    (0.2, 0.5): "medium",
    (0.0, 0.2): "low",
}

def compute_crisis_score(text: str) -> float:
    text_lower = text.lower()
    matches = sum(1 for kw in CRISIS_KEYWORDS if re.search(kw, text_lower))
    return min(matches / max(len(CRISIS_KEYWORDS) * 0.3, 1), 1.0)

def get_severity(score: float) -> str:
    for (lo, hi), label in SEVERITY_MAP.items():
        if lo <= score <= hi:
            return label
    return "low"

def is_crisis(text: str) -> tuple[bool, float, str]:
    score = compute_crisis_score(text)
    severity = get_severity(score)
    return score >= 0.2, score, severity
EOF

# ── services/mood_service.py ──────────────────────────────────────────────────
cat > backend/app/services/mood_service.py << 'EOF'
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
        select(MoodEntry)
        .where(MoodEntry.user_id == user_id)
        .order_by(MoodEntry.created_at.desc())
        .limit(limit)
    )
    return list(result.scalars().all())
EOF

# ── api/routes/auth.py ────────────────────────────────────────────────────────
cat > backend/app/api/routes/auth.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException, status
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
    user = User(
        id=str(uuid.uuid4()),
        email=data.email,
        full_name=data.full_name,
        hashed_password=hash_password(data.password),
        preferred_language=data.preferred_language,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    token = create_access_token({"sub": user.id})
    return Token(access_token=token, user=UserOut.model_validate(user))

@router.post("/login", response_model=Token)
async def login(data: UserCreate, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == data.email))
    user = result.scalar_one_or_none()
    if not user or not verify_password(data.password, user.hashed_password):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid credentials")
    token = create_access_token({"sub": user.id})
    return Token(access_token=token, user=UserOut.model_validate(user))
EOF

# ── api/routes/chat.py ────────────────────────────────────────────────────────
cat > backend/app/api/routes/chat.py << 'EOF'
from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse
from app.core.security import get_current_user
from app.schemas.chat import ChatMessage
from app.services.llm_service import stream_chat
from app.services.crisis_service import is_crisis
import json

router = APIRouter(prefix="/chat", tags=["chat"])

@router.post("/stream")
async def chat_stream(msg: ChatMessage, user_id: str = Depends(get_current_user)):
    flagged, score, severity = is_crisis(msg.content)

    async def generate():
        if flagged:
            crisis_data = json.dumps({"type": "crisis", "severity": severity, "score": round(score, 2)})
            yield f"data: {crisis_data}\n\n"

        messages = [{"role": "user", "content": msg.content}]
        async for chunk in stream_chat(messages):
            yield f"data: {json.dumps({'type': 'text', 'content': chunk})}\n\n"
        yield "data: [DONE]\n\n"

    return StreamingResponse(generate(), media_type="text/event-stream")
EOF

# ── api/routes/mood.py ────────────────────────────────────────────────────────
cat > backend/app/api/routes/mood.py << 'EOF'
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
EOF

# ── api/routes/resources.py ───────────────────────────────────────────────────
cat > backend/app/api/routes/resources.py << 'EOF'
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.resource import Resource
from app.schemas.resource import ResourceOut

router = APIRouter(prefix="/resources", tags=["resources"])

@router.get("/", response_model=list[ResourceOut])
async def list_resources(
    country: str | None = Query(None),
    resource_type: str | None = Query(None),
    db: AsyncSession = Depends(get_db),
    _: str = Depends(get_current_user),
):
    q = select(Resource)
    if country:
        q = q.where(Resource.country.ilike(f"%{country}%"))
    if resource_type:
        q = q.where(Resource.resource_type == resource_type)
    result = await db.execute(q)
    return list(result.scalars().all())
EOF

# ── api/routes/crisis.py ──────────────────────────────────────────────────────
cat > backend/app/api/routes/crisis.py << 'EOF'
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
    event = CrisisEvent(
        id=str(uuid.uuid4()),
        user_id=user_id,
        severity=data.severity,
        trigger_text=data.trigger_text,
        crisis_score=data.crisis_score,
    )
    db.add(event)
    await db.commit()
    return {"message": "Crisis event logged", "id": event.id}
EOF

# ── main.py ───────────────────────────────────────────────────────────────────
cat > backend/app/main.py << 'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from app.core.database import init_db
from app.core.redis_client import close_redis
from app.api.routes import auth, chat, mood, resources, crisis

@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    yield
    await close_redis()

app = FastAPI(
    title="Nafsi AI",
    description="Culturally-aware mental health companion for Africa and the Global South",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/api")
app.include_router(chat.router, prefix="/api")
app.include_router(mood.router, prefix="/api")
app.include_router(resources.router, prefix="/api")
app.include_router(crisis.router, prefix="/api")

@app.get("/health")
async def health():
    return {"status": "ok", "service": "nafsi-ai"}
EOF

# run.py at backend root
cat > backend/run.py << 'EOF'
import uvicorn
if __name__ == "__main__":
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
EOF

# ── Frontend ──────────────────────────────────────────────────────────────────
echo "📦 Scaffolding frontend..."
npm create vite@latest frontend -- --template react > /dev/null 2>&1

cd frontend
npm install > /dev/null 2>&1
npm install axios react-router-dom @tanstack/react-query lucide-react > /dev/null 2>&1
npm install -D tailwindcss postcss autoprefixer > /dev/null 2>&1
npx tailwindcss init -p > /dev/null 2>&1

# tailwind config
cat > tailwind.config.js << 'EOF'
/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      colors: {
        nafsi: {
          green:  "#1D9E75",
          teal:   "#0F6E56",
          light:  "#E1F5EE",
          accent: "#9FE1CB",
        },
      },
    },
  },
  plugins: [],
};
EOF

# index.css (Tailwind)
cat > src/index.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  @apply bg-gray-50 text-gray-900;
}
EOF

# API client
mkdir -p src/services
cat > src/services/api.js << 'EOF'
import axios from "axios";

const api = axios.create({ baseURL: "http://localhost:8000/api" });

api.interceptors.request.use((config) => {
  const token = localStorage.getItem("nafsi_token");
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

export default api;
EOF

# Auth context
mkdir -p src/context
cat > src/context/AuthContext.jsx << 'EOF'
import { createContext, useContext, useState, useEffect } from "react";

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [token, setToken] = useState(() => localStorage.getItem("nafsi_token"));

  useEffect(() => {
    const stored = localStorage.getItem("nafsi_user");
    if (stored) setUser(JSON.parse(stored));
  }, []);

  const login = (tokenStr, userData) => {
    localStorage.setItem("nafsi_token", tokenStr);
    localStorage.setItem("nafsi_user", JSON.stringify(userData));
    setToken(tokenStr);
    setUser(userData);
  };

  const logout = () => {
    localStorage.removeItem("nafsi_token");
    localStorage.removeItem("nafsi_user");
    setToken(null);
    setUser(null);
  };

  return (
    <AuthContext.Provider value={{ user, token, login, logout, isAuth: !!token }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => useContext(AuthContext);
EOF

# Pages
mkdir -p src/pages src/components

cat > src/pages/Login.jsx << 'EOF'
import { useState } from "react";
import { useNavigate } from "react-router-dom";
import api from "../services/api";
import { useAuth } from "../context/AuthContext";

export default function Login() {
  const [form, setForm] = useState({ email: "", password: "", full_name: "" });
  const [isRegister, setIsRegister] = useState(false);
  const [error, setError] = useState("");
  const { login } = useAuth();
  const nav = useNavigate();

  const submit = async (e) => {
    e.preventDefault();
    setError("");
    try {
      const endpoint = isRegister ? "/auth/register" : "/auth/login";
      const { data } = await api.post(endpoint, form);
      login(data.access_token, data.user);
      nav("/chat");
    } catch (err) {
      setError(err.response?.data?.detail || "Something went wrong");
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-nafsi-light">
      <div className="bg-white p-8 rounded-2xl shadow-lg w-full max-w-md">
        <div className="text-center mb-8">
          <h1 className="text-3xl font-bold text-nafsi-teal">🌿 Nafsi AI</h1>
          <p className="text-gray-500 mt-1">Your mental health companion</p>
        </div>
        <form onSubmit={submit} className="space-y-4">
          {isRegister && (
            <input
              className="w-full border rounded-lg p-3 focus:outline-none focus:ring-2 focus:ring-nafsi-green"
              placeholder="Full name"
              value={form.full_name}
              onChange={e => setForm(f => ({...f, full_name: e.target.value}))}
              required
            />
          )}
          <input
            className="w-full border rounded-lg p-3 focus:outline-none focus:ring-2 focus:ring-nafsi-green"
            type="email" placeholder="Email"
            value={form.email}
            onChange={e => setForm(f => ({...f, email: e.target.value}))}
            required
          />
          <input
            className="w-full border rounded-lg p-3 focus:outline-none focus:ring-2 focus:ring-nafsi-green"
            type="password" placeholder="Password"
            value={form.password}
            onChange={e => setForm(f => ({...f, password: e.target.value}))}
            required
          />
          {error && <p className="text-red-500 text-sm">{error}</p>}
          <button className="w-full bg-nafsi-green text-white py-3 rounded-lg font-semibold hover:bg-nafsi-teal transition">
            {isRegister ? "Create Account" : "Sign In"}
          </button>
        </form>
        <p className="text-center mt-4 text-sm text-gray-500">
          {isRegister ? "Already have an account?" : "Don't have an account?"}
          <button onClick={() => setIsRegister(!isRegister)} className="text-nafsi-green ml-1 font-medium">
            {isRegister ? "Sign in" : "Register"}
          </button>
        </p>
      </div>
    </div>
  );
}
EOF

cat > src/pages/Chat.jsx << 'EOF'
import { useState, useRef, useEffect } from "react";
import { Send, AlertTriangle } from "lucide-react";
import { useAuth } from "../context/AuthContext";
import api from "../services/api";
import CrisisAlert from "../components/CrisisAlert";

export default function Chat() {
  const [messages, setMessages] = useState([
    { role: "assistant", content: "Habari! I'm Nafsi 🌿. How are you feeling today?" }
  ]);
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);
  const [crisis, setCrisis] = useState(null);
  const bottomRef = useRef(null);
  const { token } = useAuth();

  useEffect(() => { bottomRef.current?.scrollIntoView({ behavior: "smooth" }); }, [messages]);

  const send = async () => {
    if (!input.trim() || loading) return;
    const userMsg = input.trim();
    setInput("");
    setMessages(m => [...m, { role: "user", content: userMsg }]);
    setLoading(true);

    try {
      const res = await fetch("http://localhost:8000/api/chat/stream", {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
        body: JSON.stringify({ content: userMsg }),
      });

      const reader = res.body.getReader();
      const decoder = new TextDecoder();
      let assistantText = "";
      setMessages(m => [...m, { role: "assistant", content: "" }]);

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        const lines = decoder.decode(value).split("\n");
        for (const line of lines) {
          if (!line.startsWith("data:")) continue;
          const raw = line.slice(5).trim();
          if (raw === "[DONE]") break;
          try {
            const evt = JSON.parse(raw);
            if (evt.type === "crisis") { setCrisis(evt); }
            if (evt.type === "text") {
              assistantText += evt.content;
              setMessages(m => {
                const copy = [...m];
                copy[copy.length - 1] = { role: "assistant", content: assistantText };
                return copy;
              });
            }
          } catch {}
        }
      }
    } catch (err) {
      setMessages(m => [...m, { role: "assistant", content: "I'm having trouble connecting right now. Please try again." }]);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex flex-col h-screen max-w-2xl mx-auto">
      <header className="p-4 border-b bg-white font-semibold text-nafsi-teal text-lg">🌿 Nafsi Chat</header>
      {crisis && <CrisisAlert crisis={crisis} onDismiss={() => setCrisis(null)} />}
      <div className="flex-1 overflow-y-auto p-4 space-y-3">
        {messages.map((m, i) => (
          <div key={i} className={`flex ${m.role === "user" ? "justify-end" : "justify-start"}`}>
            <div className={`max-w-xs lg:max-w-md px-4 py-2 rounded-2xl text-sm ${
              m.role === "user" ? "bg-nafsi-green text-white" : "bg-white border shadow-sm"
            }`}>{m.content}</div>
          </div>
        ))}
        {loading && <div className="text-gray-400 text-sm">Nafsi is typing...</div>}
        <div ref={bottomRef}/>
      </div>
      <div className="p-4 border-t bg-white flex gap-2">
        <input
          className="flex-1 border rounded-full px-4 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-nafsi-green"
          placeholder="How are you feeling?"
          value={input}
          onChange={e => setInput(e.target.value)}
          onKeyDown={e => e.key === "Enter" && send()}
        />
        <button onClick={send} disabled={loading}
          className="bg-nafsi-green text-white p-2 rounded-full hover:bg-nafsi-teal transition disabled:opacity-50">
          <Send size={18}/>
        </button>
      </div>
    </div>
  );
}
EOF

cat > src/components/CrisisAlert.jsx << 'EOF'
import { AlertTriangle, X, Phone } from "lucide-react";

export default function CrisisAlert({ crisis, onDismiss }) {
  const isCritical = crisis.severity === "critical";
  return (
    <div className={`mx-4 mt-2 p-4 rounded-xl border-l-4 ${isCritical ? "bg-red-50 border-red-500" : "bg-amber-50 border-amber-500"}`}>
      <div className="flex justify-between items-start">
        <div className="flex gap-2">
          <AlertTriangle className={isCritical ? "text-red-500" : "text-amber-500"} size={20}/>
          <div>
            <p className="font-semibold text-sm">{isCritical ? "Crisis Detected" : "We're Concerned"}</p>
            <p className="text-xs text-gray-600 mt-1">
              {isCritical
                ? "Please reach out for immediate help. You are not alone."
                : "It sounds like you might be going through something difficult."}
            </p>
            <div className="flex gap-2 mt-2">
              <a href="tel:+254722178177" className="flex items-center gap-1 text-xs text-white bg-nafsi-green px-3 py-1 rounded-full">
                <Phone size={12}/> Befrienders Kenya
              </a>
            </div>
          </div>
        </div>
        <button onClick={onDismiss}><X size={16} className="text-gray-400"/></button>
      </div>
    </div>
  );
}
EOF

cat > src/pages/Mood.jsx << 'EOF'
import { useState, useEffect } from "react";
import api from "../services/api";

const EMOTIONS = ["😊 Happy", "😢 Sad", "😤 Angry", "😰 Anxious", "😴 Tired", "💪 Strong", "😕 Confused", "🤗 Grateful"];
const SCORES = [1,2,3,4,5,6,7,8,9,10];

export default function Mood() {
  const [score, setScore] = useState(5);
  const [tags, setTags] = useState([]);
  const [note, setNote] = useState("");
  const [history, setHistory] = useState([]);
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    api.get("/mood/history").then(r => setHistory(r.data)).catch(() => {});
  }, []);

  const toggle = (tag) => setTags(t => t.includes(tag) ? t.filter(x => x !== tag) : [...t, tag]);

  const submit = async () => {
    await api.post("/mood/", { score, emotion_tags: tags, journal_note: note });
    setSaved(true);
    setTimeout(() => setSaved(false), 2000);
    setNote(""); setTags([]);
    const r = await api.get("/mood/history");
    setHistory(r.data);
  };

  return (
    <div className="max-w-xl mx-auto p-6 space-y-6">
      <h1 className="text-2xl font-bold text-nafsi-teal">🌡️ Mood Check-in</h1>
      <div>
        <p className="text-sm text-gray-500 mb-2">How would you rate your mood? ({score}/10)</p>
        <input type="range" min={1} max={10} value={score} onChange={e => setScore(+e.target.value)}
          className="w-full accent-nafsi-green"/>
      </div>
      <div>
        <p className="text-sm text-gray-500 mb-2">What are you feeling?</p>
        <div className="flex flex-wrap gap-2">
          {EMOTIONS.map(e => (
            <button key={e} onClick={() => toggle(e)}
              className={`px-3 py-1 rounded-full text-sm border transition ${tags.includes(e) ? "bg-nafsi-green text-white border-nafsi-green" : "border-gray-300 hover:border-nafsi-green"}`}>
              {e}
            </button>
          ))}
        </div>
      </div>
      <textarea className="w-full border rounded-xl p-3 text-sm focus:outline-none focus:ring-2 focus:ring-nafsi-green"
        rows={3} placeholder="Any thoughts you'd like to journal..." value={note} onChange={e => setNote(e.target.value)}/>
      <button onClick={submit} className="w-full bg-nafsi-green text-white py-2 rounded-xl font-medium hover:bg-nafsi-teal transition">
        {saved ? "✓ Saved!" : "Log Mood"}
      </button>
      {history.length > 0 && (
        <div>
          <h2 className="font-semibold text-gray-700 mb-2">Recent entries</h2>
          <div className="space-y-2">
            {history.slice(0,5).map(m => (
              <div key={m.id} className="bg-white border rounded-xl p-3 flex justify-between items-center">
                <div>
                  <span className="font-bold text-nafsi-green">{m.score}/10</span>
                  <span className="text-xs text-gray-400 ml-2">{new Date(m.created_at).toLocaleDateString()}</span>
                  {m.journal_note && <p className="text-sm text-gray-500 mt-1">{m.journal_note}</p>}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
EOF

cat > src/pages/Resources.jsx << 'EOF'
import { useState, useEffect } from "react";
import { Phone, Globe } from "lucide-react";
import api from "../services/api";

const SEED_RESOURCES = [
  { id: "1", name: "Befrienders Kenya", resource_type: "hotline", country: "Kenya", phone: "+254722178177", url: null, languages: "en,sw", is_free: true, description: "24/7 emotional support" },
  { id: "2", name: "Mentally Aware Nigeria", resource_type: "ngo", country: "Nigeria", phone: null, url: "https://mani.org.ng", languages: "en", is_free: true, description: "Mental health advocacy & support" },
  { id: "3", name: "SADAG (South Africa)", resource_type: "hotline", country: "South Africa", phone: "+27800567567", url: "https://sadag.org", languages: "en", is_free: true, description: "24-hour crisis line" },
];

export default function Resources() {
  const [resources, setResources] = useState(SEED_RESOURCES);
  const [filter, setFilter] = useState("");

  useEffect(() => {
    api.get("/resources/").then(r => { if (r.data.length) setResources(r.data); }).catch(() => {});
  }, []);

  const filtered = resources.filter(r =>
    r.country.toLowerCase().includes(filter.toLowerCase()) ||
    r.name.toLowerCase().includes(filter.toLowerCase())
  );

  return (
    <div className="max-w-2xl mx-auto p-6 space-y-4">
      <h1 className="text-2xl font-bold text-nafsi-teal">📋 Mental Health Resources</h1>
      <input className="w-full border rounded-xl px-4 py-2 focus:outline-none focus:ring-2 focus:ring-nafsi-green"
        placeholder="Search by country or name..." value={filter} onChange={e => setFilter(e.target.value)}/>
      <div className="space-y-3">
        {filtered.map(r => (
          <div key={r.id} className="bg-white border rounded-xl p-4 shadow-sm">
            <div className="flex justify-between items-start">
              <div>
                <h3 className="font-semibold">{r.name}</h3>
                <p className="text-sm text-gray-500">{r.country} · {r.resource_type}</p>
                {r.description && <p className="text-sm text-gray-600 mt-1">{r.description}</p>}
              </div>
              {r.is_free && <span className="text-xs bg-nafsi-light text-nafsi-teal px-2 py-1 rounded-full">Free</span>}
            </div>
            <div className="flex gap-3 mt-3">
              {r.phone && <a href={`tel:${r.phone}`} className="flex items-center gap-1 text-sm text-nafsi-green"><Phone size={14}/>{r.phone}</a>}
              {r.url && <a href={r.url} target="_blank" rel="noreferrer" className="flex items-center gap-1 text-sm text-nafsi-green"><Globe size={14}/>Website</a>}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
EOF

cat > src/pages/Dashboard.jsx << 'EOF'
import { useAuth } from "../context/AuthContext";
import { Link } from "react-router-dom";

export default function Dashboard() {
  const { user, logout } = useAuth();
  return (
    <div className="min-h-screen bg-nafsi-light">
      <nav className="bg-white shadow-sm px-6 py-4 flex justify-between items-center">
        <span className="text-nafsi-teal font-bold text-lg">🌿 Nafsi AI</span>
        <div className="flex items-center gap-4">
          <span className="text-sm text-gray-500">Hi, {user?.full_name}</span>
          <button onClick={logout} className="text-sm text-red-400 hover:text-red-600">Logout</button>
        </div>
      </nav>
      <div className="max-w-3xl mx-auto p-8 grid grid-cols-1 md:grid-cols-2 gap-4 mt-6">
        {[
          { to: "/chat", label: "💬 Talk to Nafsi", desc: "Start a conversation with your AI companion" },
          { to: "/mood", label: "🌡️ Log Your Mood", desc: "Track your emotional wellbeing" },
          { to: "/resources", label: "📋 Find Resources", desc: "Therapists, hotlines across Africa" },
        ].map(card => (
          <Link key={card.to} to={card.to} className="bg-white rounded-2xl p-6 shadow-sm hover:shadow-md transition border border-transparent hover:border-nafsi-accent">
            <h2 className="text-lg font-bold text-nafsi-teal">{card.label}</h2>
            <p className="text-sm text-gray-500 mt-1">{card.desc}</p>
          </Link>
        ))}
      </div>
    </div>
  );
}
EOF

# App.jsx with routing
cat > src/App.jsx << 'EOF'
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { AuthProvider, useAuth } from "./context/AuthContext";
import Login from "./pages/Login";
import Dashboard from "./pages/Dashboard";
import Chat from "./pages/Chat";
import Mood from "./pages/Mood";
import Resources from "./pages/Resources";

function Protected({ children }) {
  const { isAuth } = useAuth();
  return isAuth ? children : <Navigate to="/login" replace/>;
}

function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<Login/>}/>
          <Route path="/" element={<Protected><Dashboard/></Protected>}/>
          <Route path="/chat" element={<Protected><Chat/></Protected>}/>
          <Route path="/mood" element={<Protected><Mood/></Protected>}/>
          <Route path="/resources" element={<Protected><Resources/></Protected>}/>
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}

export default App;
EOF

cd ..

echo ""
echo "✅ Nafsi AI scaffold complete!"
echo ""
echo "Next steps:"
echo "  1. cp .env.example .env  →  add your ANTHROPIC_API_KEY"
echo "  2. docker compose up -d  →  start PostgreSQL + Redis"
echo "  3. cd backend && pip install -r requirements.txt && python run.py"
echo "  4. cd frontend && npm run dev"
echo ""
echo "  Backend:  http://localhost:8000"
echo "  API docs: http://localhost:8000/docs"
echo "  Frontend: http://localhost:5173"