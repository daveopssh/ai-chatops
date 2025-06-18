import os


class Config:
    def __init__(
        self,
        llm_model="gpt-4.1-nano",
        openai_api_key=None,
        db_host=None,
        db_port=None,
        db_user=None,
        db_password=None,
        db_name=None,
    ):
        self.llm_model = llm_model
        self.openai_api_key = openai_api_key or os.getenv("OPENAI_API_KEY")
        if not self.openai_api_key:
            raise RuntimeError(
                "OPENAI_API_KEY must be provided as argument or environment variable."
            )

        self.db_host = db_host or os.getenv("DB_HOST", "localhost")
        self.db_port = db_port or int(os.getenv("DB_PORT", 5432))
        self.db_user = db_user or os.getenv("DB_USER", "postgres")
        self.db_name = db_name or os.getenv("DB_NAME", "vector_db")
        self.db_password = db_password or os.getenv("DB_PASSWORD", "")

    def db_url(self):
        return f"postgresql+psycopg://{self.db_user}:{self.db_password}@{self.db_host}:{self.db_port}/{self.db_name}"
