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

app = FastAPI(title="Nafsi AI", version="1.0.0", lifespan=lifespan)

app.add_middleware(CORSMiddleware, allow_origins=["http://localhost:5173"],
                   allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

app.include_router(auth.router, prefix="/api")
app.include_router(chat.router, prefix="/api")
app.include_router(mood.router, prefix="/api")
app.include_router(resources.router, prefix="/api")
app.include_router(crisis.router, prefix="/api")

@app.get("/health")
async def health():
    return {"status": "ok", "service": "nafsi-ai"}
