extends Control

# Emitted when user confirms a scenario and proceeds to role selection
const CELL_SIZE := 40  # pixels per grid cell in the preview

var selected_index: int = -1  # 0..4 = preset scenario, 5 = random

# Node references (created in _ready)
var card_container: HBoxContainer
var detail_panel: PanelContainer
var preview_grid: Control
var title_label: Label
var concept_label: RichTextLabel
var difficulty_label: RichTextLabel
var stats_label: Label
var confirm_button: Button

# Color mapping for the tile preview
const TILE_COLORS := {
	0: Color(0.18, 0.55, 0.22),   # Forest — green
	1: Color(0.82, 0.62, 0.35),   # Human/Village — tan
	2: Color(0.60, 0.40, 0.12),   # Plantation/OilPalm — brown
}

const ELEPHANT_COLOR := Color(0.75, 0.75, 0.80)
const SCENARIO_NAMES := [
	"Balanced Landscape",
	"Fragmented Forest",
	"Forest Corridor",
	"Village Expansion",
	"Protected Forest Core",
	"Random Map",
]

func _ready() -> void:
	# --- Root layout ---
	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 16)
	# Margins
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)
	margin.add_child(root_vbox)

	# --- Title ---
	var page_title := Label.new()
	page_title.text = "Choose a Scenario"
	page_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_title.add_theme_font_size_override("font_size", 42)
	page_title.add_theme_color_override("font_color", Color(0.96, 0.92, 0.78))
	root_vbox.add_child(page_title)

	# --- Cards row ---
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 210
	scroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(scroll)

	card_container = HBoxContainer.new()
	card_container.add_theme_constant_override("separation", 20)
	card_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_container.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll.add_child(card_container)

	_build_scenario_cards()

	# --- Detail area (two-column: preview + info) ---
	detail_panel = PanelContainer.new()
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var dp_style := StyleBoxFlat.new()
	dp_style.bg_color = Color(0.15, 0.13, 0.10, 0.9)
	dp_style.corner_radius_top_left = 12
	dp_style.corner_radius_top_right = 12
	dp_style.corner_radius_bottom_left = 12
	dp_style.corner_radius_bottom_right = 12
	dp_style.content_margin_left = 24
	dp_style.content_margin_right = 24
	dp_style.content_margin_top = 20
	dp_style.content_margin_bottom = 20
	detail_panel.add_theme_stylebox_override("panel", dp_style)
	root_vbox.add_child(detail_panel)

	var detail_hbox := HBoxContainer.new()
	detail_hbox.add_theme_constant_override("separation", 30)
	detail_panel.add_child(detail_hbox)

	# Left: map preview
	var preview_wrapper := VBoxContainer.new()
	preview_wrapper.custom_minimum_size = Vector2(340, 340)
	preview_wrapper.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preview_wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	detail_hbox.add_child(preview_wrapper)

	var preview_label := Label.new()
	preview_label.text = "Map Preview"
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_label.add_theme_font_size_override("font_size", 20)
	preview_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	preview_wrapper.add_child(preview_label)

	preview_grid = Control.new()
	preview_grid.custom_minimum_size = Vector2(CELL_SIZE * 8, CELL_SIZE * 8)
	preview_wrapper.add_child(preview_grid)

	# Right: info text
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 14)
	detail_hbox.add_child(info_vbox)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
	info_vbox.add_child(title_label)

	concept_label = RichTextLabel.new()
	concept_label.bbcode_enabled = true
	concept_label.fit_content = true
	concept_label.custom_minimum_size.y = 60
	concept_label.add_theme_font_size_override("normal_font_size", 18)
	concept_label.add_theme_color_override("default_color", Color(0.85, 0.82, 0.72))
	info_vbox.add_child(concept_label)

	stats_label = Label.new()
	stats_label.add_theme_font_size_override("font_size", 18)
	stats_label.add_theme_color_override("font_color", Color(0.78, 0.78, 0.72))
	info_vbox.add_child(stats_label)

	# Difficulty section
	var diff_title := Label.new()
	diff_title.text = "Role Difficulty"
	diff_title.add_theme_font_size_override("font_size", 22)
	diff_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	info_vbox.add_child(diff_title)

	difficulty_label = RichTextLabel.new()
	difficulty_label.bbcode_enabled = true
	difficulty_label.fit_content = true
	difficulty_label.custom_minimum_size.y = 80
	difficulty_label.add_theme_font_size_override("normal_font_size", 17)
	difficulty_label.add_theme_color_override("default_color", Color(0.82, 0.78, 0.68))
	info_vbox.add_child(difficulty_label)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_vbox.add_child(spacer)

	# --- Confirm button ---
	confirm_button = Button.new()
	confirm_button.text = "Continue to Role Selection  →"
	confirm_button.custom_minimum_size = Vector2(320, 55)
	confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	confirm_button.disabled = true
	confirm_button.add_theme_font_size_override("font_size", 22)

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.82, 0.71, 0.55)
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8
	btn_style.corner_radius_bottom_right = 8
	confirm_button.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := btn_style.duplicate()
	btn_hover.bg_color = Color(0.96, 0.64, 0.38)
	confirm_button.add_theme_stylebox_override("hover", btn_hover)
	var btn_disabled := btn_style.duplicate()
	btn_disabled.bg_color = Color(0.3, 0.3, 0.3, 0.5)
	confirm_button.add_theme_stylebox_override("disabled", btn_disabled)
	confirm_button.add_theme_color_override("font_color", Color(0.2, 0.12, 0.04))
	confirm_button.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))

	confirm_button.pressed.connect(_on_confirm_pressed)
	info_vbox.add_child(confirm_button)

	# --- Legend at bottom of preview ---
	var legend_hbox := HBoxContainer.new()
	legend_hbox.add_theme_constant_override("separation", 16)
	preview_wrapper.add_child(legend_hbox)
	_add_legend_item(legend_hbox, TILE_COLORS[0], "Forest")
	_add_legend_item(legend_hbox, TILE_COLORS[1], "Village")
	_add_legend_item(legend_hbox, TILE_COLORS[2], "Oil Palm")
	_add_legend_item(legend_hbox, ELEPHANT_COLOR, "Elephant")

	# Initial state: no selection
	detail_panel.visible = false


# --- Build the 6 scenario cards ---

func _build_scenario_cards() -> void:
	for i in range(6):
		var card := Button.new()
		card.custom_minimum_size = Vector2(190, 170)
		card.clip_text = true

		# Card visual style
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.22, 0.20, 0.17)
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_color = Color(0.45, 0.40, 0.32)
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10

		var hover := style.duplicate()
		hover.border_color = Color(1.0, 0.84, 0.0)
		hover.bg_color = Color(0.28, 0.25, 0.20)

		card.add_theme_stylebox_override("normal", style)
		card.add_theme_stylebox_override("hover", hover)
		card.add_theme_stylebox_override("pressed", hover)
		card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		card.add_theme_color_override("font_color", Color(0.92, 0.88, 0.76))
		card.add_theme_font_size_override("font_size", 17)

		# Build card inner layout
		var vbox := VBoxContainer.new()
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.add_theme_constant_override("separation", 6)
		# Add margins inside the button
		var m := MarginContainer.new()
		m.set_anchors_preset(Control.PRESET_FULL_RECT)
		m.add_theme_constant_override("margin_left", 10)
		m.add_theme_constant_override("margin_right", 10)
		m.add_theme_constant_override("margin_top", 10)
		m.add_theme_constant_override("margin_bottom", 10)
		card.add_child(m)
		m.add_child(vbox)

		# Number badge
		var num_label := Label.new()
		num_label.text = str(i + 1) if i < 5 else "?"
		num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_label.add_theme_font_size_override("font_size", 28)
		num_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
		vbox.add_child(num_label)

		# Name
		var name_label := Label.new()
		name_label.text = SCENARIO_NAMES[i]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.76))
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(name_label)

		# Subtitle hint for random option
		if i == 5:
			var q := Label.new()
			q.text = "Randomized"
			q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			q.add_theme_font_size_override("font_size", 14)
			q.add_theme_color_override("font_color", Color(0.7, 0.7, 0.65))
			vbox.add_child(q)

		card.pressed.connect(_on_card_pressed.bind(i))
		card_container.add_child(card)


# --- Card selection ---

func _on_card_pressed(index: int) -> void:
	selected_index = index

	# Update card highlight borders
	var cards = card_container.get_children()
	for i in range(cards.size()):
		var style: StyleBoxFlat
		if i == index:
			style = cards[i].get_theme_stylebox("hover").duplicate()
			style.border_color = Color(1.0, 0.84, 0.0)
			style.border_width_top = 4
			style.border_width_bottom = 4
			style.border_width_left = 4
			style.border_width_right = 4
		else:
			style = StyleBoxFlat.new()
			style.bg_color = Color(0.22, 0.20, 0.17)
			style.border_width_top = 3
			style.border_width_bottom = 3
			style.border_width_left = 3
			style.border_width_right = 3
			style.border_color = Color(0.45, 0.40, 0.32)
			style.corner_radius_top_left = 10
			style.corner_radius_top_right = 10
			style.corner_radius_bottom_left = 10
			style.corner_radius_bottom_right = 10
		cards[i].add_theme_stylebox_override("normal", style)

	# Show detail panel
	detail_panel.visible = true
	confirm_button.disabled = false

	if index < 5:
		_show_preset_details(index)
	else:
		_show_random_details()


func _show_preset_details(idx: int) -> void:
	var scenario = ScenarioData.SCENARIOS[idx]
	title_label.text = scenario["name"]
	concept_label.text = scenario["concept"]

	# Count tiles
	var counts := { 0: 0, 1: 0, 2: 0 }
	var grid: Array = scenario["grid"]
	for row in range(8):
		for col in range(8):
			counts[grid[row][col]] += 1

	stats_label.text = "Forest: %d  |  Village: %d  |  Oil Palm: %d  |  Elephants: %d  |  Villagers: %d" % [
		counts[0], counts[1], counts[2],
		scenario["elephants"].size(),
		scenario["villagers_count"],
	]

	var diff: Dictionary = scenario["difficulty"]
	difficulty_label.text = ""
	difficulty_label.append_text("[color=#7ec850]Pro-Elephant:[/color] " + diff["pro_elephant"] + "\n")
	difficulty_label.append_text("  Wildlife Department, Conservationist, Ecotourism Manager\n\n")
	difficulty_label.append_text("[color=#c8c850]Neutral:[/color] " + diff["neutral"] + "\n")
	difficulty_label.append_text("  Government, Researcher, Environmental Consultant\n\n")
	difficulty_label.append_text("[color=#c85050]Pro-People:[/color] " + diff["pro_people"] + "\n")
	difficulty_label.append_text("  Village Head, Plantation Owner, Land Developer")

	# Draw large preview
	_draw_grid_preview(grid, scenario["elephants"])


func _show_random_details() -> void:
	title_label.text = "Random Map"
	concept_label.text = "The board is generated using a seed-based flood-fill algorithm that creates three contiguous tile regions — Forest, Village, and Oil Palm. Each game is unique!"
	stats_label.text = "Forest: 26  |  Village: 19  |  Oil Palm: 19  |  Elephants: 3  |  Villagers: 6"

	difficulty_label.text = ""
	difficulty_label.append_text("[color=#7ec850]Pro-Elephant:[/color] Varies\n")
	difficulty_label.append_text("  Wildlife Department, Conservationist, Ecotourism Manager\n\n")
	difficulty_label.append_text("[color=#c8c850]Neutral:[/color] Varies\n")
	difficulty_label.append_text("  Government, Researcher, Environmental Consultant\n\n")
	difficulty_label.append_text("[color=#c85050]Pro-People:[/color] Varies\n")
	difficulty_label.append_text("  Village Head, Plantation Owner, Land Developer")

	# Draw a placeholder "?" grid
	_clear_preview()
	var center_label := Label.new()
	center_label.text = "?"
	center_label.add_theme_font_size_override("font_size", 120)
	center_label.add_theme_color_override("font_color", Color(0.5, 0.48, 0.4))
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview_grid.add_child(center_label)


func _draw_grid_preview(grid: Array, elephants: Array) -> void:
	_clear_preview()
	for row in range(8):
		for col in range(8):
			var rect := ColorRect.new()
			rect.color = TILE_COLORS[grid[row][col]]
			rect.position = Vector2(col * CELL_SIZE, row * CELL_SIZE)
			rect.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)
			preview_grid.add_child(rect)

	# Draw elephant markers
	for epos in elephants:
		var marker := ColorRect.new()
		marker.color = ELEPHANT_COLOR
		var cx: float = epos.y * CELL_SIZE + CELL_SIZE * 0.25
		var cy: float = epos.x * CELL_SIZE + CELL_SIZE * 0.25
		marker.position = Vector2(cx, cy)
		marker.size = Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)
		preview_grid.add_child(marker)


func _clear_preview() -> void:
	for child in preview_grid.get_children():
		child.queue_free()


# --- Legend helper ---

func _add_legend_item(parent: HBoxContainer, color: Color, label_text: String) -> void:
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(14, 14)
	swatch.color = color
	parent.add_child(swatch)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.68, 0.6))
	parent.add_child(lbl)


# --- Confirm → go to Role Selection ---

func _on_confirm_pressed() -> void:
	# Store choice in GameState
	GameState.selected_scenario_index = selected_index
	get_tree().change_scene_to_file("res://scenes/RoleSelection.tscn")
