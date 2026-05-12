class_name StreamIntegrator

# Dimension index constants
const IDX_V: int = 0
const IDX_A: int = 1
const IDX_D: int = 2
const IDX_C: int = 3
const IDX_R: int = 4
const IDX_S: int = 5
const IDX_T: int = 6

# Per-dimension legal ranges [lo, hi]
const DIM_RANGES: Array = [
	[-1.0, 1.0],  # V
	[0.0,  1.0],  # A
	[-1.0, 1.0],  # D
	[-1.0, 1.0],  # C
	[0.0,  1.0],  # R
	[-1.0, 1.0],  # S
	[-1.0, 1.0],  # T
]

# Core integration: s_vec (9 streams) × W (9×7) → raw 7-dim contributions.
# Streams are expected in [0,1]. The resulting raw vector is NOT clamped here.
static func integrate(s_vec: Array, mode: int) -> Array:
	var W: Array = WeightMatrix.get_matrix(mode)
	return MatMath.vec_matmul(s_vec, W, WeightMatrix.STREAMS, WeightMatrix.DIMS)

# Re-centre the raw integration output.
# vec_matmul on [0,1] inputs with summed-to-1 columns gives output in [0,1].
# Dimensions with [-1,1] range need to be shifted: raw → 2*raw - 1.
static func recentre(raw: Array) -> Array:
	var out: Array = raw.duplicate()
	# Dims 0(V), 2(D), 3(C), 5(S), 6(T) are bipolar — shift from [0,1] to [-1,1]
	for j in [IDX_V, IDX_D, IDX_C, IDX_S, IDX_T]:
		out[j] = float(raw[j]) * 2.0 - 1.0
	# Dims 1(A) and 4(R) stay in [0,1]
	return out

# Clamp per-dimension to legal ranges.
static func clamp_dims(phi: Array) -> Array:
	var out: Array = phi.duplicate()
	for j in range(WeightMatrix.DIMS):
		var lo: float = float(DIM_RANGES[j][0])
		var hi: float = float(DIM_RANGES[j][1])
		out[j] = clampf(float(phi[j]), lo, hi)
	return out
