from typing import Optional
from pydantic import BaseModel


class ChatRequest(BaseModel):
    chat: str 

class ChatResponse(BaseModel):
    response: str
