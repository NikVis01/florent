import json
import os

def extract_affiliations():
    # Paths
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    input_path = os.path.join(base_dir, "src", "models", "data", "countries.json")
    output_path = os.path.join(base_dir, "src", "models", "data", "affiliations.json")

    if not os.path.exists(input_path):
        print(f"Error: Could not find {input_path}")
        return

    with open(input_path, "r") as f:
        countries = json.load(f)

    affiliations_map = {}

    for country in countries:
        a3 = country.get("a3")
        affiliations = country.get("affiliations", [])
        
        if not a3:
            continue
            
        for aff in affiliations:
            if aff not in affiliations_map:
                affiliations_map[aff] = []
            if a3 not in affiliations_map[aff]:
                affiliations_map[aff].append(a3)

    # Sort the map and the lists within it for consistency
    sorted_map = {k: sorted(v) for k, v in sorted(affiliations_map.items())}

    with open(output_path, "w") as f:
        json.dump(sorted_map, f, indent=4)

    print(f"Successfully extracted {len(sorted_map)} affiliations to {output_path}")

if __name__ == "__main__":
    extract_affiliations()
