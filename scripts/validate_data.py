#!/usr/bin/env python3
"""
Data validation script for src/data/ directory.

Validates all JSON files in the data directory, checking for:
- Valid JSON syntax
- Common typos (e.g., "prefered" instead of "preferred")
- Case inconsistencies in affiliations
- Missing required fields
- Broken references between data files
- Duplicate IDs
"""

import json
import sys
from pathlib import Path
from typing import Any, Dict, List, Set, Tuple


class DataValidator:
    """Validates data files in src/data/ directory."""

    def __init__(self, data_dir: Path):
        self.data_dir = data_dir
        self.errors: List[str] = []
        self.warnings: List[str] = []
        self.affiliations: Dict[str, List[str]] = {}
        self.country_codes: Set[str] = set()
        self.service_ids: Set[str] = set()
        self.service_names: Set[str] = set()

    def validate_all(self) -> bool:
        """Run all validation checks."""
        print("Starting data validation...")
        print(f"Data directory: {self.data_dir}\n")

        # Load reference data first
        self._load_reference_data()

        # Validate all JSON files
        json_files = list(self.data_dir.rglob("*.json"))
        print(f"Found {len(json_files)} JSON files\n")

        for json_file in json_files:
            self._validate_json_file(json_file)

        # Run cross-file validation
        self._validate_cross_references()
        self._validate_case_consistency()
        self._validate_common_typos()

        # Print results
        self._print_results()

        return len(self.errors) == 0

    def _load_reference_data(self):
        """Load reference data for cross-validation."""
        # Load affiliations
        affiliations_file = self.data_dir / "geo" / "affiliations.json"
        if affiliations_file.exists():
            try:
                with open(affiliations_file, "r", encoding="utf-8") as f:
                    self.affiliations = json.load(f)
            except Exception as e:
                self.errors.append(f"Failed to load affiliations.json: {e}")

        # Load countries
        countries_file = self.data_dir / "geo" / "countries.json"
        if countries_file.exists():
            try:
                with open(countries_file, "r", encoding="utf-8") as f:
                    countries = json.load(f)
                    self.country_codes = {c["a3"] for c in countries}
            except Exception as e:
                self.errors.append(f"Failed to load countries.json: {e}")

        # Load services
        services_file = self.data_dir / "taxonomy" / "services.json"
        if services_file.exists():
            try:
                with open(services_file, "r", encoding="utf-8") as f:
                    services = json.load(f)
                    self.service_ids = {s["id"] for s in services}
                    self.service_names = {s["name"] for s in services}
            except Exception as e:
                self.errors.append(f"Failed to load services.json: {e}")

    def _validate_json_file(self, json_file: Path):
        """Validate a single JSON file."""
        relative_path = json_file.relative_to(self.data_dir)

        try:
            with open(json_file, "r", encoding="utf-8") as f:
                data = json.load(f)

            # File-specific validation
            if json_file.name == "firm.json":
                self._validate_firm(data, relative_path)
            elif json_file.name == "project.json":
                self._validate_project(data, relative_path)
            elif json_file.name == "services.json":
                self._validate_services(data, relative_path)
            elif json_file.name == "affiliations.json":
                self._validate_affiliations(data, relative_path)
            elif json_file.name == "countries.json":
                self._validate_countries(data, relative_path)

        except json.JSONDecodeError as e:
            self.errors.append(f"{relative_path}: Invalid JSON - {e}")
        except Exception as e:
            self.errors.append(f"{relative_path}: Error reading file - {e}")

    def _validate_firm(self, data: Dict[str, Any], path: Path):
        """Validate firm.json structure."""
        required_fields = ["id", "name", "description"]
        for field in required_fields:
            if field not in data:
                self.errors.append(f"{path}: Missing required field '{field}'")

        # Check for typos in field names
        if "prefered_project_timeline" in data:
            self.errors.append(
                f"{path}: Typo in field name 'prefered_project_timeline' "
                "(should be 'preferred_project_timeline')"
            )

        # Validate country affiliations
        if "countries_active" in data:
            for country in data["countries_active"]:
                if "affiliations" in country:
                    self._validate_affiliation_references(
                        country["affiliations"], path
                    )

    def _validate_project(self, data: Dict[str, Any], path: Path):
        """Validate project.json structure."""
        required_fields = ["id", "name"]
        for field in required_fields:
            if field not in data:
                self.errors.append(f"{path}: Missing required field '{field}'")

    def _validate_services(self, data: List[Dict[str, Any]], path: Path):
        """Validate services.json structure."""
        seen_ids = set()
        seen_names = set()

        for service in data:
            # Check for duplicate IDs
            if "id" in service:
                if service["id"] in seen_ids:
                    self.errors.append(
                        f"{path}: Duplicate service ID '{service['id']}'"
                    )
                seen_ids.add(service["id"])

            # Check for duplicate names
            if "name" in service:
                if service["name"] in seen_names:
                    self.warnings.append(
                        f"{path}: Duplicate service name '{service['name']}'"
                    )
                seen_names.add(service["name"])

            # Validate required fields
            required_fields = ["id", "name", "category", "description"]
            for field in required_fields:
                if field not in service:
                    self.errors.append(
                        f"{path}: Service '{service.get('name', 'unknown')}' "
                        f"missing required field '{field}'"
                    )

    def _validate_affiliations(self, data: Dict[str, List[str]], path: Path):
        """Validate affiliations.json structure."""
        # Check that all country codes are valid
        for affiliation, countries in data.items():
            for country_code in countries:
                if self.country_codes and country_code not in self.country_codes:
                    self.warnings.append(
                        f"{path}: Unknown country code '{country_code}' "
                        f"in affiliation '{affiliation}'"
                    )

    def _validate_countries(self, data: List[Dict[str, Any]], path: Path):
        """Validate countries.json structure."""
        for country in data:
            required_fields = ["name", "a2", "a3", "num"]
            for field in required_fields:
                if field not in country:
                    self.errors.append(
                        f"{path}: Country '{country.get('name', 'unknown')}' "
                        f"missing required field '{field}'"
                    )

            # Validate affiliations
            if "affiliations" in country:
                self._validate_affiliation_references(
                    country["affiliations"], path
                )

    def _validate_affiliation_references(
        self, affiliations: List[str], path: Path
    ):
        """Validate that affiliation references exist."""
        for affiliation in affiliations:
            if self.affiliations and affiliation not in self.affiliations:
                self.warnings.append(
                    f"{path}: Unknown affiliation '{affiliation}'"
                )

    def _validate_cross_references(self):
        """Validate references between files."""
        # Check that referenced services exist
        firm_file = self.data_dir / "poc" / "firm.json"
        if firm_file.exists() and self.service_names:
            try:
                with open(firm_file, "r", encoding="utf-8") as f:
                    firm = json.load(f)
                    if "services" in firm:
                        for service in firm["services"]:
                            if service["name"] not in self.service_names:
                                self.warnings.append(
                                    f"poc/firm.json: Service '{service['name']}' "
                                    "not found in taxonomy/services.json"
                                )
            except Exception:
                pass  # Error already reported in file validation

    def _validate_case_consistency(self):
        """Check for case inconsistencies in affiliation names."""
        if not self.affiliations:
            return

        # Expected patterns for case consistency
        expected_uppercase = {
            "AL", "ASEAN", "AU", "AUKUS", "BRICS", "CARICOM", "CIS", "CPTPP",
            "CSTO", "EAC", "EAEU", "ECOWAS", "EFTA", "EU", "G20", "G7", "GCC",
            "MERCOSUR", "NATO", "OECD", "OIC", "OPEC", "PIF", "SAARC", "SACU",
            "SADC", "SCO", "USMCA"
        }

        for affiliation in self.affiliations.keys():
            # Check if it should be uppercase
            if affiliation.upper() in expected_uppercase:
                if affiliation != affiliation.upper():
                    self.errors.append(
                        f"geo/affiliations.json: Affiliation '{affiliation}' "
                        f"should be uppercase '{affiliation.upper()}'"
                    )

    def _validate_common_typos(self):
        """Check for common typos across all files."""
        common_typos = {
            "prefered": "preferred",
            "seperate": "separate",
            "occured": "occurred",
            "recieve": "receive",
            "managment": "management",
        }

        for json_file in self.data_dir.rglob("*.json"):
            try:
                with open(json_file, "r", encoding="utf-8") as f:
                    content = f.read()
                    for typo, correct in common_typos.items():
                        if typo in content.lower():
                            relative_path = json_file.relative_to(self.data_dir)
                            self.warnings.append(
                                f"{relative_path}: Possible typo '{typo}' "
                                f"(should be '{correct}')"
                            )
            except Exception:
                pass  # Error already reported in file validation

    def _print_results(self):
        """Print validation results."""
        print("\n" + "=" * 70)
        print("VALIDATION RESULTS")
        print("=" * 70)

        if self.errors:
            print(f"\nERRORS ({len(self.errors)}):")
            for error in self.errors:
                print(f"  ✗ {error}")

        if self.warnings:
            print(f"\nWARNINGS ({len(self.warnings)}):")
            for warning in self.warnings:
                print(f"  ⚠ {warning}")

        if not self.errors and not self.warnings:
            print("\n✓ All validation checks passed!")
        elif not self.errors:
            print(f"\n✓ No errors found ({len(self.warnings)} warnings)")
        else:
            print(f"\n✗ Validation failed with {len(self.errors)} errors")

        print("=" * 70 + "\n")


def main():
    """Main entry point."""
    # Determine data directory
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    data_dir = project_root / "src" / "data"

    if not data_dir.exists():
        print(f"Error: Data directory not found: {data_dir}")
        sys.exit(1)

    # Run validation
    validator = DataValidator(data_dir)
    success = validator.validate_all()

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
