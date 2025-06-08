import os
from langchain_postgres.vectorstores import PGVector
from langchain_community.document_loaders import TextLoader
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_core.documents import Document
from langchain_openai import OpenAIEmbeddings

EMBEDDING_MODEL = "text-embedding-3-small"
COLLECTION_NAME = "postmortems"

class VectorStore:
    def __init__(self, connection_string: str, collection_name: str = COLLECTION_NAME ):
        self.connection_string = connection_string
        self.collection_name = collection_name
        self.db = None

        # Initialize the embedding model 
        self.embedding = OpenAIEmbeddings(model=EMBEDDING_MODEL)

        # Load base documents 
        self.documents = []
        for files in os.listdir("./postmortems"):
            self.documents.extend(self._load_document(f"./postmortems/{files}"))

    def _load_document(self, file_path: str) -> Document:
        raw_document = TextLoader(file_path).load()
        text_splitter = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=200)
        split_documents = text_splitter.split_documents(raw_document)
        return split_documents

    def init_db(self):
        """Initialize the database connection and return the PGVector instance."""
        if self.db is not None:
            return self.db
 
        self.db = PGVector.from_documents(
            documents=self.documents,
            embedding=self.embedding,
            connection=self.connection_string,
            collection_name=self.collection_name
        ) 
    
    def add_documents(self, file_path: str):
        """Add documents to the vector store."""
        if self.db is None:
            raise ValueError("Database not initialized. Call init_db() first.")
        new_documents = self._load_document(file_path)
        self.db.add_documents(new_documents)

    def search(self, query: str, k: int = 2):
        """Search for similar documents in the vector store."""
        if self.db is None:
            raise ValueError("Database not initialized. Call init_db() first.")

        return self.db.similarity_search(query, k=k)
