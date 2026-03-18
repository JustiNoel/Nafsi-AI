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
            yield f"data: {json.dumps({'type':'crisis','severity':severity,'score':round(score,2)})}\n\n"
        async for chunk in stream_chat([{"role": "user", "content": msg.content}]):
            yield f"data: {json.dumps({'type':'text','content':chunk})}\n\n"
        yield "data: [DONE]\n\n"
    return StreamingResponse(generate(), media_type="text/event-stream")
