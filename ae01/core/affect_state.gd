class_name AffectState

# φ(t) = [V, A, D, C, R, S, T]
var V: float = 0.0    # Valence            [-1,  1]
var A: float = 0.35   # Arousal            [ 0,  1]
var D: float = 0.0    # Dominance          [-1,  1]
var C: float = 0.0    # Certainty          [-1,  1]
var R: float = 0.2    # Motivational Rel.  [ 0,  1]
var S: float = 0.0    # Social Orientation [-1,  1]
var T: float = 0.0    # Temporal Orient.   [-1,  1]

# Raw 9-stream input vector s(t) — normalised to [0, 1]
var streams: Array = [0.5, 0.0, 0.0, 0.5, 0.5, 0.5, 0.0, 0.0, 0.0]

# Slow mood vector — same 7 dims, updates on a much slower timescale
var mood: Array = [0.0, 0.35, 0.0, 0.0, 0.2, 0.0, 0.0]

# Classifier output
var emotion_label: String = "Neutral"
var emotion_distance: float = 0.0

# Weighting mode: 0=Base 1=CM_Priority 2=Social_Engagement 3=Exploration
var weighting_mode: int = 0

func to_array() -> Array:
	return [V, A, D, C, R, S, T]

func from_array(a: Array) -> void:
	V = float(a[0]); A = float(a[1]); D = float(a[2])
	C = float(a[3]); R = float(a[4]); S = float(a[5]); T = float(a[6])

func to_dict() -> Dictionary:
	return {
		"V": V, "A": A, "D": D, "C": C, "R": R, "S": S, "T": T,
		"streams": streams.duplicate(),
		"mood": mood.duplicate(),
		"emotion": emotion_label,
		"emotion_distance": emotion_distance,
		"mode": weighting_mode
	}

func copy_from(other: AffectState) -> void:
	V = other.V; A = other.A; D = other.D; C = other.C
	R = other.R; S = other.S; T = other.T
	streams = other.streams.duplicate()
	mood = other.mood.duplicate()
	emotion_label = other.emotion_label
	emotion_distance = other.emotion_distance
	weighting_mode = other.weighting_mode

static func selftest() -> bool:
	var st := AffectState.new()
	var arr: Array = [0.5, 0.6, -0.3, 0.2, 0.8, -0.1, 0.4]
	st.from_array(arr)
	var back: Array = st.to_array()
	for i in range(7):
		if abs(float(back[i]) - float(arr[i])) > 1e-6:
			push_error("AffectState selftest FAIL: round-trip at index %d" % i)
			return false
	print("AffectState selftest PASS")
	return true
