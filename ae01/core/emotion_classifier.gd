class_name EmotionClassifier

# 14 named emotion regions defined by centroid coordinates in 7D φ-space.
# Each entry: [name, V, A, D, C, R, S, T]
const CENTROIDS: Array = [
	["Joy",          0.80,  0.50,  0.60,  0.70,  0.40,  0.40,  0.00],
	["Fear",        -0.60,  0.80, -0.70, -0.30,  0.70, -0.20,  0.60],
	["Anger",       -0.50,  0.70,  0.60,  0.40,  0.60, -0.10,  0.00],
	["Sadness",     -0.50, -0.50, -0.40,  0.30,  0.30,  0.20, -0.70],
	["Excitement",   0.80,  0.80,  0.50,  0.60,  0.50,  0.50,  0.50],
	["Anxiety",     -0.30,  0.60, -0.40, -0.60,  0.50, -0.30,  0.60],
	["Curiosity",    0.30,  0.50,  0.30, -0.40,  0.30,  0.00,  0.00],
	["Contentment",  0.70, -0.50,  0.50,  0.60,  0.10, -0.30,  0.00],
	["Frustration", -0.50,  0.40,  0.40,  0.40,  0.50, -0.30,  0.00],
	["Boredom",     -0.30, -0.60,  0.30,  0.50,  0.10, -0.40,  0.00],
	["Relief",       0.60, -0.30,  0.40,  0.60,  0.20,  0.00, -0.50],
	["Flow",         0.70,  0.40,  0.70,  0.70,  0.40, -0.40,  0.00],
	["Helplessness",-0.70, -0.40, -0.70, -0.20,  0.60,  0.10, -0.20],
	["Grief",       -0.60, -0.30, -0.30,  0.40,  0.50,  0.30, -0.80],
]

# Returns [emotion_name: String, distance: float]
static func classify(phi: Array) -> Array:
	var best_name: String = "Neutral"
	var best_dist: float = INF
	for entry in CENTROIDS:
		var centroid: Array = [
			float(entry[1]), float(entry[2]), float(entry[3]), float(entry[4]),
			float(entry[5]), float(entry[6]), float(entry[7])
		]
		var d: float = MatMath.distance_nd(phi, centroid)
		if d < best_dist:
			best_dist = d
			best_name = entry[0]
	return [best_name, best_dist]

# Returns all emotions sorted by distance, closest first.
static func classify_ranked(phi: Array) -> Array:
	var results: Array = []
	for entry in CENTROIDS:
		var centroid: Array = [
			float(entry[1]), float(entry[2]), float(entry[3]), float(entry[4]),
			float(entry[5]), float(entry[6]), float(entry[7])
		]
		results.append([entry[0], MatMath.distance_nd(phi, centroid)])
	results.sort_custom(func(a, b): return float(a[1]) < float(b[1]))
	return results

static func selftest() -> bool:
	var ok: bool = true
	# Feeding Joy centroid should return "Joy"
	var joy_phi: Array = [0.80, 0.50, 0.60, 0.70, 0.40, 0.40, 0.00]
	var result: Array = classify(joy_phi)
	if result[0] != "Joy":
		push_error("EmotionClassifier selftest FAIL: Joy centroid classified as '%s'" % result[0])
		ok = false
	# Fear centroid
	var fear_phi: Array = [-0.60, 0.80, -0.70, -0.30, 0.70, -0.20, 0.60]
	var fr: Array = classify(fear_phi)
	if fr[0] != "Fear":
		push_error("EmotionClassifier selftest FAIL: Fear centroid classified as '%s'" % fr[0])
		ok = false
	if ok:
		print("EmotionClassifier selftest PASS")
	return ok
