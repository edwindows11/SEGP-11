## Keeps every role's name, description,
## special ability, max cards per turn, and win condition. [card_table_ui.gd]
## and [bot.gd] ask this script rather than checking role names themselves,
## so adding or changing a role only needs updates here.
extends Node

## Role name identifiers. Used as string keys everywhere else in the game.

const CONSERVATIONIST       := "Conservationist"
const ECOTOURISM_MANAGER    := "Ecotourism Manager"
const ENVIRONMENTAL_CONSULT := "Environmental Consultant"
const GOVERNMENT            := "Government"
const LAND_DEVELOPER        := "Land Developer"
const PLANTATION_OWNER      := "Plantation Owner"
const RESEARCHER            := "Researcher"
const VILLAGE_HEAD          := "Village Head"
const WILDLIFE_DEPARTMENT   := "Wildlife Department"

## List of all 9 roles.
const ALL_ROLES := [
	CONSERVATIONIST,
	ECOTOURISM_MANAGER,
	ENVIRONMENTAL_CONSULT,
	GOVERNMENT,
	LAND_DEVELOPER,
	PLANTATION_OWNER,
	RESEARCHER,
	VILLAGE_HEAD,
	WILDLIFE_DEPARTMENT,
]

## Roles whose ability needs a "Special Ability" button click to trigger.
## Wildlife Department and Researcher are passive (handled automatically);
## Village Head is here because activating its 2-card mode is optional.
const BUTTON_ROLES := [
	CONSERVATIONIST,
	PLANTATION_OWNER,
	GOVERNMENT,
	LAND_DEVELOPER,
	ENVIRONMENTAL_CONSULT,
	ECOTOURISM_MANAGER,
	VILLAGE_HEAD,
]

## Short description of each role's ability, shown in tooltips and popups.
const DESCRIPTIONS := {
	CONSERVATIONIST:       "Expand a forest tile adjacent to a forested tile that contains an elephant.",
	ECOTOURISM_MANAGER:    "After playing a piece-increasing action, take one extra move.",
	ENVIRONMENTAL_CONSULT: "Borrow another role's special ability for the game.",
	GOVERNMENT:            "Steal a coloured (green/yellow/red) card played by another player.",
	LAND_DEVELOPER:        "Convert a non-human tile that has 3+ human-dominated neighbours into a human zone.",
	PLANTATION_OWNER:      "Reverse the last card played by a chosen opponent (adds become removes).",
	RESEARCHER:            "Passive: move elephants equal to the action card's add_e effect.",
	VILLAGE_HEAD:          "Activate to play a 2nd coloured card this turn (only 1 can increase villagers).",
	WILDLIFE_DEPARTMENT:   "At turn start, draw 2 bonus cards then discard 1.",
}

## Checks whether a string is a known role name.
func is_valid_role(role: String) -> bool:
	return role in ALL_ROLES

## Returns true if the role's ability is triggered by the special-ability button.
func has_button_ability(role: String) -> bool:
	return role in BUTTON_ROLES

## Looks up the short ability description for a role. Returns "" if unknown.
func description_for(role: String) -> String:
	return DESCRIPTIONS.get(role, "")

## Returns the role whose ability the player effectively has. Usually just
## their own role, but Environmental Consultant reports the role they borrowed.
func effective_role(player_index: int) -> String:
	if player_index < 0 or player_index >= GameState.player_roles.size():
		return ""
	var role: String = GameState.player_roles[player_index]
	if role == ENVIRONMENTAL_CONSULT and GameState.ec_borrowed_ability != "":
		return GameState.ec_borrowed_ability
	return role

## Returns true if the given role has already used its once-per-turn ability
## this turn. Reads per-role flags stored on the UI node.
func ability_used_this_turn(role: String, ui_node: Node) -> bool:
	match role:
		PLANTATION_OWNER:   return ui_node.get("cards_played_this_turn") != 0
		GOVERNMENT:         return bool(ui_node.get("gov_used_ability_this_turn"))
		CONSERVATIONIST:    return bool(ui_node.get("cons_used_ability_this_turn"))
		LAND_DEVELOPER:     return bool(ui_node.get("ld_used_ability_this_turn"))
		ECOTOURISM_MANAGER: return bool(ui_node.get("em_used_ability_this_turn"))
		VILLAGE_HEAD:       return bool(ui_node.get("vh_used_ability_this_turn"))
		_:                  return false

## Returns true if the Special Ability button should be enabled right now.
## False for passive roles, and false if the ability was already used this turn.
func can_use_button(role: String, ui_node: Node) -> bool:
	if not has_button_ability(role):
		return false
	return not ability_used_this_turn(role, ui_node)

## Runs the right CardEffects call for the role's ability. Resolves the
## borrowed ability for Environmental Consultant.
func trigger_special_ability(role: String, ui_node: Node, card_effects: Node, target_index: int = -1) -> void:
	var resolved := role
	if role == ENVIRONMENTAL_CONSULT:
		resolved = GameState.ec_borrowed_ability
		if resolved == "":
			ui_node.show_instruction("Pick an ability to borrow first!")
			return

	match resolved:
		PLANTATION_OWNER:
			card_effects.execute_reversed_card(target_index, ui_node)
		GOVERNMENT:
			card_effects.execute_government_ability(ui_node)
		CONSERVATIONIST:
			card_effects.execute_conservationist_ability(ui_node)
		LAND_DEVELOPER:
			card_effects.execute_land_developer_ability(ui_node)
		ECOTOURISM_MANAGER:
			card_effects.execute_em_ability(ui_node)
		_:
			ui_node.show_instruction("This role has no on-demand ability.")

## Runs at the start of a player's turn. Triggers Wildlife Department's
## passive bonus-card draw. Other passive roles hook in here too if needed.
func on_turn_start(player_index: int) -> void:
	var role := effective_role(player_index)
	if role == WILDLIFE_DEPARTMENT:
		GameState.wildlife_dept_draw_bonus(player_index)

## Discards the chosen Wildlife Department bonus card.
func wildlife_discard(player_index: int, card_id: String) -> void:
	GameState.wildlife_dept_discard_bonus(player_index, card_id)

## Returns how many cards this player can play per turn. Normally 1, but
## Village Head gets 2 after pressing its Special Ability button.
## Pass `ui_node` to check the vh-activated flag; without it, assume 1.
func max_cards_per_turn(role: String, ui_node: Node = null) -> int:
	var is_vh := (role == VILLAGE_HEAD) or (role == ENVIRONMENTAL_CONSULT and GameState.ec_borrowed_ability == VILLAGE_HEAD)
	if is_vh and ui_node != null and bool(ui_node.get("vh_used_ability_this_turn")):
		return 2
	return 1

## Title and colour shown on each role's goal tracker panel in the UI.
const GOAL_DISPLAY := {
	CONSERVATIONIST:       { "title": "Conservationist Goal",   "color": Color(0.6, 1.0, 0.6) },
	VILLAGE_HEAD:          { "title": "Village Head Goal",      "color": Color(1.0, 0.6, 0.6) },
	PLANTATION_OWNER:      { "title": "Plantation Owner Goal",  "color": Color(1.0, 0.8, 0.4) },
	LAND_DEVELOPER:        { "title": "Land Developer Goal",    "color": Color(0.6, 0.8, 1.0) },
	ENVIRONMENTAL_CONSULT: { "title": "Env Consultant Goal",    "color": Color(0.6, 1.0, 0.6) },
	ECOTOURISM_MANAGER:    { "title": "Ecotourism Manager Goal","color": Color(0.4, 0.9, 0.9) },
	WILDLIFE_DEPARTMENT:   { "title": "Wildlife Dept Goal",     "color": Color(1.0, 0.5, 0.2) },
	RESEARCHER:            { "title": "Researcher Goal",        "color": Color(0.8, 0.5, 1.0) },
	GOVERNMENT:            { "title": "Government Goal",        "color": Color(0.6, 0.85, 1.0) },
}

## Returns the title text for a role's goal panel.
func goal_title(role: String) -> String:
	return GOAL_DISPLAY.get(role, {}).get("title", role + " Goal")

## Returns the colour used on a role's goal panel.
func goal_color(role: String) -> Color:
	return GOAL_DISPLAY.get(role, {}).get("color", Color(1.0, 0.8, 0.2))

## Builds the current goal-tracker data for a player. Returns a dictionary
## with display strings and a `won` flag. Used by card_table_ui to render
## every role's goal panel from a single template. The `won` flag is polled
## every 0.2 s to detect a winning player.
##
## Returned keys:
##   title : String - panel title (e.g. "Conservationist Goal")
##   color : Color  - panel highlight colour
##   line1 : String - first line of progress text
##   line2 : String - second line of progress text
##   won   : bool   - true if this player's win condition is fully met
func compute_goal(player_index: int) -> Dictionary:
	if player_index < 0 or player_index >= GameState.player_roles.size():
		return {}
	var role: String = GameState.player_roles[player_index]
	var stats: Dictionary = GameState.player_stats[player_index]
	var out := {
		"title": goal_title(role),
		"color": goal_color(role),
		"line1": "",
		"line2": "",
		"won": false,
	}

	match role:
		CONSERVATIONIST:
			var g: int = stats.get("green_cards_played", 0)
			var f: int = GameState.get_forest_increase()
			out.line1 = "Green Cards: %d / 4" % g
			out.line2 = "Forest Increase: %d / 2" % f
			out.won = g >= 4 and f >= 2

		VILLAGE_HEAD:
			var a: int = stats.get("action_cards_played", 0)
			var p: int = GameState.get_total_villagers()
			out.line1 = "Action Cards: %d / 7" % a
			out.line2 = "Population: %d / 16" % p
			out.won = a >= 7 and p >= 16

		PLANTATION_OWNER:
			var g: int = stats.get("green_cards_played", 0)
			var r: int = stats.get("red_cards_played", 0)
			var y: int = stats.get("yellow_cards_played", 0)
			var p: int = GameState.get_plantation_increase()
			out.line1 = "Cards: %dG, %dR, %dY / 2G, 1R, 1Y" % [g, r, y]
			out.line2 = "Plantations: %d / 2" % p
			out.won = g >= 2 and r >= 1 and y >= 1 and p >= 2

		LAND_DEVELOPER:
			var g: int = stats.get("green_cards_played", 0)
			var r: int = stats.get("red_cards_played", 0)
			var y: int = stats.get("yellow_cards_played", 0)
			var h: int = GameState.get_human_increase()
			out.line1 = "Cards: %dG, %dR, %dY / (2G+2R) or (2Y+2R)" % [g, r, y]
			out.line2 = "Human Areas: %d / 2" % h
			out.won = ((g >= 2 and r >= 2) or (y >= 2 and r >= 2)) and h >= 2

		ENVIRONMENTAL_CONSULT:
			var g: int = stats.get("green_cards_played", 0)
			var r: int = stats.get("red_cards_played", 0)
			var v: int = GameState.count_vacant_secondary_met()
			out.line1 = "Cards: %dG, %dR / 2G, 2R" % [g, r]
			out.line2 = "Vacant Goals Met: %d / 2" % v
			out.won = g >= 2 and r >= 2 and v >= 2

		ECOTOURISM_MANAGER:
			var g: int = stats.get("green_cards_played", 0)
			var y: int = stats.get("yellow_cards_played", 0)
			var d: int = GameState.get_shortest_distance_human_elephant()
			var total_e := 0
			for key in GameState.tile_registry:
				if GameState.tile_registry[key]["elephant_nodes"].size() > 0:
					total_e += 1
			var cond_dist: bool = (total_e > 0 and d >= 3)
			out.line1 = "Cards: %dG, %dY / 3G, 2Y" % [g, y]
			out.line2 = "Elephants / Dist: %s / %s" % ["Yes" if total_e > 0 else "No", str(d) if d != -1 else "N/A"]
			out.won = g >= 3 and y >= 2 and cond_dist

		WILDLIFE_DEPARTMENT:
			var g: int = stats.get("green_cards_played", 0)
			var e: int = GameState.get_elephants_in_forest()
			out.line1 = "Green Cards: %d / 4" % g
			out.line2 = "Forest Elephants: %d / 4" % e
			out.won = g >= 4 and e >= 4

		RESEARCHER:
			var ei: int = stats.get("e_inc_cards", 0)
			var vi: int = stats.get("v_inc_cards", 0)
			var both: int = stats.get("both_inc_cards", 0)
			var d: int = GameState.get_shortest_distance_human_elephant()
			out.line1 = "+Ele|+Hum|+Both: %d/%d/%d (Goal 2/3/0)" % [ei, vi, both]
			out.line2 = "Separation: %s (Goal >= 2)" % [str(d) if d != -1 else "N/A"]
			out.won = ei >= 2 and vi >= 3 and d >= 2

		GOVERNMENT:
			var r: int = stats.get("red_cards_played", 0)
			var y: int = stats.get("yellow_cards_played", 0)
			var v_pop: int = GameState.get_total_villagers()
			var total_e := 0
			for key in GameState.tile_registry:
				total_e += GameState.tile_registry[key]["elephant_nodes"].size()
			out.line1 = "Cards: %dR, %dY / 2R, 2Y" % [r, y]
			out.line2 = "Villagers / Elephants: %d / %d (Goal v>=2e)" % [v_pop, total_e]
			out.won = r >= 2 and y >= 2 and v_pop >= (2 * total_e)

	return out
