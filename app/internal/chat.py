from typing import List
from app.internal.config import Config
from app.internal.store import VectorStore
from langchain_core.documents import Document
from langchain.memory import ConversationBufferMemory
from langchain_community.chat_models import ChatOpenAI
from langchain_core.messages import BaseMessage, HumanMessage, SystemMessage


class ChatService:

    def __init__(self, config: Config, db: VectorStore):
        self.db = db
        self.config = config
        self.memory = ConversationBufferMemory(
            memory_key="history",
            return_messages=True,
        )
        self.llm = ChatOpenAI(
            model=self.config.llm_model,
            temperature=0.7, 
            api_key=self.config.openai_api_key,
        )

    def _build_message(self, chat: str, docs: List[Document]) -> List[BaseMessage]:
        messages = []
        messages.append(SystemMessage("Eres un Senior Site Reliability Engineer amargado y sarcástico,"
        "Tu tarea es responder a las preguntas de los usuarios basados en los postmortems de los incidentes leidos en el context"
        ))

        history = self.memory.load_memory_variables({})["history"] 
        for message in history:
            messages.append(message)

        context = "\n".join([doc.page_content for doc in docs])
        messages.append(HumanMessage(content=f"{context}\n\n{chat}"))
        return messages

    def chat(self, query: str):
        """Process the chat query and return the response."""
        try:
            search_results = self.db.search(query, k=2)
            if not search_results:
                return {"response": "No relevant documents found."}
            messages = self._build_message(query, search_results)
            response = self.llm.invoke(input=messages)
            self.memory.save_context({"input": query}, {"output": str(response.content)})
            return response.content
        except Exception as e:
            return {"response": "An error occurred while processing your request.", "error": str(e)}


