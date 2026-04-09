extends VBoxContainer

func _ready():
	# Keep entries visually inside the ActionLog's rect even if more accumulate
	# than fit — anything outside the bounds is clipped instead of overflowing.
	clip_contents = true

func add_action(text: String, is_positive: bool):
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.16, 0.88) 
	style.border_width_left = 4
	style.border_color = Color(0.2, 0.85, 0.4) if is_positive else Color(0.95, 0.35, 0.3)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 3
	style.shadow_offset = Vector2(1, 2)
	panel.add_theme_stylebox_override("panel", style)

	var label = Label.new()
	var icon = "✓ " if is_positive else "✗ "
	label.text = icon + text
	label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.96))
	label.add_theme_font_size_override("font_size", 13)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	panel.add_child(label)
	add_child(panel)

	# Pop-in + scale animation
	panel.modulate = Color(1, 1, 1, 0)
	panel.scale = Vector2(0.95, 0.95)
	panel.pivot_offset = Vector2(0, panel.size.y / 2.0)
	var tw = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(panel, "modulate", Color(1, 1, 1, 1), 0.35)
	tw.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.35)

	# Limit number of log entries (ignore ones already animating out)
	var live: Array = []
	for c in get_children():
		if not c.has_meta("dying"):
			live.append(c)

	while live.size() > 8:
		var old_panel = live.pop_front()
		old_panel.set_meta("dying", true)
		var out_tw = create_tween().set_ease(Tween.EASE_IN)
		out_tw.tween_property(old_panel, "modulate", Color(1, 1, 1, 0), 0.2)
		out_tw.tween_property(old_panel, "scale", Vector2(0.95, 0.95), 0.15)
		out_tw.tween_callback(old_panel.queue_free)
