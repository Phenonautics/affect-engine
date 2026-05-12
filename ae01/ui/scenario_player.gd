extends Node
class_name ScenarioPlayer

signal scenario_started(name: String)
signal scenario_ended(name: String)
signal scenario_event_fired(label: String, stream: int, value: float)

var _active_scenario: Dictionary = {}
var _time_elapsed: float = 0.0
var _event_cursor: int = 0
var _running: bool = false
var _scenario_key: String = ""

func play(scenario_key: String) -> void:
	var sc: Dictionary = ScenarioLibrary.get_scenario(scenario_key)
	if sc.is_empty():
		push_warning("ScenarioPlayer: unknown scenario key '%s'" % scenario_key)
		return
	_active_scenario = sc
	_scenario_key = scenario_key
	_time_elapsed = 0.0
	_event_cursor = 0
	_running = true
	AffectBus.clear_all_overrides()
	AffectBus.scenario_active = true
	scenario_started.emit(sc.get("name", scenario_key))

func stop() -> void:
	_running = false
	AffectBus.clear_all_overrides()
	AffectBus.scenario_active = false
	if not _scenario_key.is_empty():
		scenario_ended.emit(_active_scenario.get("name", _scenario_key))
	_scenario_key = ""

func is_running() -> bool:
	return _running

func _process(delta: float) -> void:
	if not _running:
		return

	_time_elapsed += delta
	var events: Array = _active_scenario.get("events", [])
	var duration: float = float(_active_scenario.get("duration", 20.0))

	# Fire events whose time has been reached
	while _event_cursor < events.size():
		var ev: Dictionary = events[_event_cursor]
		if _time_elapsed >= float(ev["t"]):
			var stream_idx: int = int(ev["stream"])
			var val: float = float(ev["value"])
			AffectBus.set_manual_override(stream_idx, val)
			scenario_event_fired.emit(str(ev.get("label", "")), stream_idx, val)
			_event_cursor += 1
		else:
			break

	# Scenario finished
	if _time_elapsed >= duration:
		stop()
