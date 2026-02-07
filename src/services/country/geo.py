"""Geo-spatial utilities for country analysis."""
from pydantic import BaseModel
from typing import List, Optional, Set
import logging

from src.models.base import Country, load_countries_data, load_affiliations_data

logger = logging.getLogger(__name__)


class CountrySimilarity(BaseModel):
    """Represents similarity between countries based on various criteria."""
    country_a3: str
    similar_countries: List[str]
    similarity_score: float

    def is_same_region(self, country: Country) -> bool:
        """Checks if country is in the same region."""
        # This needs to be implemented with actual country data lookup
        # Placeholder for now
        return country.a3 in self.similar_countries

    def is_same_sub_region(self, country: Country) -> bool:
        """Checks if country is in the same sub-region."""
        # This needs to be implemented with actual country data lookup
        return country.a3 in self.similar_countries

    def is_same_affiliation(self, country: Country) -> bool:
        """Checks if country shares affiliations."""
        # This needs to be implemented with actual affiliation data
        return country.a3 in self.similar_countries

    def is_close(self, country: Country) -> bool:
        """Checks if two countries are close by any metric."""
        return (self.is_same_region(country) or
                self.is_same_sub_region(country) or
                self.is_same_affiliation(country))


class GeoAnalyzer:
    """Analyzes geographical and geopolitical relationships between countries."""

    def __init__(self):
        """Initialize with country and affiliation data."""
        try:
            self.countries_data = load_countries_data()
            self.affiliations_data = load_affiliations_data()
            self._country_lookup = {c['a3']: c for c in self.countries_data}
            logger.info(f"GeoAnalyzer initialized with {len(self.countries_data)} countries")
        except Exception as e:
            logger.error(f"Failed to initialize GeoAnalyzer: {e}")
            self.countries_data = []
            self.affiliations_data = {}
            self._country_lookup = {}

    def get_country(self, a3_code: str) -> Optional[Country]:
        """Get country object by A3 code."""
        country_data = self._country_lookup.get(a3_code)
        if not country_data:
            logger.warning(f"Country not found: {a3_code}")
            return None
        try:
            return Country(**country_data)
        except Exception as e:
            logger.error(f"Failed to create Country object for {a3_code}: {e}")
            return None

    def countries_share_region(self, a3_code1: str, a3_code2: str) -> bool:
        """Check if two countries are in the same region."""
        c1 = self._country_lookup.get(a3_code1)
        c2 = self._country_lookup.get(a3_code2)

        if not c1 or not c2:
            return False

        return c1.get('region') == c2.get('region')

    def countries_share_subregion(self, a3_code1: str, a3_code2: str) -> bool:
        """Check if two countries are in the same sub-region."""
        c1 = self._country_lookup.get(a3_code1)
        c2 = self._country_lookup.get(a3_code2)

        if not c1 or not c2:
            return False

        return c1.get('sub_region') == c2.get('sub_region')

    def get_shared_affiliations(self, a3_code1: str, a3_code2: str) -> Set[str]:
        """Get shared affiliations between two countries."""
        c1 = self._country_lookup.get(a3_code1)
        c2 = self._country_lookup.get(a3_code2)

        if not c1 or not c2:
            return set()

        aff1 = set(c1.get('affiliations', []))
        aff2 = set(c2.get('affiliations', []))

        return aff1.intersection(aff2)

    def calculate_geo_similarity(self, a3_code1: str, a3_code2: str) -> float:
        """
        Calculate geographical/geopolitical similarity between countries.
        Returns a score between 0 and 1.
        """
        if a3_code1 == a3_code2:
            return 1.0

        score = 0.0

        # Same region: +0.3
        if self.countries_share_region(a3_code1, a3_code2):
            score += 0.3

        # Same sub-region: +0.3
        if self.countries_share_subregion(a3_code1, a3_code2):
            score += 0.3

        # Shared affiliations: +0.1 per shared affiliation (max 0.4)
        shared_aff = self.get_shared_affiliations(a3_code1, a3_code2)
        score += min(0.4, len(shared_aff) * 0.1)

        logger.debug(f"Geo similarity {a3_code1}-{a3_code2}: {score:.2f}")
        return min(1.0, score)
