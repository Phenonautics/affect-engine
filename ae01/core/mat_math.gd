class_name MatMath

# Multiply a length-n row vector v against an n×m matrix M (row-major flat Array).
# Returns a length-m Array.
static func vec_matmul(v: Array, M: Array, n: int, m: int) -> Array:
	var out: Array = []
	out.resize(m)
	for j in range(m):
		var acc: float = 0.0
		for i in range(n):
			acc += float(v[i]) * float(M[i * m + j])
		out[j] = acc
	return out

# Clamp every element of array a to [lo, hi]
static func clamp_array(a: Array, lo: float, hi: float) -> Array:
	var out: Array = a.duplicate()
	for i in range(out.size()):
		out[i] = clampf(float(out[i]), lo, hi)
	return out

# Dot product of two equal-length arrays
static func dot(a: Array, b: Array) -> float:
	var s: float = 0.0
	for i in range(a.size()):
		s += float(a[i]) * float(b[i])
	return s

# Euclidean distance in n-D
static func distance_nd(a: Array, b: Array) -> float:
	var sq: float = 0.0
	for i in range(a.size()):
		var d: float = float(a[i]) - float(b[i])
		sq += d * d
	return sqrt(sq)

# Lerp two arrays element-wise
static func lerp_array(a: Array, b: Array, t: float) -> Array:
	var out: Array = []
	out.resize(a.size())
	for i in range(a.size()):
		out[i] = lerpf(float(a[i]), float(b[i]), t)
	return out

# Scale each element of array a by scalar s
static func scale_array(a: Array, s: float) -> Array:
	var out: Array = a.duplicate()
	for i in range(out.size()):
		out[i] = float(out[i]) * s
	return out

# Element-wise sum of two arrays
static func add_arrays(a: Array, b: Array) -> Array:
	var out: Array = []
	out.resize(a.size())
	for i in range(a.size()):
		out[i] = float(a[i]) + float(b[i])
	return out

# L1 norm of an array
static func l1_norm(a: Array) -> float:
	var s: float = 0.0
	for i in range(a.size()):
		s += abs(float(a[i]))
	return s

# Normalise a flat n×m matrix so each column sums to 1.
# M is row-major: M[i*m + j] is row i, col j.
static func normalise_columns(M: Array, n: int, m: int) -> Array:
	var out: Array = M.duplicate()
	for j in range(m):
		var col_sum: float = 0.0
		for i in range(n):
			col_sum += abs(float(out[i * m + j]))
		if col_sum > 1e-9:
			for i in range(n):
				out[i * m + j] = float(out[i * m + j]) / col_sum
	return out

# Run built-in self-tests; returns true if all pass.
static func selftest() -> bool:
	var ok: bool = true

	# vec_matmul: identity-like 2×2 test
	var v2: Array = [1.0, 0.0]
	var M2: Array = [1.0, 0.0, 0.0, 1.0]
	var r2: Array = vec_matmul(v2, M2, 2, 2)
	if abs(float(r2[0]) - 1.0) > 1e-6 or abs(float(r2[1]) - 0.0) > 1e-6:
		push_error("MatMath selftest FAIL: vec_matmul identity")
		ok = false

	# distance_nd
	var a: Array = [0.0, 0.0]
	var b: Array = [3.0, 4.0]
	if abs(distance_nd(a, b) - 5.0) > 1e-5:
		push_error("MatMath selftest FAIL: distance_nd")
		ok = false

	# lerp_array
	var la: Array = [0.0, 1.0]
	var lb: Array = [1.0, 0.0]
	var lc: Array = lerp_array(la, lb, 0.5)
	if abs(float(lc[0]) - 0.5) > 1e-6 or abs(float(lc[1]) - 0.5) > 1e-6:
		push_error("MatMath selftest FAIL: lerp_array")
		ok = false

	if ok:
		print("MatMath selftest PASS")
	return ok
