from fastapi import APIRouter, HTTPException, Depends, status
from app.models import ChatRequest, ChatResponse

router = APIRouter()
def chat_service():
    from main import chat_service
    return chat_service

@router.get("/", status_code=status.HTTP_200_OK)
async def root():
    return "Ok"

@router.post("/chat", response_class=ChatResponse, status_code=status.HTTP_200_OK)
async def chat(payload: ChatRequest, chat_service=Depends(chat_service)):
    response = chat_service.chat(payload)
    return ChatResponse(response=response)