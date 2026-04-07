class_name ScenarioData

# Tile types: 0=FOREST, 1=HUMAN (Village), 2=PLANTATION (Oil Palm)
# Row layouts use: F=FOREST, V=HUMAN, O=PLANTATION
# Grid is 8x8, indexed [row][col] where row 0 = top row (Row 1 in spec)

# Each scenario dict:
#   "name"           : String
#   "concept"        : String
#   "grid"           : Array[Array[int]] — 8 rows of 8 tile types
#   "elephants"      : Array[Vector2i]   — starting elephant positions (row, col) 0-indexed
#   "villagers_count": int               — number of villagers to place randomly on HUMAN tiles
#   "difficulty"     : Dictionary         — { "pro_elephant": String, "neutral": String, "pro_people": String }

# Single-letter aliases let the grid literals below stay readable as a map
const F = 0   # Forest
const V = 1   # Human / Village
const O = 2   # Plantation / Oil Palm

static var SCENARIOS: Array = [
	# --- Scenario 1: Balanced Landscape ---
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

	# --- Scenario 2: Fragmented Forest ---
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

	# --- Scenario 3: Forest Corridor ---
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

	# --- Scenario 4: Village Expansion ---
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

	# --- Scenario 5: Protected Forest Core ---
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

# --- Lookup helpers ---

# Returns null for "random" — caller should use the original flood-fill algorithm
# Out-of-range indices also return null so callers can fall back to random gen.
static func get_scenario(index: int):
	if index < 0 or index >= SCENARIOS.size():
		return null
	return SCENARIOS[index]

static func get_scenario_count() -> int:
	return SCENARIOS.size()
