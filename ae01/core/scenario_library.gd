class_name ScenarioLibrary

# Scenario event format: {t: float, stream: int, value: float, label: String}
# t     — seconds since scenario start
# stream — 0-indexed stream (0=S1 Intero … 8=S9 PE)
# value  — override value [0, 1]
# label  — human-readable description shown in the narrative overlay

const SCENARIOS: Dictionary = {
	"depleting_agent": {
		"name": "Depleting Agent",
		"description": "Energy drains; anxiety builds; resource found → relief.",
		"duration": 20.0,
		"events": [
			{"t": 0.0,  "stream": 0, "value": 0.85, "label": "Normal operation — energy high"},
			{"t": 0.0,  "stream": 1, "value": 0.05, "label": "Environment clear"},
			{"t": 3.0,  "stream": 0, "value": 0.55, "label": "Energy declining"},
			{"t": 3.0,  "stream": 7, "value": 0.4,  "label": "Effort rising"},
			{"t": 6.0,  "stream": 0, "value": 0.30, "label": "Energy at 30% — warning"},
			{"t": 6.0,  "stream": 7, "value": 0.7,  "label": "High effort, low return"},
			{"t": 9.0,  "stream": 0, "value": 0.12, "label": "Critical depletion — CM override"},
			{"t": 9.0,  "stream": 4, "value": 0.85, "label": "Goal urgency spikes"},
			{"t": 9.0,  "stream": 8, "value": 0.8,  "label": "Prediction error high"},
			{"t": 13.0, "stream": 0, "value": 0.75, "label": "Resource found — energy restored"},
			{"t": 13.0, "stream": 4, "value": 0.95, "label": "Goal achieved"},
			{"t": 13.0, "stream": 7, "value": 0.1,  "label": "Effort drops"},
			{"t": 13.0, "stream": 8, "value": 0.05, "label": "Prediction error resolves"},
			{"t": 16.0, "stream": 0, "value": 0.80, "label": "Stable — contentment returning"},
		]
	},
	"novel_entity": {
		"name": "Novel Entity",
		"description": "Unknown entity detected → prediction error → curiosity → familiarity.",
		"duration": 18.0,
		"events": [
			{"t": 0.0,  "stream": 0, "value": 0.75, "label": "Nominal state"},
			{"t": 0.0,  "stream": 3, "value": 0.70, "label": "Familiar environment"},
			{"t": 2.0,  "stream": 1, "value": 0.85, "label": "Novel entity detected"},
			{"t": 2.0,  "stream": 8, "value": 0.90, "label": "Prediction error spikes"},
			{"t": 2.0,  "stream": 3, "value": 0.15, "label": "No relational memory match"},
			{"t": 4.0,  "stream": 2, "value": 0.60, "label": "Approach — proprioception rises"},
			{"t": 4.0,  "stream": 8, "value": 0.55, "label": "PE partially resolved"},
			{"t": 6.0,  "stream": 3, "value": 0.40, "label": "Relational record forming"},
			{"t": 6.0,  "stream": 8, "value": 0.25, "label": "Model building — PE falling"},
			{"t": 9.0,  "stream": 3, "value": 0.75, "label": "Entity is known now"},
			{"t": 9.0,  "stream": 8, "value": 0.05, "label": "PE resolved — certainty rising"},
			{"t": 9.0,  "stream": 6, "value": 0.60, "label": "Intersubjective signal positive"},
			{"t": 13.0, "stream": 1, "value": 0.40, "label": "Entity recedes — environment calms"},
		]
	},
	"fear_vs_anger": {
		"name": "Fear vs Anger",
		"description": "Same threat + low resources → Fear. Same threat + high resources → Anger.",
		"duration": 22.0,
		"events": [
			# Phase 1: Low resource state (0–10s)
			{"t": 0.0,  "stream": 0, "value": 0.15, "label": "Low resource state"},
			{"t": 0.0,  "stream": 2, "value": 0.20, "label": "Reduced proprioception"},
			{"t": 0.0,  "stream": 4, "value": 0.30, "label": "Goal progress blocked"},
			{"t": 1.5,  "stream": 1, "value": 0.90, "label": "Threat detected — same threat"},
			{"t": 1.5,  "stream": 8, "value": 0.80, "label": "Unexpected — PE spikes"},
			{"t": 1.5,  "stream": 7, "value": 0.75, "label": "High effort to escape"},
			{"t": 5.0,  "stream": 1, "value": 0.60, "label": "Threat persists — retreat"},
			# Phase 2: transition (10–12s)
			{"t": 10.0, "stream": 1, "value": 0.05, "label": "Threat clears — reset"},
			{"t": 10.0, "stream": 0, "value": 0.90, "label": "High resource state"},
			{"t": 10.0, "stream": 7, "value": 0.10, "label": "Effort low — resourced"},
			{"t": 10.0, "stream": 2, "value": 0.75, "label": "Strong proprioception"},
			{"t": 10.0, "stream": 4, "value": 0.80, "label": "Goal path open"},
			# Phase 3: Same threat, high resource (12–22s)
			{"t": 13.5, "stream": 1, "value": 0.90, "label": "Same threat — high resource"},
			{"t": 13.5, "stream": 8, "value": 0.80, "label": "PE spikes — same threat"},
			{"t": 13.5, "stream": 7, "value": 0.75, "label": "Effort to confront"},
		]
	}
}

static func get_scenario(key: String) -> Dictionary:
	return SCENARIOS.get(key, {})

static func get_keys() -> Array:
	return SCENARIOS.keys()

static func get_names() -> Array:
	var names: Array = []
	for k in SCENARIOS:
		names.append(SCENARIOS[k]["name"])
	return names

static func selftest() -> bool:
	var ok: bool = true
	# All scenarios must have events sorted by t ascending
	for key in SCENARIOS:
		var events: Array = SCENARIOS[key]["events"]
		var prev_t: float = -1.0
		for ev in events:
			if float(ev["t"]) < prev_t:
				push_error("ScenarioLibrary selftest FAIL: events not sorted in scenario '%s'" % key)
				ok = false
				break
			prev_t = float(ev["t"])
	if ok:
		print("ScenarioLibrary selftest PASS (%d scenarios)" % SCENARIOS.size())
	return ok
