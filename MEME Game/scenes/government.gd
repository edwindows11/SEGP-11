extends TextureButton

var base_scale
var tween

func _ready():
	base_scale = scale
	pivot_offset = size / 2
	
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_unhover)
	button_down.connect(_on_press)
	button_up.connect(_on_release)

func animate_to(target_scale, time):
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(self, "scale", target_scale, time)

func _on_hover():
	animate_to(base_scale * 1.1, 0.12)

func _on_unhover():
	animate_to(base_scale, 0.12)

func _on_press():
	animate_to(base_scale * 0.9, 0.05)

func _on_release():
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(self, "scale", base_scale * 1.1, 0.08)
	tween.tween_property(self, "scale", base_scale, 0.08)
