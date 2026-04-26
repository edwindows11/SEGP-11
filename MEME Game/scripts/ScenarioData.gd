## Each scenario is a fixed 8x8 map with a specific tile layout, elephant start positions and villager count. 
class_name ScenarioData

## Tile type code for a forest tile.
const F = 0
## Tile type code for a village tile.
const V = 1
## Tile type code for a plantation tile.
const O = 2

## List of all scenarios in the game. Each entry is a Dictionary:
##   "id"              : unique identifier
##   "name"            : display name
##   "concept"         : short description shown on the select screen
##   "grid"            : 8 tile-type ints (F / V / O)
##   "elephants"       : starting elephant positions (row, col)
##   "villagers_count" : villagers placed randomly on HUMAN tiles
##   "difficulty"      : Dictionary with keys "pro_elephant", "neutral", "pro_people"
static var SCENARIOS: Array = [
	# Scenario 1: Balanced Landscape
	{
		"id": "balanced_landscape",
		"name": "Balanced Landscape",
		"concept": "Mixed landscape with moderate connectivity. A large forest area offers room for elephants, while oil palm and villages create moderate conflict zones.",
		"grid": [
			[F, F, O, O, O, F, F, F],
			[F, F, O, V, O, F, F, F],
			[F, O, O, O, O, O, F, F],
			[F, O, V, O, O, O, F, F],
			[F, F, O, O, O, O, F, F],
			[F, F, F, O, V, F, F, F],
			[F, F, F, F, F, F, F, F],
			[F, F, F, F, F, F, F, F],
		],
		"elephants": [Vector2i(6, 2), Vector2i(5, 5), Vector2i(2, 0)],
		"villagers_count": 10,
		"difficulty": {
			"pro_elephant": "Easy",
			"neutral": "Moderate",
			"pro_people": "Moderate–Hard",
		},
	},

	# Scenario 2: Fragmented Forest 
	{
		"id": "fragmented_forest",
		"name": "Fragmented Forest",
		"concept": "Oil palm dominates and forest patches are isolated. Elephants must navigate through plantation to survive. Ideal for pro-people strategies.",
		"grid": [
			[F, O, O, O, O, O, O, F],
			[O, O, V, O, O, V, O, O],
			[O, F, F, O, O, F, F, O],
			[O, O, O, V, O, O, O, O],
			[O, F, F, O, O, O, F, F],
			[O, O, V, O, O, V, O, O],
			[F, O, O, O, O, O, O, F],
			[F, F, O, O, O, O, F, F],
		],
		"elephants": [Vector2i(0, 0), Vector2i(2, 1), Vector2i(4, 1), Vector2i(7, 6)],
		"villagers_count": 9,
		"difficulty": {
			"pro_elephant": "Hard",
			"neutral": "Moderate",
			"pro_people": "Easy",
		},
	},

	# Scenario 3: Forest Corridor 
	{
		"id": "forest_corridor",
		"name": "Forest Corridor",
		"concept": "A narrow corridor connects two forest blocks. Protecting it is crucial for elephant movement. Losing the corridor fragments the habitat.",
		"grid": [
			[O, O, F, F, F, O, O, O],
			[O, O, F, F, F, O, O, V],
			[O, O, F, O, F, O, O, V],
			[O, O, F, O, F, O, O, O],
			[O, O, F, O, F, O, O, O],
			[O, O, F, F, F, O, O, O],
			[O, O, F, F, F, O, O, V],
			[O, O, O, O, O, O, O, V],
		],
		"elephants": [Vector2i(0, 3), Vector2i(2, 2), Vector2i(5, 3), Vector2i(6, 4)],
		"villagers_count": 8,
		"difficulty": {
			"pro_elephant": "Moderate",
			"neutral": "Moderate",
			"pro_people": "Moderate",
		},
	},

	# Scenario 4: Village Expansion 
	{
		"id": "village_expansion",
		"name": "Village Expansion",
		"concept": "Human settlements dominate the edges while elephants are confined to a small central forest. Villages press inward from all sides.",
		"grid": [
			[V, V, O, O, O, V, V, V],
			[V, O, O, O, O, O, O, V],
			[O, O, F, F, F, O, O, O],
			[O, F, F, F, F, F, O, O],
			[O, F, F, F, F, F, O, O],
			[O, O, F, F, F, O, O, O],
			[V, O, O, O, O, O, O, V],
			[V, V, O, O, O, V, V, V],
		],
		"elephants": [Vector2i(3, 3), Vector2i(4, 4), Vector2i(2, 3)],
		"villagers_count": 12,
		"difficulty": {
			"pro_elephant": "Hard",
			"neutral": "Hard",
			"pro_people": "Easy",
		},
	},

	# Scenario 5: Protected Forest Core 
	{
		"id": "protected_forest_core",
		"name": "Protected Forest Core",
		"concept": "A large central forest is surrounded by plantations and scattered villages. Elephants thrive inside the core but expansion is limited.",
		"grid": [
			[O, O, O, O, O, O, V, V],
			[O, F, F, F, F, F, F, O],
			[O, F, F, F, F, F, F, O],
			[O, F, F, F, F, F, F, O],
			[O, F, F, F, F, F, F, O],
			[O, F, F, F, F, F, F, O],
			[O, F, F, F, F, F, F, O],
			[O, O, O, V, V, O, O, O],
		],
		"elephants": [Vector2i(2, 3), Vector2i(3, 2), Vector2i(4, 4), Vector2i(5, 3)],
		"villagers_count": 6,
		"difficulty": {
			"pro_elephant": "Easy",
			"neutral": "Easy–Moderate",
			"pro_people": "Hard",
		},
	},
]

## Returns the scenario at the given index, or null if the index is out of range. 
## Out-of-range = "random": The board is built using the random flood-fill algorithm.
static func get_scenario(index: int):
	if index < 0 or index >= SCENARIOS.size():
		return null
	return SCENARIOS[index]

## Returns how many preset scenarios exist.
static func get_scenario_count() -> int:
	return SCENARIOS.size()
