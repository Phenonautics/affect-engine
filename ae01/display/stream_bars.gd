extends VBoxContainer

const STREAM_NAMES: Array = [
	"S1  Intero", "S2  Extero", "S3  Proprio",
	"S4  Relational", "S5  Goal", "S6  Mood",
	"S7  Intersub", "S8  Effort", "S9  Pred.Err"
]
const BAR_COLORS: Array = [
	Color(0.30, 0.75, 0.40),  # S1 green
	Color(0.75, 0.55, 0.20),  # S2 amber
	Color(0.40, 0.65, 0.85),  # S3 sky
	Color(0.80, 0.45, 0.70),  # S4 rose
	Color(0.90, 0.80, 0.20),  # S5 gold
	Color(0.55, 0.55, 0.75),  # S6 slate
	Color(0.35, 0.80, 0.75),  # S7 teal
	Color(0.90, 0.50, 0.30),  # S8 orange
	Color(0.70, 0.30, 0.30),  # S9 red
]

var _bars: Array = []

func _ready() -> void:
	_build_ui()
	AffectBus.state_updated.connect(_on_state_updated)

func _build_ui() -> void:
	add_theme_constant_override("separation", 2)
	for i in range(9):
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var lbl: Label = Label.new()
		lbl.text = STREAM_NAMES[i]
		lbl.custom_minimum_size = Vector2(90, 0)
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		row.add_child(lbl)

		var bar: ProgressBar = ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 1.0
		bar.value = 0.0
		bar.custom_minimum_size = Vector2(120, 12)
		bar.show_percentage = false
		# Style the fill
		var fill_style: StyleBoxFlat = StyleBoxFlat.new()
		fill_style.bg_color = BAR_COLORS[i]
		fill_style.corner_radius_top_left = 2
		fill_style.corner_radius_top_right = 2
		fill_style.corner_radius_bottom_left = 2
		fill_style.corner_radius_bottom_right = 2
		bar.add_theme_stylebox_override("fill", fill_style)
		var bg_style: StyleBoxFlat = StyleBoxFlat.new()
		bg_style.bg_color = Color(0.12, 0.12, 0.14)
		bg_style.corner_radius_top_left = 2
		bg_style.corner_radius_top_right = 2
		bg_style.corner_radius_bottom_left = 2
		bg_style.corner_radius_bottom_right = 2
		bar.add_theme_stylebox_override("background", bg_style)

		row.add_child(bar)
		_bars.append(bar)
		add_child(row)

func _on_state_updated(state: Dictionary) -> void:
	var streams: Array = state.get("streams", [])
	for i in range(mini(9, streams.size())):
		_bars[i].value = clampf(float(streams[i]), 0.0, 1.0)
