#!/usr/bin/env python3
"""Generate 20 diverse infrastructure projects around the world."""
import json
from pathlib import Path

PROJECTS = [
    {
        "id": "proj_000",
        "name": "Amazonas Smart Grid Phase I",
        "description": "Development of a decentralized renewable energy grid to stabilize power supply in the northern Amazonas region.",
        "country": {"name": "Brazil", "a2": "BR", "a3": "BRA", "num": "076", "region": "Americas", "sub_region": "South America", "affiliations": ["BRICS", "G20", "MERCOSUR"]},
        "sector": "energy",
        "service_requirements": ["Environmental Impact Assessment (EIA)", "Grid Integrity Verification", "Public-Private Partnership Management"],
        "timeline": 36,
        "ops_requirements": [
            {"name": "Capital Mobilization", "category": "financing", "description": "Securing upfront funding for grid hardware."},
            {"name": "Industrial Equipment Supply", "category": "equipment", "description": "Sourcing and deploying transformers and substations."}
        ],
        "entry_criteria": {"pre_requisites": ["Environmental Permit Approved", "Regional Gvt Agreement Signed"], "mobilization_time": 6, "entry_node_id": "node_site_survey"},
        "success_criteria": {"success_metrics": ["Grid Uptime > 99%", "Zero Major Safety Incidents"], "mandate_end_date": "2029-12-31", "exit_node_id": "node_operations_handover"}
    },
    {
        "id": "proj_001",
        "name": "Lagos Port Expansion",
        "description": "Deep-water port expansion to increase cargo capacity and reduce vessel waiting times in West Africa's busiest port.",
        "country": {"name": "Nigeria", "a2": "NG", "a3": "NGA", "num": "566", "region": "Africa", "sub_region": "Western Africa", "affiliations": ["ECOWAS", "African Union", "OPEC"]},
        "sector": "transportation",
        "service_requirements": ["Marine Engineering Assessment", "Trade Flow Analysis", "Customs Integration Planning"],
        "timeline": 48,
        "ops_requirements": [
            {"name": "Dredging Operations", "category": "construction", "description": "Deepening harbor to accommodate larger vessels."},
            {"name": "Crane Infrastructure", "category": "equipment", "description": "Installing automated container handling systems."},
            {"name": "Security Systems", "category": "security", "description": "Port security and surveillance infrastructure."}
        ],
        "entry_criteria": {"pre_requisites": ["Maritime Authority Approval", "Environmental Clearance"], "mobilization_time": 9, "entry_node_id": "node_feasibility_study"},
        "success_criteria": {"success_metrics": ["Container Throughput +40%", "Vessel Turnaround Time < 48hrs"], "mandate_end_date": "2030-06-30", "exit_node_id": "node_port_handover"}
    },
    {
        "id": "proj_002",
        "name": "Mumbai Metro Line 7 Extension",
        "description": "Extension of metro line serving suburban districts to reduce road congestion and improve urban mobility.",
        "country": {"name": "India", "a2": "IN", "a3": "IND", "num": "356", "region": "Asia", "sub_region": "Southern Asia", "affiliations": ["BRICS", "G20", "SAARC"]},
        "sector": "transportation",
        "service_requirements": ["Urban Planning Integration", "Right-of-Way Acquisition", "Rail Safety Certification"],
        "timeline": 60,
        "ops_requirements": [
            {"name": "Tunnel Boring", "category": "construction", "description": "Underground tunneling through dense urban area."},
            {"name": "Station Construction", "category": "construction", "description": "Building 12 new metro stations."},
            {"name": "Rolling Stock Procurement", "category": "equipment", "description": "Acquiring metro train sets."}
        ],
        "entry_criteria": {"pre_requisites": ["State Government Approval", "Land Acquisition Complete"], "mobilization_time": 12, "entry_node_id": "node_design_phase"},
        "success_criteria": {"success_metrics": ["Daily Ridership > 300k", "On-time Performance > 95%"], "mandate_end_date": "2031-03-31", "exit_node_id": "node_operations_transfer"}
    },
    {
        "id": "proj_003",
        "name": "Hanoi Water Treatment Plant",
        "description": "Modern wastewater treatment facility to serve 2 million residents and improve Mekong River water quality.",
        "country": {"name": "Vietnam", "a2": "VN", "a3": "VNM", "num": "704", "region": "Asia", "sub_region": "South-Eastern Asia", "affiliations": ["ASEAN", "APEC"]},
        "sector": "water",
        "service_requirements": ["Water Quality Baseline Study", "Discharge Permit Compliance", "Public Health Assessment"],
        "timeline": 30,
        "ops_requirements": [
            {"name": "Treatment Technology Selection", "category": "engineering", "description": "Selecting advanced treatment systems."},
            {"name": "Pipeline Network", "category": "construction", "description": "Building sewage collection infrastructure."},
            {"name": "Operations Training", "category": "capacity_building", "description": "Training local operators."}
        ],
        "entry_criteria": {"pre_requisites": ["Environmental Permit", "Budget Approval"], "mobilization_time": 4, "entry_node_id": "node_site_preparation"},
        "success_criteria": {"success_metrics": ["BOD Reduction > 90%", "Zero Discharge Violations"], "mandate_end_date": "2028-12-31", "exit_node_id": "node_facility_handover"}
    },
    {
        "id": "proj_004",
        "name": "Cairo 5G Network Rollout",
        "description": "Deployment of 5G telecommunications infrastructure across Greater Cairo metropolitan area.",
        "country": {"name": "Egypt", "a2": "EG", "a3": "EGY", "num": "818", "region": "Africa", "sub_region": "Northern Africa", "affiliations": ["African Union", "Arab League"]},
        "sector": "telecommunications",
        "service_requirements": ["Spectrum Licensing", "Network Architecture Design", "Cybersecurity Assessment"],
        "timeline": 24,
        "ops_requirements": [
            {"name": "Cell Tower Deployment", "category": "equipment", "description": "Installing 5G base stations."},
            {"name": "Fiber Backbone", "category": "construction", "description": "Laying fiber optic network."},
            {"name": "Network Testing", "category": "testing", "description": "Performance and security testing."}
        ],
        "entry_criteria": {"pre_requisites": ["Telecom License", "Site Permits"], "mobilization_time": 3, "entry_node_id": "node_planning"},
        "success_criteria": {"success_metrics": ["Coverage > 85%", "Avg Speed > 500 Mbps"], "mandate_end_date": "2027-12-31", "exit_node_id": "node_network_live"}
    },
    {
        "id": "proj_005",
        "name": "Jakarta Flood Defense System",
        "description": "Integrated flood management system including seawalls, pumping stations, and retention basins.",
        "country": {"name": "Indonesia", "a2": "ID", "a3": "IDN", "num": "360", "region": "Asia", "sub_region": "South-Eastern Asia", "affiliations": ["ASEAN", "G20", "APEC"]},
        "sector": "water",
        "service_requirements": ["Hydrological Modeling", "Coastal Engineering", "Urban Drainage Planning"],
        "timeline": 72,
        "ops_requirements": [
            {"name": "Seawall Construction", "category": "construction", "description": "Building 15km coastal barrier."},
            {"name": "Pumping Infrastructure", "category": "equipment", "description": "Installing flood water pumps."},
            {"name": "Early Warning System", "category": "technology", "description": "Flood monitoring and alert system."}
        ],
        "entry_criteria": {"pre_requisites": ["World Bank Financing", "Presidential Decree"], "mobilization_time": 18, "entry_node_id": "node_master_plan"},
        "success_criteria": {"success_metrics": ["Flood Risk Reduction 60%", "Protected Population 8M"], "mandate_end_date": "2032-06-30", "exit_node_id": "node_system_operational"}
    },
    {
        "id": "proj_006",
        "name": "Nairobi Affordable Housing Development",
        "description": "Construction of 10,000 affordable housing units with integrated social infrastructure.",
        "country": {"name": "Kenya", "a2": "KE", "a3": "KEN", "num": "404", "region": "Africa", "sub_region": "Eastern Africa", "affiliations": ["African Union", "East African Community"]},
        "sector": "housing",
        "service_requirements": ["Urban Planning Approval", "Social Impact Assessment", "Affordable Housing Financing"],
        "timeline": 42,
        "ops_requirements": [
            {"name": "Land Preparation", "category": "construction", "description": "Site clearing and leveling."},
            {"name": "Building Construction", "category": "construction", "description": "Multi-story residential blocks."},
            {"name": "Utilities Connection", "category": "utilities", "description": "Water, power, sewage hookup."}
        ],
        "entry_criteria": {"pre_requisites": ["Land Title Transfer", "Building Permits"], "mobilization_time": 6, "entry_node_id": "node_site_survey"},
        "success_criteria": {"success_metrics": ["Units Delivered 10k", "Occupancy Rate > 90%"], "mandate_end_date": "2029-09-30", "exit_node_id": "node_handover_residents"}
    },
    {
        "id": "proj_007",
        "name": "Buenos Aires Solar Farm",
        "description": "500 MW solar photovoltaic farm to supply clean energy to the capital region.",
        "country": {"name": "Argentina", "a2": "AR", "a3": "ARG", "num": "032", "region": "Americas", "sub_region": "South America", "affiliations": ["G20", "MERCOSUR"]},
        "sector": "energy",
        "service_requirements": ["Grid Connection Study", "Land Lease Agreements", "Carbon Credit Registration"],
        "timeline": 30,
        "ops_requirements": [
            {"name": "Solar Panel Procurement", "category": "equipment", "description": "Importing PV modules."},
            {"name": "Substation Construction", "category": "construction", "description": "Building transmission substation."},
            {"name": "Grid Integration", "category": "engineering", "description": "Connecting to national grid."}
        ],
        "entry_criteria": {"pre_requisites": ["Environmental License", "Grid Approval"], "mobilization_time": 8, "entry_node_id": "node_engineering_design"},
        "success_criteria": {"success_metrics": ["Capacity 500 MW", "Capacity Factor > 25%"], "mandate_end_date": "2028-06-30", "exit_node_id": "node_commercial_operation"}
    },
    {
        "id": "proj_008",
        "name": "Bangkok Airport Rail Link Phase 2",
        "description": "High-speed rail connection linking Suvarnabhumi Airport to eastern suburbs.",
        "country": {"name": "Thailand", "a2": "TH", "a3": "THA", "num": "764", "region": "Asia", "sub_region": "South-Eastern Asia", "affiliations": ["ASEAN"]},
        "sector": "transportation",
        "service_requirements": ["Aviation Authority Coordination", "Rail Safety Standards", "Ticketing Integration"],
        "timeline": 36,
        "ops_requirements": [
            {"name": "Track Construction", "category": "construction", "description": "Elevated rail guideway."},
            {"name": "Station Development", "category": "construction", "description": "Building 8 new stations."},
            {"name": "Train Procurement", "category": "equipment", "description": "High-speed rail cars."}
        ],
        "entry_criteria": {"pre_requisites": ["Transport Ministry Approval", "Route Finalization"], "mobilization_time": 10, "entry_node_id": "node_detailed_design"},
        "success_criteria": {"success_metrics": ["Travel Time < 20 min", "Daily Passengers > 50k"], "mandate_end_date": "2029-03-31", "exit_node_id": "node_service_launch"}
    },
    {
        "id": "proj_009",
        "name": "Istanbul Hospital Complex",
        "description": "1,200-bed tertiary care hospital with medical research facilities and teaching programs.",
        "country": {"name": "Turkey", "a2": "TR", "a3": "TUR", "num": "792", "region": "Asia", "sub_region": "Western Asia", "affiliations": ["G20", "NATO"]},
        "sector": "healthcare",
        "service_requirements": ["Healthcare Licensing", "Medical Equipment Certification", "Staff Recruitment Planning"],
        "timeline": 54,
        "ops_requirements": [
            {"name": "Hospital Construction", "category": "construction", "description": "Building main hospital structure."},
            {"name": "Medical Equipment", "category": "equipment", "description": "Procuring surgical and diagnostic equipment."},
            {"name": "IT Systems", "category": "technology", "description": "Hospital management system."}
        ],
        "entry_criteria": {"pre_requisites": ["Health Ministry Approval", "Zoning Clearance"], "mobilization_time": 12, "entry_node_id": "node_architectural_design"},
        "success_criteria": {"success_metrics": ["Operational Beds 1200", "Accreditation Achieved"], "mandate_end_date": "2030-12-31", "exit_node_id": "node_hospital_operational"}
    },
    {
        "id": "proj_010",
        "name": "Riyadh Smart City District",
        "description": "Development of a 5 km² smart city district with IoT infrastructure and sustainable design.",
        "country": {"name": "Saudi Arabia", "a2": "SA", "a3": "SAU", "num": "682", "region": "Asia", "sub_region": "Western Asia", "affiliations": ["G20", "OPEC", "Arab League"]},
        "sector": "urban_development",
        "service_requirements": ["Smart City Master Planning", "Technology Integration", "Sustainability Certification"],
        "timeline": 96,
        "ops_requirements": [
            {"name": "Infrastructure Development", "category": "construction", "description": "Roads, utilities, telecommunications."},
            {"name": "Building Construction", "category": "construction", "description": "Mixed-use smart buildings."},
            {"name": "IoT Deployment", "category": "technology", "description": "Sensors and control systems."}
        ],
        "entry_criteria": {"pre_requisites": ["Vision 2030 Alignment", "Royal Decree"], "mobilization_time": 24, "entry_node_id": "node_concept_design"},
        "success_criteria": {"success_metrics": ["Population 100k", "Carbon Neutral Operations"], "mandate_end_date": "2034-12-31", "exit_node_id": "node_district_complete"}
    },
    {
        "id": "proj_011",
        "name": "Manila Bay Bridge",
        "description": "24 km cable-stayed bridge connecting Manila to Cavite province to reduce traffic congestion.",
        "country": {"name": "Philippines", "a2": "PH", "a3": "PHL", "num": "608", "region": "Asia", "sub_region": "South-Eastern Asia", "affiliations": ["ASEAN"]},
        "sector": "transportation",
        "service_requirements": ["Marine Navigation Assessment", "Seismic Engineering", "Environmental Impact Study"],
        "timeline": 66,
        "ops_requirements": [
            {"name": "Foundation Works", "category": "construction", "description": "Deep-sea pile driving."},
            {"name": "Bridge Superstructure", "category": "construction", "description": "Cable-stayed span construction."},
            {"name": "Toll Collection System", "category": "technology", "description": "Automated toll infrastructure."}
        ],
        "entry_criteria": {"pre_requisites": ["Congressional Approval", "Japan Financing Secured"], "mobilization_time": 18, "entry_node_id": "node_geotechnical_study"},
        "success_criteria": {"success_metrics": ["Bridge Capacity 40k vehicles/day", "Seismic Rating 8.0"], "mandate_end_date": "2032-03-31", "exit_node_id": "node_bridge_opening"}
    },
    {
        "id": "proj_012",
        "name": "Lima Desalination Plant",
        "description": "Large-scale seawater desalination facility to address water scarcity in coastal Peru.",
        "country": {"name": "Peru", "a2": "PE", "a3": "PER", "num": "604", "region": "Americas", "sub_region": "South America", "affiliations": ["APEC"]},
        "sector": "water",
        "service_requirements": ["Marine Environmental Assessment", "Water Distribution Integration", "Energy Efficiency Study"],
        "timeline": 38,
        "ops_requirements": [
            {"name": "Desalination Technology", "category": "equipment", "description": "Reverse osmosis systems."},
            {"name": "Intake/Outfall Construction", "category": "construction", "description": "Ocean water intake and brine disposal."},
            {"name": "Pipeline Network", "category": "construction", "description": "Freshwater distribution pipes."}
        ],
        "entry_criteria": {"pre_requisites": ["Environmental Permit", "Coastal Zone Approval"], "mobilization_time": 9, "entry_node_id": "node_technology_selection"},
        "success_criteria": {"success_metrics": ["Capacity 100M liters/day", "Energy Use < 3.5 kWh/m³"], "mandate_end_date": "2029-06-30", "exit_node_id": "node_plant_operational"}
    },
    {
        "id": "proj_013",
        "name": "Accra International Trade Hub",
        "description": "Modern logistics and trade facilitation center with warehousing and customs facilities.",
        "country": {"name": "Ghana", "a2": "GH", "a3": "GHA", "num": "288", "region": "Africa", "sub_region": "Western Africa", "affiliations": ["ECOWAS", "African Union"]},
        "sector": "logistics",
        "service_requirements": ["Trade Policy Alignment", "Customs Automation", "Warehouse Management Systems"],
        "timeline": 32,
        "ops_requirements": [
            {"name": "Warehouse Construction", "category": "construction", "description": "Climate-controlled storage facilities."},
            {"name": "Logistics Technology", "category": "technology", "description": "Inventory tracking and customs systems."},
            {"name": "Road Access", "category": "construction", "description": "Highway connection and internal roads."}
        ],
        "entry_criteria": {"pre_requisites": ["Trade Ministry License", "Land Acquisition"], "mobilization_time": 6, "entry_node_id": "node_site_development"},
        "success_criteria": {"success_metrics": ["Storage Capacity 500k m³", "Customs Processing < 24hrs"], "mandate_end_date": "2028-09-30", "exit_node_id": "node_hub_operational"}
    },
    {
        "id": "proj_014",
        "name": "Seoul District Heating Network",
        "description": "Expansion of combined heat and power district heating system serving 200,000 households.",
        "country": {"name": "South Korea", "a2": "KR", "a3": "KOR", "num": "410", "region": "Asia", "sub_region": "Eastern Asia", "affiliations": ["G20", "OECD"]},
        "sector": "energy",
        "service_requirements": ["Energy Efficiency Assessment", "Urban Planning Integration", "Gas Supply Coordination"],
        "timeline": 28,
        "ops_requirements": [
            {"name": "CHP Plant Construction", "category": "construction", "description": "Combined heat and power facility."},
            {"name": "Heat Distribution Network", "category": "construction", "description": "Underground hot water pipes."},
            {"name": "Building Connections", "category": "construction", "description": "Connecting residential buildings."}
        ],
        "entry_criteria": {"pre_requisites": ["City Approval", "Utility Coordination"], "mobilization_time": 4, "entry_node_id": "node_network_design"},
        "success_criteria": {"success_metrics": ["Connected Households 200k", "Energy Savings 30%"], "mandate_end_date": "2028-03-31", "exit_node_id": "node_network_operational"}
    },
    {
        "id": "proj_015",
        "name": "Bogotá Bus Rapid Transit Expansion",
        "description": "Extension of TransMilenio BRT system with 50 km of dedicated bus lanes and 30 new stations.",
        "country": {"name": "Colombia", "a2": "CO", "a3": "COL", "num": "170", "region": "Americas", "sub_region": "South America", "affiliations": ["Pacific Alliance"]},
        "sector": "transportation",
        "service_requirements": ["Transit Planning", "Right-of-Way Acquisition", "Fare System Integration"],
        "timeline": 40,
        "ops_requirements": [
            {"name": "Busway Construction", "category": "construction", "description": "Dedicated bus-only lanes."},
            {"name": "Station Construction", "category": "construction", "description": "Modern BRT stations."},
            {"name": "Bus Fleet Procurement", "category": "equipment", "description": "Electric articulated buses."}
        ],
        "entry_criteria": {"pre_requisites": ["District Approval", "ADB Loan Secured"], "mobilization_time": 8, "entry_node_id": "node_corridor_planning"},
        "success_criteria": {"success_metrics": ["Daily Ridership > 500k", "Travel Time Reduction 25%"], "mandate_end_date": "2029-12-31", "exit_node_id": "node_service_operational"}
    },
    {
        "id": "proj_016",
        "name": "Dhaka Industrial Park Development",
        "description": "800-hectare industrial park with garment manufacturing facilities and export processing zones.",
        "country": {"name": "Bangladesh", "a2": "BD", "a3": "BGD", "num": "050", "region": "Asia", "sub_region": "Southern Asia", "affiliations": ["SAARC"]},
        "sector": "industrial",
        "service_requirements": ["Industrial Zoning Approval", "Environmental Compliance", "Export Zone Licensing"],
        "timeline": 48,
        "ops_requirements": [
            {"name": "Land Development", "category": "construction", "description": "Site preparation and infrastructure."},
            {"name": "Factory Construction", "category": "construction", "description": "Industrial buildings."},
            {"name": "Utilities Infrastructure", "category": "utilities", "description": "Power, water, sewage systems."}
        ],
        "entry_criteria": {"pre_requisites": ["Government Approval", "Environmental Clearance"], "mobilization_time": 12, "entry_node_id": "node_master_planning"},
        "success_criteria": {"success_metrics": ["Occupancy Rate 80%", "Export Value $500M/year"], "mandate_end_date": "2030-06-30", "exit_node_id": "node_park_operational"}
    },
    {
        "id": "proj_017",
        "name": "Dubai Hyperloop Test Track",
        "description": "10 km hyperloop test track for ultra-high-speed ground transportation technology validation.",
        "country": {"name": "United Arab Emirates", "a2": "AE", "a3": "ARE", "num": "784", "region": "Asia", "sub_region": "Western Asia", "affiliations": ["GCC", "Arab League"]},
        "sector": "transportation",
        "service_requirements": ["Innovation Zone Approval", "Safety Certification", "Technology Transfer Agreements"],
        "timeline": 36,
        "ops_requirements": [
            {"name": "Tube Construction", "category": "construction", "description": "Low-pressure tube infrastructure."},
            {"name": "Propulsion System", "category": "equipment", "description": "Magnetic levitation technology."},
            {"name": "Control Systems", "category": "technology", "description": "Automated control and safety systems."}
        ],
        "entry_criteria": {"pre_requisites": ["Ruler Decree", "Technology Partner Agreement"], "mobilization_time": 6, "entry_node_id": "node_technology_validation"},
        "success_criteria": {"success_metrics": ["Test Speed > 700 km/h", "Safety Tests Passed"], "mandate_end_date": "2029-12-31", "exit_node_id": "node_certification_complete"}
    },
    {
        "id": "proj_018",
        "name": "Karachi Wind Farm Phase 1",
        "description": "300 MW wind power generation facility in coastal Sindh province.",
        "country": {"name": "Pakistan", "a2": "PK", "a3": "PAK", "num": "586", "region": "Asia", "sub_region": "Southern Asia", "affiliations": ["SAARC"]},
        "sector": "energy",
        "service_requirements": ["Wind Resource Assessment", "Grid Connection Approval", "Land Lease Negotiation"],
        "timeline": 30,
        "ops_requirements": [
            {"name": "Wind Turbine Installation", "category": "equipment", "description": "Deploying 100 wind turbines."},
            {"name": "Substation Construction", "category": "construction", "description": "Electrical substation and controls."},
            {"name": "Access Roads", "category": "construction", "description": "Site access and maintenance roads."}
        ],
        "entry_criteria": {"pre_requisites": ["NEPRA License", "Power Purchase Agreement"], "mobilization_time": 8, "entry_node_id": "node_site_assessment"},
        "success_criteria": {"success_metrics": ["Capacity 300 MW", "Capacity Factor > 30%"], "mandate_end_date": "2028-12-31", "exit_node_id": "node_grid_connected"}
    },
    {
        "id": "proj_019",
        "name": "Singapore Deep Tunnel Sewerage Phase 3",
        "description": "Deep underground sewerage system expansion with advanced wastewater treatment and water reclamation.",
        "country": {"name": "Singapore", "a2": "SG", "a3": "SGP", "num": "702", "region": "Asia", "sub_region": "South-Eastern Asia", "affiliations": ["ASEAN"]},
        "sector": "water",
        "service_requirements": ["Underground Space Planning", "Water Quality Standards", "NEWater Integration"],
        "timeline": 84,
        "ops_requirements": [
            {"name": "Deep Tunnel Excavation", "category": "construction", "description": "TBM tunneling at 50m depth."},
            {"name": "Treatment Plant Construction", "category": "construction", "description": "Advanced membrane bioreactor plant."},
            {"name": "Pumping Stations", "category": "equipment", "description": "Deep lift pumping infrastructure."}
        ],
        "entry_criteria": {"pre_requisites": ["Parliamentary Approval", "PUB Contract Award"], "mobilization_time": 15, "entry_node_id": "node_engineering_design"},
        "success_criteria": {"success_metrics": ["Tunnel Length 40 km", "Treatment Capacity 800k m³/day"], "mandate_end_date": "2033-12-31", "exit_node_id": "node_system_operational"}
    }
]

def main():
    output_dir = Path("src/data/poc")
    output_dir.mkdir(parents=True, exist_ok=True)

    for project in PROJECTS:
        filename = f"project_{project['id'].split('_')[1]}.json"
        filepath = output_dir / filename

        with open(filepath, 'w') as f:
            json.dump(project, f, indent=4)

        print(f"✅ Created {filename}: {project['name']}")

    print(f"\n🎉 Generated {len(PROJECTS)} project files in {output_dir}")

if __name__ == "__main__":
    main()
