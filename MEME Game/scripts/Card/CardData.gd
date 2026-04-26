## For all action card definitions in the game.
##
## Holds the card name, colour and effect.
class_name CardData

## Dictionary of every card in the game. 
## The key is the card ID, the value is the card's name, colour, and list of effects.
##
## Each card data looks like this:
##     "card_id_here": {
##         "name": "Name",
##         "color": Color.GREEN,
##         "sub_effects": [ ... list of effects ... ]
##     }
##
## Effect "op" types (what the card does):
##   "add_v"           - Add villagers on valid tiles
##   "add_e"           - Add elephants on valid tiles
##   "add_v_in"        - Add villagers only on tiles of "in" type(s)
##   "remove_v"        - Remove villagers
##   "remove_e"        - Remove elephants
##   "move_e"          - Move elephants (player picks source then dest)
##   "move_v"          - Move villagers (player picks source then dest)
##   "move_all_e_to"   - Auto, Move all elephants within max_dist to a "to" tile type
##   "convert"         - Player clicks on valid tiles to change from one type to another
##   "convert_any_any" - Player clicks a tile, then picks what type to change it to
##   "immune"          - Makes elephants immune for one round
##
## Effect fields (all optional except "op"):
##   "count"     - how many pieces / tiles affected
##   "from"      - source tile types: "FOREST", "HUMAN", "PLANTATION", or "ANY"
##   "to"        - destination tile type
##   "in"        - for which tile type to spawn in
##   "max_dist"  - furthest grid distance for a move (-1 means no limit)
##   "condition" - optional extra rule
static var ALL_CARDS: Dictionary = {
	
	
	# ---- GREEN CARDS ----
	
	"green_abandonment_land": {
		"name": "Abandonment of Land",
		"color": Color.GREEN,
		"sub_effects": [
			{"op": "convert", "count": 2, "from": ["HUMAN"], "to": "FOREST"}
		]
	},
	"green_abandonment_oil_palm": {
		"name": "Abandonment of Oil Palm Areas",
		"color": Color.GREEN,
		"sub_effects": [
			{"op": "convert", "count": 2, "from": ["PLANTATION"], "to": "FOREST"}
		]
	},
	"green_alternative_livelihood": {
		"name": "Alternative Livelihood",
		"color": Color.GREEN,
		"sub_effects": [
			{"op": "add_v", "count": 2},
			{"op": "add_e", "count": 1}
		]
	},
	"green_artificial_salt_lick": {
		"name": "Artificial Salt Lick",
		"color": Color.GREEN,
		"sub_effects": [
			{"op": "add_v", "count": 2},
			{"op": "add_e", "count": 1}
		]
	},
	"green_biological_fences": {
		"name": "Biological Fences",
		"color": Color.GREEN,
		"sub_effects": [
			{"op": "immune"}
		]
	},
	"green_buffer_crops": {
		"name": "Buffer Crops",
		"color": Color.GREEN,
		"sub_effects": [
			{"op": "add_v", "count": 2},
			{"op": "move_e", "count": 1, "from": ["PLANTATION", "HUMAN"], "to": "ANY", "max_dist": 1}
		]
	},
	"green_cleared_boundaries": {
		"name": "Cleared Boundaries",
		"color": Color.GREEN,
		"sub_effects": [
			{"op": "immune"}
		]
	},
	"green_compensation": {
		"name": "Compensation",
		"color": Color.GREEN,
		"sub_effects": [
			{"op": "add_v", "count": 3}
		]
	},
	"green_crop_guarding": {
		"name": "Crop Guarding",
		"color": Color.GREEN,
		"sub_effects": [
			{"op": "move_e", "count": 2, "from": ["PLANTATION"], "to": "ANY", "max_dist": 1}
		]
	},
	"green_early_warning": {
		"name": "Early Warning System",
		"color": Color.GREEN,
		"sub_effects": [
			{"op": "immune"}
		]
	},
	"green_grow_elephant_food": {
		"name": "Grow Elephant Food in Habitat",
		"color": Color.GREEN,
		"sub_effects": [
			{"op": "add_v", "count": 2},
			{"op": "add_e", "count": 2},
			{"op": "move_e", "count": 1, "from": ["PLANTATION", "HUMAN"], "to": "FOREST", "max_dist": 1}
		]
	},
	"green_habitat_enrichment": {
		"name": "Habitat Enrichment",
		"color": Color.GREEN,
		"sub_effects": [
			{"op": "move_e", "count": 2, "from": ["PLANTATION", "HUMAN"], "to": "ANY", "max_dist": 1}
		]
	},
	"green_insurance": {
		"name": "Insurance",
		"color": Color.GREEN,
		"sub_effects": [
			{"op": "add_v", "count": 3}
		]
	},
	"green_land_use_planning": {
		"name": "Land-Use Planning",
		"color": Color.GREEN,
		"sub_effects": [
			{"op": "convert_any_any", "count": 2}
		]
	},
	"green_light_repellent": {
		"name": "Light Based Repellent",
		"color": Color.GREEN,
		"sub_effects": [
			{"op": "move_e", "count": 1, "from": ["PLANTATION", "HUMAN"], "to": "ANY", "max_dist": 1}
		]
	},
	"green_natural_salt_lick": {
		"name": "Natural Salt Lick",
		"color": Color.GREEN,
		"sub_effects": [
			{"op": "add_v", "count": 2},
			{"op": "move_e", "count": 1, "from": ["PLANTATION", "HUMAN"], "to": "ANY", "max_dist": 1}
		]
	},
	"green_organised_crop_protection": {
		"name": "Organized Crop Protection",
		"color": Color.GREEN,
		"sub_effects": [
			{"op": "move_e", "count": 2, "from": ["PLANTATION"], "to": "ANY", "max_dist": 1}
		]
	},
	"green_physical_barriers": {
		"name": "Physical Barriers",
		"color": Color.GREEN,
		"sub_effects": [
			{"op": "immune"}
		]
	},
	"green_protected_areas": {
		"name": "Protected Areas",
		"color": Color.GREEN,
		"sub_effects": [
			{"op": "add_e", "count": 1},
			{"op": "convert", "count": 1, "from": ["PLANTATION", "HUMAN"], "to": "FOREST",
			 "condition": "forest_lt_12"}
		]
	},
	"green_reforestation": {
		"name": "Reforestation",
		"color": Color.GREEN,
		"sub_effects": [
			{"op": "convert", "count": 2, "from": ["HUMAN", "PLANTATION"], "to": "FOREST"}
		]
	},
	"green_removal_subsidies": {
		"name": "Removal of Agricultural Subsidies",
		"color": Color.GREEN,
		"sub_effects": [
			{"op": "remove_v", "count": 2}
		]
	},
	"green_smell_repellents": {
		"name": "Smell-Based Repellents",
		"color": Color.GREEN,
		"sub_effects": [
			{"op": "move_e", "count": 1, "from": ["PLANTATION", "HUMAN"], "to": "ANY", "max_dist": 1}
		]
	},
	"green_sound_repellents": {
		"name": "Sound-Based Repellents",
		"color": Color.GREEN,
		"sub_effects": [
			{"op": "move_e", "count": 1, "from": ["PLANTATION", "HUMAN"], "to": "ANY", "max_dist": 1}
		]
	},
	"green_sustainability_practice": {
		"name": "Sustainability Practice",
		"color": Color.GREEN,
		"sub_effects": [
			{"op": "add_v", "count": 1},
			{"op": "add_e", "count": 1}
		]
	},
	"green_wildlife_corridor": {
		"name": "Wildlife Corridor",
		"color": Color.GREEN,
		"sub_effects": [
			{"op": "move_e", "count": 2, "from": ["PLANTATION", "HUMAN"], "to": "ANY", "max_dist": 1},
			{"op": "add_v", "count": 1}
		]
	},

	# ---- YELLOW CARDS ----

	"yellow_electric_fences": {
		"name": "Electric Fences",
		"color": Color.YELLOW,
		"sub_effects": [
			{"op": "remove_e", "count": 1},
			{"op": "move_e", "count": 2, "from": ["PLANTATION"], "to": "ANY", "max_dist": -1}
		]
	},
	"yellow_elephant_sanctuary": {
		"name": "Elephant Sanctuary",
		"color": Color.YELLOW,
		"sub_effects": [
			{"op": "add_v", "count": 2},
			{"op": "move_e", "count": 1, "from": ["ANY"], "to": "PLANTATION", "max_dist": -1}
		]
	},
	"yellow_improper_waste": {
		"name": "Improper Waste Management102",
		"color": Color.YELLOW,
		"sub_effects": [
			{"op": "move_e", "count": 2, "from": ["ANY"], "to": "HUMAN", "max_dist": 1}
		]
	},
	"yellow_labour_shift": {
		"name": "Labour Shift",
		"color": Color.YELLOW,
		"sub_effects": [
			{"op": "convert", "count": 1, "from": ["PLANTATION"], "to": "HUMAN"},
			{"op": "add_v_in", "count": 2, "in": ["HUMAN"]},
			{"op": "move_all_e_to", "to": ["PLANTATION"], "max_dist": 1}
		]
	},
	"yellow_poison": {
		"name": "Poison",
		"color": Color.YELLOW,
		"sub_effects": [
			{"op": "remove_v", "count": 1},
			{"op": "remove_e", "count": 1}
		]
	},
	"yellow_translocation": {
		"name": "Translocation",
		"color": Color.YELLOW,
		"sub_effects": [
			{"op": "move_e", "count": 1, "from": ["PLANTATION"], "to": "ANY", "max_dist": 1}
		]
	},

	# ---- RED CARDS ----

	"red_deforestation": {
		"name": "Deforestation",
		"color": Color.RED,
		"sub_effects": [
			{"op": "move_all_e_to", "to": ["HUMAN"], "max_dist": 1},
			{"op": "convert", "count": 2, "from": ["FOREST"], "to": "PLANTATION"}
		]
	},
	"red_development": {
		"name": "Development",
		"color": Color.RED,
		"sub_effects": [
			{"op": "add_v", "count": 2},
			{"op": "convert", "count": 2, "from": ["FOREST"], "to": "HUMAN"}
		]
	},
	"red_plantation_conversion": {
		"name": "Plantation Conversion",
		"color": Color.RED,
		"sub_effects": [
			{"op": "convert", "count": 1, "from": ["PLANTATION"], "to": "HUMAN"},
			{"op": "remove_e", "count": 1},
			{"op": "add_v_in", "count": 2, "in": ["HUMAN"]}
		]
	},
	"red_plantation_expansion": {
		"name": "Plantation Expansion",
		"color": Color.RED,
		"sub_effects": [
			{"op": "convert", "count": 2, "from": ["FOREST"], "to": "PLANTATION"}
		]
	},
	"red_poaching": {
		"name": "Poaching",
		"color": Color.RED,
		"sub_effects": [
			{"op": "remove_e", "count": 1},
			{"op": "move_all_e_to", "to": ["PLANTATION"], "max_dist": 3}
		]
	},
	"red_population_control": {
		"name": "Population Control",
		"color": Color.RED,
		"sub_effects": [
			{"op": "remove_e", "count": 3}
		]
	},
	"red_roadkill": {
		"name": "Roadkill",
		"color": Color.RED,
		"sub_effects": [
			{"op": "remove_v", "count": 1},
			{"op": "remove_e", "count": 1}
		]
	},
	"red_selling_land": {
		"name": "Selling Land to Industry",
		"color": Color.RED,
		"sub_effects": [
			{"op": "convert", "count": 3, "from": ["FOREST"], "to": "PLANTATION"}
		]
	},
	"red_urban_sprawl": {
		"name": "Urban Sprawl",
		"color": Color.RED,
		"sub_effects": [
			{"op": "convert", "count": 1, "from": ["PLANTATION"], "to": "HUMAN"},
			{"op": "add_v_in", "count": 2, "in": ["HUMAN"]}
		]
	},
	
	# -- Black --
	"black_corruption": {
		"name": "Corruption",
		"color": Color.BLACK,
		"sub_effects": [
			{"op": "steal"}
		]
	},
	
	"black_disagreement": {
		"name": "Disagreement",
		"color": Color.BLACK,
		"sub_effects": [
			{"op": "return_to_hand"}
		]
	},
	
	"black_diesease_strikes_elephants": {
		"name": "Disease Strike Elephants",
		"color": Color.BLACK,
		"sub_effects": [
			{"op": "remove_e", "count": 3},
		]
	},
	
	"black_diesease_strikes_human": {
		"name": "Disease Strike Human",
		"color": Color.BLACK,
		"sub_effects": [
			{"op": "remove_v", "count": 3},
		]
	},
	
	"black_drought": {
		"name": "Drought",
		"color": Color.BLACK,
		"sub_effects": [
			{"op": "move_all_e_to", "to": ["PLANTATION","HUMAN"], "max_dist": 2}
		]
	},
	
	"black_flood": {
		"name": "Flood",
		"color": Color.BLACK,
		"sub_effects": [
			{"op": "move_all_e_to", "to": ["PLANTATION","HUMAN"], "max_dist": 2}
		]
	},
	
	"black_forest_burning": {
		"name": "Forest Burning",
		"color": Color.BLACK,
		"sub_effects": [
			{"op": "move_all_e_to", "to": ["PLANTATION","HUMAN"], "max_dist": 2}
		]
	},
	
	"black_sabotaging": {
		"name": "Sabotaging",
		"color": Color.BLACK,
		"sub_effects": [
			{"op": "skip"}
		]
	},
	
	"black_wamring": {
		"name": "Warming",
		"color": Color.BLACK,
		"sub_effects": [
			{"op": "remove_v", "count": 1},
			{"op": "remove_e", "count": 1}
		]
	},
}
