class_name AffectEngine

# Smoothing rate: fraction of the gap between current φ and target closed per 60Hz tick.
const AFFECT_SMOOTHING: float = 0.12
# Mood EMA decay constant (very slow — hours timescale at 60Hz).
const MOOD_ALPHA: float = 0.0008
# How strongly mood pulls the current affect state toward itself.
const MOOD_FLOOR_BETA: float = 0.25
# Precision multiplier for prediction error (S9).
const PE_PRECISION: float = 1.2

var _state: AffectState = AffectState.new()
# Exponential moving average of stream signals — used as the prediction model.
var _predicted: Array = [0.5, 0.0, 0.0, 0.5, 0.5, 0.5, 0.0, 0.0, 0.0]

func tick(raw_streams: Array, delta: float) -> AffectState:
	# 1. Prediction error for S9 (precision-weighted L1 distance from prediction)
	var pe: float = _compute_pe(raw_streams)

	# 2. Inject PE into stream vector copy (S9 = index 8)
	var s: Array = raw_streams.duplicate()
	s[8] = clampf(pe, 0.0, 1.0)

	# 3. Stream integration: s × W → raw 7-dim vector (outputs in [0,1])
	var raw_phi: Array = StreamIntegrator.integrate(s, _state.weighting_mode)

	# 4. Re-centre bipolar dimensions from [0,1] → [-1,1]
	var centred: Array = StreamIntegrator.recentre(raw_phi)

	# 5. Smooth from current φ toward centred target (frame-rate normalised)
	var alpha: float = clampf(AFFECT_SMOOTHING * delta * 60.0, 0.0, 1.0)
	var current: Array = _state.to_array()
	var smoothed: Array = MatMath.lerp_array(current, centred, alpha)

	# 6. Clamp per dimension
	var clamped: Array = StreamIntegrator.clamp_dims(smoothed)

	# 7. Mood EMA — only update when motivational relevance R is meaningful
	var R_val: float = float(clamped[StreamIntegrator.IDX_R])
	var mood_alpha_eff: float = MOOD_ALPHA * (0.5 + R_val * 0.5)
	_state.mood = MatMath.lerp_array(_state.mood, clamped, mood_alpha_eff)

	# 8. Mood floor — softly pull φ toward mood
	var mood_pull: float = clampf(MOOD_FLOOR_BETA * delta, 0.0, 0.05)
	clamped = MatMath.lerp_array(clamped, _state.mood, mood_pull)
	clamped = StreamIntegrator.clamp_dims(clamped)

	# 9. Write back state
	_state.from_array(clamped)
	_state.streams = raw_streams.duplicate()
	_state.streams[8] = s[8]

	# 10. Update prediction model
	_update_predicted(raw_streams)

	# 11. Classify emotion
	var result: Array = EmotionClassifier.classify(clamped)
	_state.emotion_label = result[0]
	_state.emotion_distance = float(result[1])

	return _state

func set_weighting_mode(mode: int) -> void:
	_state.weighting_mode = clampi(mode, 0, 3)

func get_state() -> AffectState:
	return _state

func reset() -> void:
	_state = AffectState.new()
	_predicted = [0.5, 0.0, 0.0, 0.5, 0.5, 0.5, 0.0, 0.0, 0.0]

# Precision-weighted mean absolute error between actual streams and prediction.
func _compute_pe(actual: Array) -> float:
	var err: float = 0.0
	for i in range(8):  # exclude index 8 (PE itself)
		err += abs(float(actual[i]) - float(_predicted[i]))
	return clampf(PE_PRECISION * err / 8.0, 0.0, 1.0)

func _update_predicted(actual: Array) -> void:
	for i in range(8):
		_predicted[i] = lerpf(float(_predicted[i]), float(actual[i]), 0.08)

func selftest() -> bool:
	var ok: bool = true
	reset()

	# Run 1000 ticks with constant high-interoception signal
	var s_high: Array = [0.9, 0.1, 0.2, 0.6, 0.7, 0.5, 0.0, 0.1, 0.0]
	for _i in range(1000):
		tick(s_high, 1.0 / 60.0)

	# After convergence, V should be positive (good interoception → positive valence)
	if _state.V < 0.0:
		push_error("AffectEngine selftest FAIL: expected V > 0 after high-interoception, got %f" % _state.V)
		ok = false

	# Mood should have drifted toward positive V
	if float(_state.mood[0]) < -0.5:
		push_error("AffectEngine selftest FAIL: mood V stayed too negative: %f" % float(_state.mood[0]))
		ok = false

	# Fear vs Anger: same threat, different resource level
	# Low resource → fear (D < 0)
	reset()
	var s_threat_low_resource: Array = [0.1, 0.9, 0.5, 0.3, 0.2, 0.5, 0.0, 0.8, 0.0]
	for _i in range(300):
		tick(s_threat_low_resource, 1.0 / 60.0)
	var D_low: float = _state.D
	var label_low: String = _state.emotion_label

	# High resource → dominance higher
	reset()
	var s_threat_high_resource: Array = [0.9, 0.9, 0.8, 0.7, 0.7, 0.5, 0.0, 0.8, 0.0]
	for _i in range(300):
		tick(s_threat_high_resource, 1.0 / 60.0)
	var D_high: float = _state.D

	if D_high <= D_low:
		push_error("AffectEngine selftest FAIL: high resource should produce higher D. D_low=%f D_high=%f" % [D_low, D_high])
		ok = false

	reset()
	if ok:
		print("AffectEngine selftest PASS (D_low=%.2f, D_high=%.2f, label_low=%s)" % [D_low, D_high, label_low])
	return ok
