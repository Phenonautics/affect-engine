extends VBoxContainer

var _label: Label
var _sub_label: Label
var _dims_brief: Label

func _ready() -> void:
	_build_ui()
	AffectBus.state_updated.connect(_on_state_updated)

func _build_ui() -> void:
	add_theme_constant_override("separation", 2)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.80))
	_label.text = "Neutral"
	add_child(_label)

	_sub_label = Label.new()
	_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_label.add_theme_font_size_override("font_size", 10)
	_sub_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.60))
	_sub_label.text = "mode: Base"
	add_child(_sub_label)

	_dims_brief = Label.new()
	_dims_brief.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dims_brief.add_theme_font_size_override("font_size", 10)
	_dims_brief.add_theme_color_override("font_color", Color(0.65, 0.70, 0.65))
	_dims_brief.text = "V 0.00  A 0.35  D 0.00"
	add_child(_dims_brief)

func _on_state_updated(state: Dictionary) -> void:
	var emotion: String = state.get("emotion", "Neutral")
	var dist: float = float(state.get("emotion_distance", 0.0))
	var mode_id: int = state.get("mode", 0)
	var mode_names: Array = ["Base", "CM Priority", "Social", "Explore"]
	var mode_str: String = mode_names[clampi(mode_id, 0, 3)]

	_label.text = emotion
	_sub_label.text = "mode: %s  |  dist: %.2f" % [mode_str, dist]

	var V: float = float(state.get("V", 0.0))
	var A: float = float(state.get("A", 0.35))
	var D: float = float(state.get("D", 0.0))
	_dims_brief.text = "V%+.2f  A%.2f  D%+.2f" % [V, A, D]

	# Colour the emotion label by valence
	var hue: float = 0.33 - V * 0.20
	_label.add_theme_color_override("font_color", Color.from_hsv(fmod(hue + 1.0, 1.0), 0.5, 0.95))
