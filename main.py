from fastapi import FastAPI
from app.routers import router
from app.internal.store import VectorStore 
from app.internal.chat import ChatService

app = FastAPI()
app.include_router(router)

store = VectorStore(
    collection_name="postmortem",
    connection_string="postgresql+psycopg://postgres:mysecretpassword@localhost:5432/vector_db"
)

chat_service = ChatService(db=store)

@app.on_event("startup")
async def startup_event():
    """Initialize the vector store on startup."""
    store.init_db()
    print("Vector store initialized.")
