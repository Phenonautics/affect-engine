extends Node

signal state_updated(state: Dictionary)

var current_state: Dictionary = {}
# Manual stream overrides from the control panel: {stream_idx: value}
var manual_overrides: Dictionary = {}
var scenario_active: bool = false

func push(state: Dictionary) -> void:
	current_state = state
	state_updated.emit(state)

func set_manual_override(stream_idx: int, value: float) -> void:
	manual_overrides[stream_idx] = clampf(value, 0.0, 1.0)

func clear_override(stream_idx: int) -> void:
	manual_overrides.erase(stream_idx)

func clear_all_overrides() -> void:
	manual_overrides.clear()

func apply_overrides(streams: Array) -> Array:
	var out: Array = streams.duplicate()
	for idx in manual_overrides:
		if idx >= 0 and idx < out.size():
			out[idx] = manual_overrides[idx]
	return out

func _ready() -> void:
	if OS.is_debug_build():
		_run_selftests()

func _run_selftests() -> void:
	print("--- AE-01 self-tests ---")
	MatMath.selftest()
	WeightMatrix.selftest()
	AffectState.selftest()
	EmotionClassifier.selftest()
	ScenarioLibrary.selftest()
	var engine := AffectEngine.new()
	engine.selftest()
	print("--- self-tests complete ---")
