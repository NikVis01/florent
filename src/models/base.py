from pydantic import BaseModel, Field
from typing import List, Literal, Set, Dict, Optional
import json
import os

# Source of truth for country data
COUNTRIES_DATA_PATH = os.path.join(os.path.dirname(__file__), "data", "countries.json")

def load_countries_data() -> List[Dict]:
    """Loads the country data from the JSON file."""
    if not os.path.exists(COUNTRIES_DATA_PATH):
        return []
    with open(COUNTRIES_DATA_PATH, "r") as f:
        return json.load(f)

# Cache for country codes to speed up validation
_COUNTRY_A3_CODES: Set[str] = set()

def get_valid_country_codes() -> Set[str]:
    global _COUNTRY_A3_CODES
    if not _COUNTRY_A3_CODES:
        data = load_countries_data()
        _COUNTRY_A3_CODES = {c["a3"] for c in data if "a3" in c}
    return _COUNTRY_A3_CODES

# Type of operations requirement or business need
# Represents a specific type of business or operational requirement.
class OperationType(BaseModel):
    name: str
    category: Literal[
        "transportation",
        "financing",
        "insurance",
        "guarantee",
        "recruitment",
        "materials",
        "equipment",
        "other",
    ]
    description: str


# Defines the industry sectors a firm or project can belong to.
class Sectors(BaseModel):
    name: str
    description: Literal[
        "energy",
        "technology",
        "healthcare",
        "finance",
        "manufacturing",
        "construction",
        "agriculture",
        "retail",
        "services",
        "education",
        "public",
        "defence",
        "other",
    ]


# Categorizes the strategic goals or focus areas of a firm.
class StrategicFocus(BaseModel):
    name: str
    description: Literal[
        "growth",
        "innovation",
        "sustainability",
        "efficiency",
        "expansion",
        "public_private_partnership",
        "digital_transformation",
        "other",
    ]


# Detailed representation of a country with ISO codes and regional metadata.
class Country(BaseModel):
    name: str
    a2: str
    a3: str
    num: str
    region: str
    sub_region: str
    affiliations: List[str] = Field(default_factory=list, description="Affiliations of the country")