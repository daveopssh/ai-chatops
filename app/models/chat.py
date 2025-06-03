from typing import Optional
from pydantic import BaseModel


class ChatRequest(BaseModel):
    conversation_id: Optional[int] = 0
    chat: str 

