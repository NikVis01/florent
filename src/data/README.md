# Florent Data Registry

This directory contains the central registries, taxonomies, and proof-of-concept data for the Florent Neuro-Symbolic Engine.

## Directory Structure

### `geo/`
Contains geo-spatial and geo-political metadata.
- **`countries.json`**: Ground truth for ISO 3166-1 alpha-3 country codes, regions, and names.
- **`affiliations.json`**: Reverse mapping of geo-political affiliations (e.g., BRICS, OPEC) to participating country codes.

### `taxonomy/`
Contains normalized registries and classification schemas.
- **`services.json`**: Detailed catalogue of infrastructure consultancy services (Financial, Advisory, Technical).
- **`categories.json`**: Higher-level groupings for services (Service Types).
- **`sectors.json`**: Industry sector classifications (Energy, Infrastructure, etc.).
- **`strategic_focus.json`**: Strategic goal identifiers (Sustainability, Innovation, etc.).

### `config/`
Contains engine parameters and physical constants.
- **`metrics.json`**: Mathematical weights, attenuation factors, and threshold constants for risk propagation.

### `poc/` (Proof of Concept)
Contains sample inputs for testing and demonstration.
- **`firm.json`**: A sample profile of a global infrastructure consultant.
- **`project.json`**: A sample infrastructure DAG project requirements and topology.

## Usage
Data paths are managed centrally in `src/models/base.py`. Use the provided loader functions (e.g., `load_countries_data`, `get_categories`) to access these files to ensure consistent validation and caching.
