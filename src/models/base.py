from pydantic import BaseModel, Field, field_validator
from typing import List, Literal, Set, Dict, Optional
import json
import os

# Geo-spatial data
COUNTRIES_DATA_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "src", "data", "geo", "countries.json")
AFFILIATIONS_DATA_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "src", "data", "geo", "affiliations.json")

# Taxonomy and Registries
SERVICES_DATA_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "src", "data", "taxonomy", "services.json")
CATEGORIES_DATA_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "src", "data", "taxonomy", "categories.json")
SECTORS_DATA_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "src", "data", "taxonomy", "sectors.json")
STRATEGIC_FOCUS_DATA_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "src", "data", "taxonomy", "strategic_focus.json")

# Configuration and Metrics
METRICS_DATA_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "src", "data", "config", "metrics.json")

def load_countries_data() -> List[Dict]:
    """Loads the country data from the JSON file."""
    if not os.path.exists(COUNTRIES_DATA_PATH):
        return []
    with open(COUNTRIES_DATA_PATH, "r") as f:
        return json.load(f)

def load_affiliations_data() -> Dict[str, List[str]]:
    """Loads the affiliation registry mapping affiliations to country a3 codes."""
    if not os.path.exists(AFFILIATIONS_DATA_PATH):
        return {}
    with open(AFFILIATIONS_DATA_PATH, "r") as f:
        return json.load(f)

def load_services_data() -> List[Dict]:
    """Loads the normalized services registry."""
    if not os.path.exists(SERVICES_DATA_PATH):
        return []
    with open(SERVICES_DATA_PATH, "r") as f:
        return json.load(f)

def load_registry_list(path: str, key: Optional[str] = None) -> List[str]:
    """Loads a list registry from a JSON file, optionally from a specific key."""
    if not os.path.exists(path):
        return []
    with open(path, "r") as f:
        data = json.load(f)
        if key and isinstance(data, dict):
            return data.get(key, [])
        return data

# Cache for registries
_CATEGORIES: Optional[Set[str]] = None
_SECTORS: Optional[Set[str]] = None
_FOCUSES: Optional[Set[str]] = None

def get_categories() -> Set[str]:
    global _CATEGORIES
    if _CATEGORIES is None:
        _CATEGORIES = set(load_registry_list(CATEGORIES_DATA_PATH, key="service_types"))
    return _CATEGORIES

def get_sectors() -> Set[str]:
    global _SECTORS
    if _SECTORS is None:
        _SECTORS = set(load_registry_list(SECTORS_DATA_PATH, key="sectors"))
    return _SECTORS

def get_focuses() -> Set[str]:
    global _FOCUSES
    if _FOCUSES is None:
        _FOCUSES = set(load_registry_list(STRATEGIC_FOCUS_DATA_PATH, key="focuses"))
    return _FOCUSES

# Type of operations requirement or business need
class OperationType(BaseModel):
    name: str
    category: str = Field(description="Service category from categories.json")
    description: str

    @field_validator("category")
    @classmethod
    def validate_category(cls, v: str) -> str:
        if v not in get_categories():
            raise ValueError(f"Category '{v}' not in registry: {get_categories()}")
        return v

# Defines the industry sectors a firm or project can belong to.
class Sectors(BaseModel):
    name: str
    description: str = Field(description="Sector identifier from sectors.json")

    @field_validator("description")
    @classmethod
    def validate_sector(cls, v: str) -> str:
        if v not in get_sectors():
            raise ValueError(f"Sector '{v}' not in registry: {get_sectors()}")
        return v

# Categorizes the strategic goals or focus areas of a firm.
class StrategicFocus(BaseModel):
    name: str
    description: str = Field(description="Strategic focus area from strategic_focus.json")

    @field_validator("description")
    @classmethod
    def validate_focus(cls, v: str) -> str:
        if v not in get_focuses():
            raise ValueError(f"Strategic focus '{v}' not in registry: {get_focuses()}")
        return v


# Detailed representation of a country with ISO codes and regional metadata.
class Country(BaseModel):
    name: str
    a2: str
    a3: str
    num: str
    region: str
    sub_region: str
    affiliations: List[str] = Field(default_factory=list, description="Affiliations of the country")