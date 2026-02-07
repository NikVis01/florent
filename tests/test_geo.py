import sys
import os
import unittest
from unittest.mock import patch, mock_open
import json

# Add src to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from src.services.country.geo import GeoAnalyzer, CountrySimilarity
from src.models.base import Country


class TestCountrySimilarity(unittest.TestCase):
    """Test CountrySimilarity model."""

    def setUp(self):
        """Set up test data."""
        self.similarity = CountrySimilarity(
            country_a3="USA",
            similar_countries=["CAN", "MEX", "GBR"],
            similarity_score=0.85
        )
        self.test_country = Country(
            name="Canada",
            a2="CA",
            a3="CAN",
            num="124",
            region="Americas",
            sub_region="Northern America"
        )

    def test_similarity_creation(self):
        """Test creating CountrySimilarity."""
        self.assertEqual(self.similarity.country_a3, "USA")
        self.assertEqual(len(self.similarity.similar_countries), 3)
        self.assertEqual(self.similarity.similarity_score, 0.85)

    def test_is_same_region(self):
        """Test is_same_region method."""
        result = self.similarity.is_same_region(self.test_country)
        # Currently this checks if country in similar_countries
        self.assertTrue(result)

    def test_is_same_sub_region(self):
        """Test is_same_sub_region method."""
        result = self.similarity.is_same_sub_region(self.test_country)
        self.assertTrue(result)

    def test_is_same_affiliation(self):
        """Test is_same_affiliation method."""
        result = self.similarity.is_same_affiliation(self.test_country)
        self.assertTrue(result)

    def test_is_close(self):
        """Test is_close method."""
        result = self.similarity.is_close(self.test_country)
        self.assertTrue(result)

    def test_is_not_close(self):
        """Test is_close with dissimilar country."""
        far_country = Country(
            name="Japan",
            a2="JP",
            a3="JPN",
            num="392",
            region="Asia",
            sub_region="Eastern Asia"
        )
        result = self.similarity.is_close(far_country)
        self.assertFalse(result)


class TestGeoAnalyzer(unittest.TestCase):
    """Test GeoAnalyzer functionality."""

    def setUp(self):
        """Set up test data."""
        self.countries_data = [
            {
                "name": "United States",
                "a2": "US",
                "a3": "USA",
                "num": "840",
                "region": "Americas",
                "sub_region": "Northern America",
                "affiliations": ["NATO", "OECD"]
            },
            {
                "name": "Canada",
                "a2": "CA",
                "a3": "CAN",
                "num": "124",
                "region": "Americas",
                "sub_region": "Northern America",
                "affiliations": ["NATO", "OECD"]
            },
            {
                "name": "France",
                "a2": "FR",
                "a3": "FRA",
                "num": "250",
                "region": "Europe",
                "sub_region": "Western Europe",
                "affiliations": ["EU", "NATO", "OECD"]
            },
            {
                "name": "Japan",
                "a2": "JP",
                "a3": "JPN",
                "num": "392",
                "region": "Asia",
                "sub_region": "Eastern Asia",
                "affiliations": ["OECD"]
            }
        ]
        self.affiliations_data = {
            "NATO": ["USA", "CAN", "FRA"],
            "OECD": ["USA", "CAN", "FRA", "JPN"],
            "EU": ["FRA"]
        }

    def test_initialization_success(self):
        """Test GeoAnalyzer initialization with valid data."""
        with patch('src.models.base.load_countries_data', return_value=self.countries_data), \
             patch('src.models.base.load_affiliations_data', return_value=self.affiliations_data):
            analyzer = GeoAnalyzer()
            self.assertEqual(len(analyzer.countries_data), 4)
            self.assertEqual(len(analyzer._country_lookup), 4)

    def test_initialization_failure(self):
        """Test GeoAnalyzer initialization with error."""
        with patch('src.models.base.load_countries_data', side_effect=Exception("Load error")):
            analyzer = GeoAnalyzer()
            self.assertEqual(len(analyzer.countries_data), 0)
            self.assertEqual(len(analyzer._country_lookup), 0)

    def test_get_country_success(self):
        """Test retrieving a country by A3 code."""
        with patch('src.models.base.load_countries_data', return_value=self.countries_data), \
             patch('src.models.base.load_affiliations_data', return_value=self.affiliations_data):
            analyzer = GeoAnalyzer()
            country = analyzer.get_country("USA")
            self.assertIsNotNone(country)
            self.assertEqual(country.name, "United States")
            self.assertEqual(country.a3, "USA")

    def test_get_country_not_found(self):
        """Test retrieving a non-existent country."""
        with patch('src.models.base.load_countries_data', return_value=self.countries_data), \
             patch('src.models.base.load_affiliations_data', return_value=self.affiliations_data):
            analyzer = GeoAnalyzer()
            country = analyzer.get_country("XXX")
            self.assertIsNone(country)

    def test_countries_share_region_true(self):
        """Test countries that share the same region."""
        with patch('src.models.base.load_countries_data', return_value=self.countries_data), \
             patch('src.models.base.load_affiliations_data', return_value=self.affiliations_data):
            analyzer = GeoAnalyzer()
            result = analyzer.countries_share_region("USA", "CAN")
            self.assertTrue(result)

    def test_countries_share_region_false(self):
        """Test countries that don't share the same region."""
        with patch('src.models.base.load_countries_data', return_value=self.countries_data), \
             patch('src.models.base.load_affiliations_data', return_value=self.affiliations_data):
            analyzer = GeoAnalyzer()
            result = analyzer.countries_share_region("USA", "JPN")
            self.assertFalse(result)

    def test_countries_share_region_invalid_country(self):
        """Test region check with invalid country."""
        with patch('src.models.base.load_countries_data', return_value=self.countries_data), \
             patch('src.models.base.load_affiliations_data', return_value=self.affiliations_data):
            analyzer = GeoAnalyzer()
            result = analyzer.countries_share_region("USA", "XXX")
            self.assertFalse(result)

    def test_countries_share_subregion_true(self):
        """Test countries that share the same sub-region."""
        with patch('src.models.base.load_countries_data', return_value=self.countries_data), \
             patch('src.models.base.load_affiliations_data', return_value=self.affiliations_data):
            analyzer = GeoAnalyzer()
            result = analyzer.countries_share_subregion("USA", "CAN")
            self.assertTrue(result)

    def test_countries_share_subregion_false(self):
        """Test countries that don't share the same sub-region."""
        with patch('src.models.base.load_countries_data', return_value=self.countries_data), \
             patch('src.models.base.load_affiliations_data', return_value=self.affiliations_data):
            analyzer = GeoAnalyzer()
            result = analyzer.countries_share_subregion("USA", "FRA")
            self.assertFalse(result)

    def test_get_shared_affiliations(self):
        """Test getting shared affiliations between countries."""
        with patch('src.models.base.load_countries_data', return_value=self.countries_data), \
             patch('src.models.base.load_affiliations_data', return_value=self.affiliations_data):
            analyzer = GeoAnalyzer()
            shared = analyzer.get_shared_affiliations("USA", "CAN")
            self.assertEqual(shared, {"NATO", "OECD"})

    def test_get_shared_affiliations_partial(self):
        """Test getting partial shared affiliations."""
        with patch('src.models.base.load_countries_data', return_value=self.countries_data), \
             patch('src.models.base.load_affiliations_data', return_value=self.affiliations_data):
            analyzer = GeoAnalyzer()
            shared = analyzer.get_shared_affiliations("USA", "JPN")
            self.assertEqual(shared, {"OECD"})

    def test_get_shared_affiliations_none(self):
        """Test getting shared affiliations when none exist."""
        countries_no_shared = self.countries_data.copy()
        countries_no_shared.append({
            "name": "Brazil",
            "a2": "BR",
            "a3": "BRA",
            "num": "076",
            "region": "Americas",
            "sub_region": "South America",
            "affiliations": []
        })
        with patch('src.models.base.load_countries_data', return_value=countries_no_shared), \
             patch('src.models.base.load_affiliations_data', return_value=self.affiliations_data):
            analyzer = GeoAnalyzer()
            shared = analyzer.get_shared_affiliations("USA", "BRA")
            self.assertEqual(len(shared), 0)

    def test_calculate_geo_similarity_same_country(self):
        """Test similarity calculation for same country."""
        with patch('src.models.base.load_countries_data', return_value=self.countries_data), \
             patch('src.models.base.load_affiliations_data', return_value=self.affiliations_data):
            analyzer = GeoAnalyzer()
            similarity = analyzer.calculate_geo_similarity("USA", "USA")
            self.assertEqual(similarity, 1.0)

    def test_calculate_geo_similarity_high(self):
        """Test similarity calculation for very similar countries."""
        with patch('src.models.base.load_countries_data', return_value=self.countries_data), \
             patch('src.models.base.load_affiliations_data', return_value=self.affiliations_data):
            analyzer = GeoAnalyzer()
            similarity = analyzer.calculate_geo_similarity("USA", "CAN")
            # Same region (0.3) + Same sub-region (0.3) + 2 shared affiliations (0.2) = 0.8
            self.assertEqual(similarity, 0.8)

    def test_calculate_geo_similarity_medium(self):
        """Test similarity calculation for partially similar countries."""
        with patch('src.models.base.load_countries_data', return_value=self.countries_data), \
             patch('src.models.base.load_affiliations_data', return_value=self.affiliations_data):
            analyzer = GeoAnalyzer()
            similarity = analyzer.calculate_geo_similarity("USA", "FRA")
            # Different region (0) + Different sub-region (0) + 2 shared affiliations (0.2) = 0.2
            self.assertEqual(similarity, 0.2)

    def test_calculate_geo_similarity_low(self):
        """Test similarity calculation for dissimilar countries."""
        with patch('src.models.base.load_countries_data', return_value=self.countries_data), \
             patch('src.models.base.load_affiliations_data', return_value=self.affiliations_data):
            analyzer = GeoAnalyzer()
            similarity = analyzer.calculate_geo_similarity("USA", "JPN")
            # Different region (0) + Different sub-region (0) + 1 shared affiliation (0.1) = 0.1
            self.assertEqual(similarity, 0.1)

    def test_calculate_geo_similarity_max_affiliations(self):
        """Test that affiliation bonus is capped at 0.4."""
        countries_many_aff = [
            {
                "name": "Country A",
                "a2": "AA",
                "a3": "AAA",
                "num": "001",
                "region": "Test",
                "sub_region": "Test",
                "affiliations": ["A1", "A2", "A3", "A4", "A5", "A6"]
            },
            {
                "name": "Country B",
                "a2": "BB",
                "a3": "BBB",
                "num": "002",
                "region": "Test",
                "sub_region": "Test",
                "affiliations": ["A1", "A2", "A3", "A4", "A5", "A6"]
            }
        ]
        with patch('src.models.base.load_countries_data', return_value=countries_many_aff), \
             patch('src.models.base.load_affiliations_data', return_value={}):
            analyzer = GeoAnalyzer()
            similarity = analyzer.calculate_geo_similarity("AAA", "BBB")
            # Same region (0.3) + Same sub-region (0.3) + Max affiliations (0.4) = 1.0
            self.assertEqual(similarity, 1.0)

    def test_calculate_geo_similarity_invalid_country(self):
        """Test similarity calculation with invalid country."""
        with patch('src.models.base.load_countries_data', return_value=self.countries_data), \
             patch('src.models.base.load_affiliations_data', return_value=self.affiliations_data):
            analyzer = GeoAnalyzer()
            similarity = analyzer.calculate_geo_similarity("USA", "XXX")
            self.assertEqual(similarity, 0.0)


if __name__ == '__main__':
    unittest.main()
