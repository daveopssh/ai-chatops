from fastapi import APIRouter, status
from app.models import ChatRequest

router = APIRouter()

@router.get("/", status_code=status.HTTP_200_OK)
async def root():
    return "Ok"

@router.post("/chat", status_code=status.HTTP_200_OK)
async def chat(payload: ChatRequest):
    return {"recibido": payload}
