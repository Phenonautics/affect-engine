class_name WeightMatrix

# 9×7 weight matrix W, row-major flat Array.
# Rows = streams [S1..S9], Cols = dimensions [V, A, D, C, R, S, T]
# Each column is independently normalised to sum to 1.0.

const STREAMS: int = 9
const DIMS: int = 7

# Base weights — these define the structural prior of the affect engine.
# Dim order: [V,  A,  D,  C,  R,  S,  T]
const BASE_WEIGHTS: Array = [
#    V      A      D      C      R      S      T
	0.25,  0.30,  0.05,  0.05,  0.40,  0.00,  0.00,  # S1 Interoception
	0.20,  0.20,  0.05,  0.25,  0.10,  0.10,  0.00,  # S2 Exteroception
	0.10,  0.25,  0.15,  0.00,  0.00,  0.00,  0.00,  # S3 Proprioception
	0.20,  0.00,  0.05,  0.20,  0.20,  0.25,  0.05,  # S4 Relational Memory
	0.10,  0.05,  0.05,  0.00,  0.15,  0.00,  0.30,  # S5 Goal/Task
	0.05,  0.05,  0.05,  0.05,  0.00,  0.05,  0.10,  # S6 Mood
	0.05,  0.10,  0.00,  0.00,  0.10,  0.35,  0.00,  # S7 Intersubjective
	0.03,  0.03,  0.05,  0.00,  0.15,  0.00,  0.00,  # S8 Effort/Resource
	0.02,  0.02,  0.00,  0.25,  0.00,  0.00,  0.05   # S9 Prediction Error
]

# Row scale factors for each context mode.
# Each inner array has STREAMS (9) elements — one multiplier per stream row.
# After scaling, columns are renormalised.

const CM_PRIORITY_ROW_SCALES: Array = [1.4, 1.0, 1.0, 1.0, 1.2, 1.0, 1.0, 1.3, 1.0]
const SOCIAL_ENGAGEMENT_ROW_SCALES: Array = [1.0, 1.0, 1.0, 1.3, 1.0, 1.1, 1.6, 1.0, 1.0]
const EXPLORATION_ROW_SCALES: Array = [1.0, 1.5, 1.2, 1.0, 1.0, 1.0, 1.0, 1.0, 1.3]

# Cache — built once on first access.
static var _cache: Dictionary = {}

static func get_matrix(mode: int) -> Array:
	if _cache.has(mode):
		return _cache[mode]
	var W: Array = _build(mode)
	_cache[mode] = W
	return W

static func _build(mode: int) -> Array:
	var scales: Array
	match mode:
		1: scales = CM_PRIORITY_ROW_SCALES
		2: scales = SOCIAL_ENGAGEMENT_ROW_SCALES
		3: scales = EXPLORATION_ROW_SCALES
		_: return BASE_WEIGHTS  # mode 0: return base directly
	# Apply row scaling then renormalise columns
	var M: Array = BASE_WEIGHTS.duplicate()
	for i in range(STREAMS):
		for j in range(DIMS):
			M[i * DIMS + j] = float(M[i * DIMS + j]) * float(scales[i])
	return MatMath.normalise_columns(M, STREAMS, DIMS)

static func selftest() -> bool:
	var ok: bool = true
	# Column sums of BASE_WEIGHTS should each be ≈ 1.0 (they are by construction).
	for j in range(DIMS):
		var col_sum: float = 0.0
		for i in range(STREAMS):
			col_sum += float(BASE_WEIGHTS[i * DIMS + j])
		if abs(col_sum - 1.0) > 0.02:
			push_error("WeightMatrix selftest FAIL: column %d sum = %f" % [j, col_sum])
			ok = false
	# Test that S1-only stream vector returns expected V≈0.25, A≈0.30, R≈0.40
	var s: Array = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var W0: Array = get_matrix(0)
	var raw: Array = MatMath.vec_matmul(s, W0, STREAMS, DIMS)
	if abs(float(raw[0]) - 0.25) > 0.01:
		push_error("WeightMatrix selftest FAIL: S1→V expected 0.25, got %f" % float(raw[0]))
		ok = false
	if abs(float(raw[1]) - 0.30) > 0.01:
		push_error("WeightMatrix selftest FAIL: S1→A expected 0.30, got %f" % float(raw[1]))
		ok = false
	if abs(float(raw[4]) - 0.40) > 0.01:
		push_error("WeightMatrix selftest FAIL: S1→R expected 0.40, got %f" % float(raw[4]))
		ok = false
	# Test that S7-only stream returns S≈0.35
	var s7: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0]
	var raw7: Array = MatMath.vec_matmul(s7, W0, STREAMS, DIMS)
	if abs(float(raw7[5]) - 0.35) > 0.01:
		push_error("WeightMatrix selftest FAIL: S7→S expected 0.35, got %f" % float(raw7[5]))
		ok = false
	if ok:
		print("WeightMatrix selftest PASS")
	return ok
