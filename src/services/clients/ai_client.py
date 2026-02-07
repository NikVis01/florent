import dspy
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def init_dspy():
    """
    Initializes DSPy with OpenAI.
    Ensures that the OPENAI_API_KEY is loaded from .env.
    """
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise ValueError("OPENAI_API_KEY not found in environment variables")
    
    # Configure DSPy with GPT-4o-mini as a default efficient model
    lm = dspy.OpenAI(model="gpt-4o-mini", api_key=api_key)
    dspy.settings.configure(lm=lm)
    return lm

class AIClient:
    """
    Wrapper for AI operations using DSPy.
    """
    def __init__(self):
        self.lm = init_dspy()

    def get_lm(self):
        return self.lm
