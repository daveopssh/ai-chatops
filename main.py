from fastapi import FastAPI
from app.routers import router
from app.internal.store import VectorStore 
from app.internal.chat import ChatService
from app.internal.config import Config

app = FastAPI()
app.include_router(router)

# Initialize configuration
config = Config(
    db_host="localhost",
    db_name="vector_db",
    db_user="postgres",
    db_password="mysecretpassword",
)

# Initialize the vector store with the connection string
store = VectorStore(
    collection_name="postmortem",
    connection_string=config.db_url() #"postgresql+psycopg://postgres:mysecretpassword@localhost:5432/vector_db"
)

chat_service = ChatService(config, store)

@app.on_event("startup")
async def startup_event():
    """Initialize the vector store on startup."""
    store.init_db()
    print("Vector store initialized.")
