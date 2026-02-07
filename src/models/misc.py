

# Type of operations requirement or business need
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


class Country(BaseModel):
    name: str
    code: str
    region: Literal[
        "europe",
        "asia",
        "africa",
        "north_america",
        "south_america",
        "oceania",
        "other",
    ]
    affiliations: List[str] = Field(default_factory=list, description="Affiliations of the country")