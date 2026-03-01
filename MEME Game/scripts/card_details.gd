extends Node

enum CardID {
	ABANDONMENT_OF_LAND,
	ABANDONMENT_OF_OIL_PALM_AREAS,
	ALTERNATIVE_LIVELIHOOD,
	ARTIFICIAL_SALT_LICK,
	BIOLOGICAL_FENCES,
	BUFFER_CROPS,
	CLEARED_BOUNDARIES,
	COMPENSATION,
	CROP_GUARDING,
	EARLY_WARNING_SYSTEM,
	GROW_ELEPHANT_FOOD_IN_THEIR_HABITAT,
	HABITAT_ENRICHMENT,
	INSURANCE,
	LAND_USE_PLANNING,
	LIGHT_BASED_REPELLENT,
	NATURAL_SALT_LICK,
	ORGANIZED_CROP_PROTECTION,
	PHYSICAL_BARRIERS,
	PROTECTED_AREAS,
	REFORESTATION,
	REMOVAL_OF_AGRICULTURAL_SUBSIDIES,
	SMELL_BASED_REPELLENTS,
	SOUND_BASED_REPELLENTS,
	SUSTAINABILITY_PRACTICE,
	WILDLIFE_CORRIDOR,
	ELECTRIC_FENCES,
	ELEPHANT_SANCTUARY,
	IMPROPER_WASTE_MANAGEMENT,
	LABOUR_SHIFT,
	POISON,
	TRANSLOCATION,
	DEFORESTATION,
	DEVELOPMENT,
	PLANTATION_CONVERSION,
	PLANTATION_EXPANSION,
	POACHING,
	POPULATION_CONTROL,
	ROADKILL,
	SELLING_LAND_TO_INDUSTRY,
	URBAN_SPRAWL,
	CORRUPTION,
	DISAGREEMENT,
	DISEASE_STRIKE_ELEPHANTS,
	DISEASE_STRIKE_HUMANS,
	DROUGHT,
	FLOOD,
	FOREST_BURNING,
	OIL_PALM_BURNING,
	SABOTAGING,
	WARMING
}

const CARDS = {
	CardID.ABANDONMENT_OF_LAND: 
		{ "name": "Abandonment of Land", 				"stack": 1, "colour": "green" },
	CardID.ABANDONMENT_OF_OIL_PALM_AREAS: 
		{ "name": "Abandonment of Oil Palm Areas",		"stack": 1, "colour": "green" },
	CardID.ALTERNATIVE_LIVELIHOOD: 
		{ "name": "Alternative Livelihood", 			"stack": 1, "colour": "green" },
	CardID.ARTIFICIAL_SALT_LICK: 
		{ "name": "Artificial Salt Lick", 				"stack": 1, "colour": "green" },
	CardID.BIOLOGICAL_FENCES: 
		{ "name": "Biological Fences", 					"stack": 1, "colour": "green" },
	CardID.BUFFER_CROPS: 
		{ "name": "Buffer Crops", 						"stack": 1, "colour": "green" },
	CardID.CLEARED_BOUNDARIES: 
		{ "name": "Cleared Boundaries", 				"stack": 1, "colour": "green" },
	CardID.COMPENSATION: 
		{ "name": "Compensation", 						"stack": 1, "colour": "green" },
	CardID.CROP_GUARDING: 
		{ "name": "Crop Guarding", 						"stack": 1, "colour": "green", "icons": ["plantation", "move", "elephant", "elephant"] },
	CardID.EARLY_WARNING_SYSTEM: 
		{ "name": "Early Warning System", 				"stack": 1, "colour": "green" },
	CardID.GROW_ELEPHANT_FOOD_IN_THEIR_HABITAT: 
		{ "name": "Grow Elephant Food in their Habitat", "stack": 1, "colour": "green" },
	CardID.HABITAT_ENRICHMENT: 
		{ "name": "Habitat Enrichment", 				"stack": 1, "colour": "green" },
	CardID.INSURANCE: 
		{ "name": "Insurance", 							"stack": 1, "colour": "green" },
	CardID.LAND_USE_PLANNING: 
		{ "name": "Land-Use Planning", 					"stack": 2, "colour": "green" },
	CardID.LIGHT_BASED_REPELLENT: 
		{ "name": "Light Based Repellent", 				"stack": 1, "colour": "green" },
	CardID.NATURAL_SALT_LICK: 
		{ "name": "Natural Salt Lick", 					"stack": 1, "colour": "green" },
	CardID.ORGANIZED_CROP_PROTECTION: 
		{ "name": "Organized Crop Protection", 			"stack": 1, "colour": "green" },
	CardID.PHYSICAL_BARRIERS: 
		{ "name": "Physical Barriers", 					"stack": 1, "colour": "green" },
	CardID.PROTECTED_AREAS: 
		{ "name": "Protected Areas", 					"stack": 1, "colour": "green" },
	CardID.REFORESTATION: 
		{ "name": "Reforestation",						"stack": 3, "colour": "green"},
	CardID.REMOVAL_OF_AGRICULTURAL_SUBSIDIES: 
		{ "name": "Removal of Agricultural Subsidies", 	"stack": 2, "colour": "green" },
	CardID.SMELL_BASED_REPELLENTS: 
		{ "name": "Smell-Based Repellents", 			"stack": 1, "colour": "green" },
	CardID.SOUND_BASED_REPELLENTS: 
		{ "name": "Sound-Based Repellents", 			"stack": 1, "colour": "green" },
	CardID.SUSTAINABILITY_PRACTICE: 
		{ "name": "Sustainability Practice", 			"stack": 3, "colour": "green" },
	CardID.WILDLIFE_CORRIDOR: 
		{ "name": "Wildlife Corridor", 					"stack": 1, "colour": "green" },
		
	CardID.ELECTRIC_FENCES: 
		{ "name": "Electric Fences",					"stack": 3, "colour": "yellow" },
	CardID.ELEPHANT_SANCTUARY: 
		{ "name": "Elephant Sanctuary", 				"stack": 3, "colour": "yellow" },
	CardID.IMPROPER_WASTE_MANAGEMENT: 
		{ "name": "Improper Waste Management", 			"stack": 2, "colour": "yellow" },
	CardID.LABOUR_SHIFT: 
		{ "name": "Labour Shift", 						"stack": 1, "colour": "yellow" },
	CardID.POISON: 
		{ "name": "Poison", 							"stack": 2, "colour": "yellow" },
	CardID.TRANSLOCATION: 
		{ "name": "Translocation", 						"stack": 2, "colour": "yellow" },
		
	CardID.DEFORESTATION: 
		{ "name": "Deforestation", 						"stack": 2, "colour": "red" },
	CardID.DEVELOPMENT: 
		{ "name": "Development", 						"stack": 3, "colour": "red" },
	CardID.PLANTATION_CONVERSION: 
		{ "name": "Plantation Conversion", 				"stack": 1, "colour": "red" },
	CardID.PLANTATION_EXPANSION: 
		{ "name": "Plantation Expansion", 				"stack": 1, "colour": "red" },
	CardID.POACHING: 
		{ "name": "Poaching", 							"stack": 2, "colour": "red" },
	CardID.POPULATION_CONTROL: 
		{ "name": "Population Control", 				"stack": 1, "colour": "red" },
	CardID.ROADKILL: 
		{ "name": "Roadkill", 							"stack": 1, "colour": "red" },
	CardID.SELLING_LAND_TO_INDUSTRY: 
		{ "name": "Selling Land to Industry", 			"stack": 2, "colour": "red" },
	CardID.URBAN_SPRAWL: 
		{ "name": "Urban Sprawl", 						"stack": 2, "colour": "red" },
		
	CardID.CORRUPTION: 
		{ "name": "Corruption", 						"stack": 1, "colour": "black" },
	CardID.DISAGREEMENT: 
		{ "name": "Disagreement", 						"stack": 1, "colour": "black" },
	CardID.DISEASE_STRIKE_ELEPHANTS: 
		{ "name": "Disease Strike Elephants", 			"stack": 1, "colour": "black" },
	CardID.DISEASE_STRIKE_HUMANS: 
		{ "name": "Disease Strike Humans", 				"stack": 1, "colour": "black" },
	CardID.DROUGHT: 
		{ "name": "Drought", 							"stack": 1, "colour": "black" },
	CardID.FLOOD: 
		{ "name": "Flood", 								"stack": 1, "colour": "black" },
	CardID.FOREST_BURNING: {
		 "name": "Forest Burning", 						"stack": 1, "colour": "black" },
	CardID.OIL_PALM_BURNING: 
		{ "name": "Oil Palm Burning", 					"stack": 1, "colour": "black" },
	CardID.SABOTAGING: 
		{ "name": "Sabotaging", 						"stack": 1, "colour": "black" },
	CardID.WARMING: 
		{ "name": "Warming", 							"stack": 1, "colour": "black" }
}
