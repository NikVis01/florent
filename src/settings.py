import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

class Settings:
    # LLM Settings
    OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
    LLM_MODEL = os.getenv("LLM_MODEL", "gpt-4-turbo-preview")

    # BGE-M3 Settings
    BGE_M3_URL = os.getenv("BGE_M3_URL", "http://localhost:8080")
    BGE_M3_MODEL = os.getenv("BGE_M3_MODEL", "BAAI/bge-m3")

    # Engine Constants
    DEFAULT_ATTENUATION_FACTOR = float(os.getenv("DEFAULT_ATTENUATION_FACTOR", "1.2"))
    MAX_TRAVERSAL_DEPTH = int(os.getenv("MAX_TRAVERSAL_DEPTH", "10"))

    # Project Paths
    BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    DATA_DIR = os.path.join(BASE_DIR, "src", "data")
    GEO_DIR = os.path.join(DATA_DIR, "geo")
    TAXONOMY_DIR = os.path.join(DATA_DIR, "taxonomy")
    CONFIG_DIR = os.path.join(DATA_DIR, "config")
    POC_DIR = os.path.join(DATA_DIR, "poc")

settings = Settings()
