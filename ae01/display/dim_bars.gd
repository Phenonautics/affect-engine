extends VBoxContainer

const DIM_NAMES: Array = ["V  Valence", "A  Arousal", "D  Dominance",
						   "C  Certainty", "R  Relevance", "S  Social", "T  Temporal"]
const DIM_KEYS: Array = ["V", "A", "D", "C", "R", "S", "T"]
# Bipolar dims: [-1,1] mapped to [0,1] for bar display
const BIPOLAR: Array = [true, false, true, true, false, true, true]

var _bars: Array = []
var _labels: Array = []

func _ready() -> void:
	_build_ui()
	AffectBus.state_updated.connect(_on_state_updated)

func _build_ui() -> void:
	add_theme_constant_override("separation", 3)
	for i in range(7):
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var lbl: Label = Label.new()
		lbl.text = DIM_NAMES[i]
		lbl.custom_minimum_size = Vector2(90, 0)
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		row.add_child(lbl)

		var bar: ProgressBar = ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 1.0
		bar.value = 0.5 if BIPOLAR[i] else 0.0
		bar.custom_minimum_size = Vector2(110, 14)
		bar.show_percentage = false
		row.add_child(bar)

		var val_lbl: Label = Label.new()
		val_lbl.text = " 0.00"
		val_lbl.custom_minimum_size = Vector2(38, 0)
		val_lbl.add_theme_font_size_override("font_size", 10)
		val_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		row.add_child(val_lbl)

		_bars.append(bar)
		_labels.append(val_lbl)
		add_child(row)

func _on_state_updated(state: Dictionary) -> void:
	for i in range(7):
		var raw: float = float(state.get(DIM_KEYS[i], 0.0))
		var bar: ProgressBar = _bars[i]
		var lbl: Label = _labels[i]

		# Map to [0,1] for progress bar
		var bar_val: float = (raw * 0.5 + 0.5) if BIPOLAR[i] else raw
		bar.value = clampf(bar_val, 0.0, 1.0)

		# Colour: green for positive / neutral, red for negative
		var fill_style: StyleBoxFlat = StyleBoxFlat.new()
		fill_style.corner_radius_top_left = 2
		fill_style.corner_radius_top_right = 2
		fill_style.corner_radius_bottom_left = 2
		fill_style.corner_radius_bottom_right = 2
		if BIPOLAR[i]:
			fill_style.bg_color = Color(0.3, 0.7, 0.4) if raw >= 0.0 else Color(0.75, 0.25, 0.25)
		else:
			fill_style.bg_color = Color(0.4, 0.6, 0.85)
		bar.add_theme_stylebox_override("fill", fill_style)

		var bg_style: StyleBoxFlat = StyleBoxFlat.new()
		bg_style.bg_color = Color(0.12, 0.12, 0.14)
		bg_style.corner_radius_top_left = 2
		bg_style.corner_radius_top_right = 2
		bg_style.corner_radius_bottom_left = 2
		bg_style.corner_radius_bottom_right = 2
		bar.add_theme_stylebox_override("background", bg_style)

		lbl.text = "%+.2f" % raw
