### Similarity between countries

class CountrySimilarity(BaseModel):
    country_a3: str
    similar_countries: List[str]
    similarity_score: float

    def is_same_region(self, country_a3: str) -> bool:
        """Checks if two countries are in the same region."""
        return self.country_a3 == country_a3

    def is_same_sub_region(self, country_a3: str) -> bool:
        """Checks if two countries are in the same sub-region."""
        return self.country_a3 == country_a3

    def is_same_affiliation(self, country_a3: str) -> bool:
        """Checks if two countries are in the same affiliation."""
        return self.country_a3 == country_a3

    def is_close(self, country_a3: str) -> bool:
        """Checks if two countries are close."""
        return self.is_same_region(country_a3) or self.is_same_sub_region(country_a3) or self.is_same_affiliation(country_a3)