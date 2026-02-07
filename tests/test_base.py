import sys
import os
import unittest
from unittest.mock import patch, mock_open, MagicMock
from pydantic import ValidationError
import json

# Add src to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from src.models.base import (
    OperationType, Sectors, StrategicFocus, Country,
    load_countries_data, load_affiliations_data, load_services_data,
    load_registry_list, get_categories, get_sectors, get_focuses
)


class TestDataLoaders(unittest.TestCase):
    """Test data loading functions."""

    def test_load_countries_data_missing_file(self):
        """Test loading countries when file doesn't exist."""
        with patch('os.path.exists', return_value=False):
            result = load_countries_data()
            self.assertEqual(result, [])

    def test_load_countries_data_success(self):
        """Test successful loading of countries data."""
        mock_data = [{"name": "USA", "a3": "USA"}]
        with patch('os.path.exists', return_value=True), \
             patch('builtins.open', mock_open(read_data=json.dumps(mock_data))):
            result = load_countries_data()
            self.assertEqual(result, mock_data)

    def test_load_affiliations_data_missing_file(self):
        """Test loading affiliations when file doesn't exist."""
        with patch('os.path.exists', return_value=False):
            result = load_affiliations_data()
            self.assertEqual(result, {})

    def test_load_affiliations_data_success(self):
        """Test successful loading of affiliations data."""
        mock_data = {"EU": ["FRA", "DEU"]}
        with patch('os.path.exists', return_value=True), \
             patch('builtins.open', mock_open(read_data=json.dumps(mock_data))):
            result = load_affiliations_data()
            self.assertEqual(result, mock_data)

    def test_load_services_data_missing_file(self):
        """Test loading services when file doesn't exist."""
        with patch('os.path.exists', return_value=False):
            result = load_services_data()
            self.assertEqual(result, [])

    def test_load_registry_list_missing_file(self):
        """Test loading registry list when file doesn't exist."""
        with patch('os.path.exists', return_value=False):
            result = load_registry_list('/fake/path.json')
            self.assertEqual(result, [])

    def test_load_registry_list_with_key(self):
        """Test loading registry list with specific key."""
        mock_data = {"items": ["item1", "item2"]}
        with patch('os.path.exists', return_value=True), \
             patch('builtins.open', mock_open(read_data=json.dumps(mock_data))):
            result = load_registry_list('/fake/path.json', key='items')
            self.assertEqual(result, ["item1", "item2"])

    def test_load_registry_list_without_key(self):
        """Test loading registry list without key."""
        mock_data = ["item1", "item2"]
        with patch('os.path.exists', return_value=True), \
             patch('builtins.open', mock_open(read_data=json.dumps(mock_data))):
            result = load_registry_list('/fake/path.json')
            self.assertEqual(result, mock_data)


class TestOperationType(unittest.TestCase):
    """Test OperationType model."""

    def setUp(self):
        # Mock the categories registry
        self.mock_categories = {"transportation", "logistics", "manufacturing"}
        self.patcher = patch('src.models.base.get_categories', return_value=self.mock_categories)
        self.patcher.start()

    def tearDown(self):
        self.patcher.stop()

    def test_valid_operation_type(self):
        """Test creating a valid OperationType."""
        op = OperationType(
            name="Trucking",
            category="transportation",
            description="Heavy-duty freight transport"
        )
        self.assertEqual(op.name, "Trucking")
        self.assertEqual(op.category, "transportation")
        self.assertEqual(op.description, "Heavy-duty freight transport")

    def test_invalid_category(self):
        """Test creating OperationType with invalid category."""
        with self.assertRaises(ValidationError) as context:
            OperationType(
                name="Invalid",
                category="invalid_category",
                description="Should fail"
            )
        self.assertIn("not in registry", str(context.exception))

    def test_missing_fields(self):
        """Test creating OperationType with missing fields."""
        with self.assertRaises(ValidationError):
            OperationType(name="Incomplete")


class TestSectors(unittest.TestCase):
    """Test Sectors model."""

    def setUp(self):
        self.mock_sectors = {"energy", "finance", "healthcare"}
        self.patcher = patch('src.models.base.get_sectors', return_value=self.mock_sectors)
        self.patcher.start()

    def tearDown(self):
        self.patcher.stop()

    def test_valid_sector(self):
        """Test creating a valid Sector."""
        sector = Sectors(
            name="Energy Sector",
            description="energy"
        )
        self.assertEqual(sector.name, "Energy Sector")
        self.assertEqual(sector.description, "energy")

    def test_invalid_sector(self):
        """Test creating Sector with invalid description."""
        with self.assertRaises(ValidationError) as context:
            Sectors(
                name="Invalid Sector",
                description="invalid_sector"
            )
        self.assertIn("not in registry", str(context.exception))


class TestStrategicFocus(unittest.TestCase):
    """Test StrategicFocus model."""

    def setUp(self):
        self.mock_focuses = {"cost_reduction", "market_expansion", "innovation"}
        self.patcher = patch('src.models.base.get_focuses', return_value=self.mock_focuses)
        self.patcher.start()

    def tearDown(self):
        self.patcher.stop()

    def test_valid_strategic_focus(self):
        """Test creating a valid StrategicFocus."""
        focus = StrategicFocus(
            name="Cost Leadership",
            description="cost_reduction"
        )
        self.assertEqual(focus.name, "Cost Leadership")
        self.assertEqual(focus.description, "cost_reduction")

    def test_invalid_focus(self):
        """Test creating StrategicFocus with invalid description."""
        with self.assertRaises(ValidationError) as context:
            StrategicFocus(
                name="Invalid Focus",
                description="invalid_focus"
            )
        self.assertIn("not in registry", str(context.exception))


class TestCountry(unittest.TestCase):
    """Test Country model."""

    def test_valid_country(self):
        """Test creating a valid Country."""
        country = Country(
            name="France",
            a2="FR",
            a3="FRA",
            num="250",
            region="Europe",
            sub_region="Western Europe",
            affiliations=["EU", "NATO"]
        )
        self.assertEqual(country.name, "France")
        self.assertEqual(country.a3, "FRA")
        self.assertEqual(len(country.affiliations), 2)

    def test_country_without_affiliations(self):
        """Test creating Country without affiliations."""
        country = Country(
            name="Switzerland",
            a2="CH",
            a3="CHE",
            num="756",
            region="Europe",
            sub_region="Western Europe"
        )
        self.assertEqual(len(country.affiliations), 0)

    def test_country_missing_required_fields(self):
        """Test creating Country with missing required fields."""
        with self.assertRaises(ValidationError):
            Country(
                name="Incomplete",
                a2="XX"
            )


class TestRegistryCache(unittest.TestCase):
    """Test registry caching mechanisms."""

    def test_categories_cache(self):
        """Test that get_categories caches results."""
        mock_data = {"service_types": ["type1", "type2"]}
        with patch('os.path.exists', return_value=True), \
             patch('builtins.open', mock_open(read_data=json.dumps(mock_data))):
            # First call
            result1 = get_categories()
            # Second call should use cache
            result2 = get_categories()
            self.assertEqual(result1, result2)
            self.assertIsInstance(result1, set)

    def test_sectors_cache(self):
        """Test that get_sectors caches results."""
        mock_data = {"sectors": ["sector1", "sector2"]}
        with patch('os.path.exists', return_value=True), \
             patch('builtins.open', mock_open(read_data=json.dumps(mock_data))):
            result1 = get_sectors()
            result2 = get_sectors()
            self.assertEqual(result1, result2)
            self.assertIsInstance(result1, set)

    def test_focuses_cache(self):
        """Test that get_focuses caches results."""
        mock_data = {"focuses": ["focus1", "focus2"]}
        with patch('os.path.exists', return_value=True), \
             patch('builtins.open', mock_open(read_data=json.dumps(mock_data))):
            result1 = get_focuses()
            result2 = get_focuses()
            self.assertEqual(result1, result2)
            self.assertIsInstance(result1, set)


if __name__ == '__main__':
    unittest.main()
