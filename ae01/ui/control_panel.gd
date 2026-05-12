extends VBoxContainer

const STREAM_NAMES: Array = [
	"S1 Intero", "S2 Extero", "S3 Proprio",
	"S4 Relational", "S5 Goal", "S6 Mood",
	"S7 Intersub", "S8 Effort", "S9 Pred.Err"
]
const MODE_NAMES: Array = ["Base", "CM Priority", "Social Engagement", "Exploration"]

var _sliders: Array = []
var _override_active: CheckButton
var _scenario_option: OptionButton
var _scenario_play_btn: Button
var _scenario_player: ScenarioPlayer  # assigned by MainUI
var _narrative_label: Label
var _mode_option: OptionButton

# Reference to the AffectEngine (set by parent after scene ready)
var affect_engine_ref: AffectEngine = null

func _ready() -> void:
	_build_ui()

func set_scenario_player(sp) -> void:
	_scenario_player = sp
	if _scenario_player:
		_scenario_player.scenario_started.connect(_on_scenario_started)
		_scenario_player.scenario_ended.connect(_on_scenario_ended)
		_scenario_player.scenario_event_fired.connect(_on_event_fired)

func _build_ui() -> void:
	add_theme_constant_override("separation", 6)

	# --- Weighting mode ---
	var mode_lbl: Label = Label.new()
	mode_lbl.text = "Weighting Mode"
	mode_lbl.add_theme_font_size_override("font_size", 11)
	add_child(mode_lbl)

	_mode_option = OptionButton.new()
	for m in MODE_NAMES:
		_mode_option.add_item(m)
	_mode_option.selected = 0
	_mode_option.item_selected.connect(_on_mode_changed)
	add_child(_mode_option)

	# Separator
	add_child(_make_separator())

	# --- Manual overrides toggle ---
	_override_active = CheckButton.new()
	_override_active.text = "Manual Overrides"
	_override_active.button_pressed = false
	_override_active.toggled.connect(_on_override_toggled)
	add_child(_override_active)

	# --- Stream sliders ---
	var sliders_box: VBoxContainer = VBoxContainer.new()
	sliders_box.add_theme_constant_override("separation", 2)
	for i in range(9):
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var lbl: Label = Label.new()
		lbl.text = STREAM_NAMES[i]
		lbl.custom_minimum_size = Vector2(80, 0)
		lbl.add_theme_font_size_override("font_size", 10)
		row.add_child(lbl)

		var sl: HSlider = HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.01
		sl.value = 0.5
		sl.custom_minimum_size = Vector2(110, 18)
		sl.editable = false  # disabled until override is active
		sl.value_changed.connect(_on_slider_changed.bind(i))
		row.add_child(sl)

		_sliders.append(sl)
		sliders_box.add_child(row)
	add_child(sliders_box)

	add_child(_make_separator())

	# --- Scenario selector ---
	var sc_lbl: Label = Label.new()
	sc_lbl.text = "Scenario"
	sc_lbl.add_theme_font_size_override("font_size", 11)
	add_child(sc_lbl)

	_scenario_option = OptionButton.new()
	var keys: Array = ScenarioLibrary.get_keys()
	for k in keys:
		var sc: Dictionary = ScenarioLibrary.get_scenario(k)
		_scenario_option.add_item(sc.get("name", k))
	add_child(_scenario_option)

	_scenario_play_btn = Button.new()
	_scenario_play_btn.text = "▶  Play Scenario"
	_scenario_play_btn.pressed.connect(_on_play_scenario)
	add_child(_scenario_play_btn)

	add_child(_make_separator())

	# --- Narrative label ---
	_narrative_label = Label.new()
	_narrative_label.text = ""
	_narrative_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_narrative_label.custom_minimum_size = Vector2(0, 30)
	_narrative_label.add_theme_font_size_override("font_size", 10)
	_narrative_label.add_theme_color_override("font_color", Color(0.60, 0.75, 0.65))
	add_child(_narrative_label)

func _make_separator() -> HSeparator:
	var sep: HSeparator = HSeparator.new()
	return sep

func _on_mode_changed(idx: int) -> void:
	if affect_engine_ref:
		affect_engine_ref.set_weighting_mode(idx)
	# Also push the mode into the current AffectBus state for display
	if not AffectBus.current_state.is_empty():
		AffectBus.current_state["mode"] = idx

func _on_override_toggled(active: bool) -> void:
	for sl in _sliders:
		sl.editable = active
	if not active:
		AffectBus.clear_all_overrides()

func _on_slider_changed(value: float, stream_idx: int) -> void:
	if _override_active.button_pressed:
		AffectBus.set_manual_override(stream_idx, value)

func _on_play_scenario() -> void:
	if not _scenario_player:
		return
	if _scenario_player.is_running():
		_scenario_player.stop()
		_scenario_play_btn.text = "▶  Play Scenario"
		return
	var keys: Array = ScenarioLibrary.get_keys()
	var idx: int = _scenario_option.selected
	if idx >= 0 and idx < keys.size():
		# Disable manual override during scenario
		_override_active.button_pressed = false
		_on_override_toggled(false)
		_scenario_player.play(keys[idx])
		_scenario_play_btn.text = "■  Stop Scenario"

func _on_scenario_started(name: String) -> void:
	_narrative_label.text = "Playing: %s" % name

func _on_scenario_ended(_name: String) -> void:
	_narrative_label.text = ""
	_scenario_play_btn.text = "▶  Play Scenario"

func _on_event_fired(label: String, _stream: int, _value: float) -> void:
	_narrative_label.text = label
