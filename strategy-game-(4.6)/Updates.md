# MEME Game — Update Log

## Core Game Loop Implementation

### New Files

| File | Purpose |
|------|---------|
| `scripts/GameState.gd` | Global singleton — tracks all tiles, pieces, deck, and whose turn it is |
| `scripts/CardData.gd` | All card definitions (24 Green + 6 Yellow) with names, colours, and effects |
| `scripts/CardEffects.gd` | Executes card effects one by one; handles player interaction for placing/removing/converting tiles |

### Modified Files

| File | What changed |
|------|-------------|
| `project.godot` | Registered `GameState` as an AutoLoad singleton |
| `scripts/Board.gd` | 8×8 board (was 10×10); tiles are now clustered into contiguous regions using a seed-based flood-fill growth algorithm — one large Forest blob, one Human blob, one Plantation blob; quotas: Forest=26, Human=19, Plantation=19; tile highlights now use `free()` instead of `queue_free()` so clear+redraw happens atomically in the same frame |
| `scripts/Card.gd` | Cards now display real names and colours pulled from `CardData` |
| `scripts/Pieces/elephant.gd` + `meeple.gd` | Each piece now stores which tile it's sitting on (`tile_key`) |
| `scripts/Card Table/card_functions.gd` | Piece spawning now registers pieces with `GameState` so the board tracks occupancy |
| `scripts/Card Table/card_table.gd` | Wires everything together — initialises game state, deals cards, places starting pieces, routes tile clicks to card effects |
| `scripts/Card Table/card_table_ui.gd` | Hand is now drawn from a real shuffled deck; UI updates per turn; instruction prompt is now a large gold-text banner with a dark pill background anchored top-centre |

---

### What Currently Works

- 8×8 clustered board with 3 contiguous tile regions (Forest, Human, Plantation)
- Shuffled deck dealt to all players (5 cards each); replacement card drawn after each play
- Playing a card triggers its effect, then the player clicks End Turn
- **Add piece cards** — player clicks highlighted tiles (cyan); highlights stay continuous across all placements with no flash; count enforced correctly
- **Remove piece cards** — player clicks highlighted tiles (red); same continuous highlight behaviour
- **Convert cards** — player clicks highlighted tiles (green) to convert them to the target type; count enforced correctly (e.g. exactly 2 for Reforestation); instruction banner shows remaining count
  - Working: Abandonment of Land, Abandonment of Oil Palm Areas, Reforestation, Protected Areas (forest < 12 condition)
- **Land-Use Planning** (`convert_any_any`) — player clicks highlighted tiles (orange) to cycle Forest→Human→Plantation→Forest; count enforced correctly
- Starting board state: 3 elephants on forest tiles, 6 villagers on human/plantation tiles
- Cards display real names and colours (black font for readability)
- Card hand re-centres correctly on turn change and window resize
- Instruction banner is large, clearly visible, and dismisses automatically when effect completes

---

### What Is Skipped / Not Yet Done

- **Move card effects** — all move ops (`move_e`, `move_v`, `move_all_e_to`) are skipped with a log message. The CSV has been updated (`Card Conditions Updated.csv`) and the new move model uses **"Away from"** and **"Towards"** columns instead of from/to — this needs new ops in `CardData.gd` and `CardEffects.gd` before implementing
- **Immune card effects** — skipped with log message; immune means elephants are protected from cards that move them towards Plantation/Human for 1 round — needs a turn-based status flag system
- **Red cards** — not yet added to `CardData.gd` (Deforestation, Development, Plantation Conversion, Plantation Expansion, Poaching, Population Control, Roadkill, Selling Land to Industry, Urban Sprawl)
- **Black cards** — not yet added to `CardData.gd` (Corruption, Disagreement, Disease Strike, Drought, Flood, Forest Burning, Oil Palm Burning, Sabotaging, Warming); also need "draw and play immediately" logic in turn structure
- **CardData.gd Green/Yellow cards** — several cards still use old move model and need updating to match `Card Conditions Updated.csv` (Reforestation source changed to Human Dominated, Wildlife Corridor, Sustainability Practice, all repellent cards, Electric Fences, Elephant Sanctuary, Improper Waste Management, Translocation)
- Win/loss conditions
- AI players
- Turn structure: draw 1 at turn start, discard-1-draw-2 mechanic, hand limit of 5 enforced

---

## Move Ops, Red Cards, and Card Data Corrections

### Modified Files

| File | What changed |
|------|-------------|
| `scripts/CardEffects.gd` | `move_e`, `move_v`, and `move_all_e_to` are now fully wired; removed from the skip branch and dispatched to `_begin_move` / `_do_move_all_e_auto` respectively |
| `scripts/CardData.gd` | All Green/Yellow cards corrected to match `Card Conditions Updated.csv` (see below); all 9 Red cards added |
| `scripts/GameState.gd` | `build_deck()` now includes Red cards (`Color.RED`) in addition to Green/Yellow |

### Green Card Corrections (vs. old data)

| Card | Change |
|------|--------|
| Grow Elephant Food in Habitat | Sub-effect was `move_v` (wrong) — fixed to `move_e count:1 from:PLANTATION/HUMAN to:FOREST max_dist:1` |
| Reforestation | Source tile was `PLANTATION` — corrected to `HUMAN` per CSV |
| Sustainability Practice | Was `add_v 1 + move_e 2` — corrected to `add_v 1 + add_e 1` per CSV |
| Wildlife Corridor | Was `add_v 1 + add_e 1` — corrected to `move_e 2 from:PLANTATION/HUMAN away, max_dist:1 + add_v 1` per CSV |

### Yellow Card Corrections

| Card | Change |
|------|--------|
| Electric Fences | `move_e` count corrected from 1 → 2 per CSV |
| Improper Waste Management | Direction reversed: was `from:HUMAN to:ANY` — corrected to `from:ANY to:HUMAN` (elephants move *towards* Human tiles) |
| Translocation | Was `move_v` (wrong) — corrected to `move_e count:1 from:PLANTATION, max_dist:1` per CSV |

### Red Cards Added

| Card ID | Effects |
|---------|---------|
| `red_deforestation` | Auto-move all elephants → Human (dist 1); convert 2 Forest → Plantation |
| `red_development` | Add 2 villagers; convert 2 Forest → Human |
| `red_plantation_conversion` | Convert 1 Plantation → Human; remove 1 elephant; add 2 villagers on Human tiles |
| `red_plantation_expansion` | Convert 2 Forest → Plantation |
| `red_poaching` | Remove 1 elephant; auto-move all elephants → Plantation (dist 3) |
| `red_population_control` | Remove 3 elephants |
| `red_roadkill` | Remove 1 villager + 1 elephant |
| `red_selling_land` | Convert 3 Forest → Plantation |
| `red_urban_sprawl` | Convert 1 Plantation → Human; add 2 villagers on Human tiles |

---

### What Currently Works

- 8×8 clustered board with 3 contiguous tile regions (Forest, Human, Plantation)
- Shuffled deck dealt to all players (5 cards each); replacement card drawn after each play; deck now includes Green + Yellow + Red cards
- Playing a card triggers its effect, then the player clicks End Turn
- **Add piece cards** — player clicks highlighted tiles (cyan); highlights stay continuous across all placements
- **Remove piece cards** — player clicks highlighted tiles (red)
- **Convert cards** — player clicks highlighted tiles (green) to convert them; count enforced correctly
  - Working: Abandonment of Land, Abandonment of Oil Palm Areas, Reforestation (from Human), Protected Areas (forest < 12 condition), Development, Plantation Expansion, Selling Land to Industry, Urban Sprawl, Plantation Conversion, Red Deforestation (convert part)
- **Land-Use Planning** (`convert_any_any`) — player cycles tile types (orange); count enforced
- **Move piece cards** — `move_e` and `move_v` now fully interactive: player picks source tile (yellow highlight), then destination tile (blue highlight); max_dist enforced; from/to type filters enforced
  - Working: Buffer Crops, Crop Guarding, Grow Elephant Food, Habitat Enrichment, Light/Smell/Sound Repellents, Natural Salt Lick, Organised Crop Protection, Sustainability Practice (now add only), Wildlife Corridor, Electric Fences, Elephant Sanctuary, Improper Waste Management, Translocation
- **Auto-move all elephants** (`move_all_e_to`) — moves every elephant toward target type within max_dist automatically
  - Working: Labour Shift, Deforestation (auto-move part), Poaching (auto-move part)
- Starting board state: 3 elephants on forest tiles, 6 villagers on human/plantation tiles
- Cards display real names and colours (black font); red cards display with red background
- Card hand re-centres correctly on turn change and window resize
- Instruction banner is large, clearly visible, and dismisses automatically

---

### What Is Skipped / Not Yet Done

- **Immune card effects** — still skipped; immune means elephants are protected from cards that move them toward Plantation/Human for 1 round — needs a turn-based status flag system
- **Black cards** — not yet added to `CardData.gd` (Corruption, Disagreement, Disease Strike ×2, Drought, Flood, Forest Burning, Oil Palm Burning, Sabotaging, Warming); also need "draw and play immediately" logic
- **Plantation Conversion / Urban Sprawl — "newly converted tiles"** — currently adds villagers on *any* Human tile rather than specifically the just-converted tile; needs a `_last_converted_key` tracker in `CardEffects`
- Win/loss conditions
- AI players
- Turn structure: draw 1 at turn start, discard-1-draw-2 mechanic, hand limit of 5 enforced

---

---

## Camera — 4-Side Snap Rotation

### Modified Files

| File | What changed |
|------|-------------|
| `scripts/CameraControls.gd` | Added Q/E snap-rotate; `_snap_rotate()` helper snaps yaw to nearest 90° multiple then steps by 90° |

### What was added

- **Q** — rotate camera 90° counter-clockwise (left side of board)
- **E** — rotate camera 90° clockwise (right side of board)
- Snaps cleanly from any free-orbit position to the nearest cardinal angle before stepping, so Q/E always lands on a true 90° boundary
- Scroll-wheel zoom and right-click free-orbit are unchanged

---

### To-do list

1. **Immune status system** — add a per-elephant flag `is_immune: bool`; set it on immune cards; check it before executing any move op that targets PLANTATION/HUMAN; clear at end of each full round
2. **Black cards** — add card definitions; implement "draw and play immediately" in `card_table_ui.gd`/`card_table.gd`; special ops: `steal_card`, `skip_turn`, `return_last_played`
3. **Plantation Conversion / Urban Sprawl fix** — track `_last_converted_key` in CardEffects and use it for the follow-on `add_v` op
4. **Turn structure** — enforce hand limit 5, draw 1 at turn start, discard-1-draw-2 option

---

## Scenario Selection Screen

### New Files

| File | Purpose |
|------|---------|
| `scripts/ScenarioData.gd` | Static class holding all 5 preset scenario definitions — 8×8 grid layouts (Forest/Human/Plantation), elephant start positions, villager counts, and role difficulty ratings per interest group |
| `scripts/ScenarioSelect.gd` | Full UI screen — 6 clickable cards (5 presets + Random), a colour-coded 8×8 map preview drawn on click, concept text, tile/piece stats, per-role-group difficulty breakdown, and a legend |
| `scenes/ScenarioSelect.tscn` | Scene file for the scenario selection screen |

### Modified Files

| File | What changed |
|------|-------------|
| `scripts/GameState.gd` | Added `selected_scenario_index: int` variable (-1 = unset, 0–4 = preset, 5 = random) |
| `scripts/Board.gd` | `generate_board()` now reads `GameState.selected_scenario_index`; uses `_type_map_from_scenario()` for presets, falls back to flood-fill for Random/unset |
| `scripts/Card Table/card_table.gd` | `_spawn_initial_pieces()` now places elephants at exact scenario positions and fills villagers onto Human tiles for presets; uses original random logic for the Random option |
| `scripts/MainMenu/Buttons/start_button.gd` | Now routes to `ScenarioSelect.tscn` instead of directly to `RoleSelection.tscn` |

### Scene flow

**MainMenu → ScenarioSelect → RoleSelection → CardTable**

### The 5 preset scenarios

| # | Name | Forest | Human | Plantation | Elephants | Villagers | Pro-Elephant | Neutral | Pro-People |
|---|------|--------|-------|------------|-----------|-----------|--------------|---------|------------|
| 1 | Balanced Landscape | 42 | 10 | 12 | 3 | 10 | Easy | Moderate | Moderate–Hard |
| 2 | Fragmented Forest | 12 | 9 | 43 | 4 | 9 | Hard | Moderate | Easy |
| 3 | Forest Corridor | 20 | 4 | 40 | 4 | 8 | Moderate | Moderate | Moderate |
| 4 | Village Expansion | 16 | 12 | 36 | 3 | 12 | Hard | Hard | Easy |
| 5 | Protected Forest Core | 36 | 4 | 24 | 4 | 6 | Easy | Easy–Moderate | Hard |
| 6 | Random Map | 26 | 19 | 19 | 3 | 6 | Varies | Varies | Varies |

### What was added

- Clicking a scenario card shows the large colour-coded 8×8 map preview (Forest = green, Village = tan, Oil Palm = brown) with grey markers for elephant start positions
- Detail panel shows scenario name, concept description, tile/piece counts, and difficulty per role group (Pro-Elephant / Neutral / Pro-People)
- "Continue to Role Selection" button only activates after a scenario is selected
- Random option retains the original flood-fill algorithm with fixed 26/19/19 quotas and random starting piece placement

