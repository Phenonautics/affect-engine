extends Node2D

const RADIUS: float = 100.0
const DOT_RADIUS: float = 7.0
const TRAIL_LEN: int = 40

var _trail: Array = []  # Array of Vector2 — recent dot positions
var _current_pos: Vector2 = Vector2.ZERO

# Approximate region boundaries drawn as faint background zones
const REGION_ZONES: Array = [
	# [label, V_centre, A_centre, approx_radius, hue]
	["Joy",         0.75,  0.60, 0.28, 0.12],
	["Fear",       -0.60,  0.75, 0.28, 0.58],
	["Anger",      -0.45,  0.65, 0.28, 0.02],
	["Sadness",    -0.50, -0.40, 0.28, 0.62],
	["Excitement",  0.75,  0.85, 0.25, 0.10],
	["Anxiety",    -0.30,  0.55, 0.25, 0.55],
	["Curiosity",   0.30,  0.55, 0.22, 0.18],
	["Contentment", 0.65, -0.40, 0.28, 0.25],
	["Frustration",-0.45,  0.35, 0.22, 0.04],
	["Boredom",    -0.25, -0.55, 0.22, 0.50],
	["Relief",      0.55, -0.25, 0.22, 0.30],
	["Flow",        0.65,  0.45, 0.22, 0.15],
]

func _ready() -> void:
	AffectBus.state_updated.connect(_on_state_updated)

func _on_state_updated(state: Dictionary) -> void:
	var V: float = float(state.get("V", 0.0))
	var A: float = float(state.get("A", 0.5))
	# Map to pixel space: V→X (left=negative), A→Y (top=high arousal)
	_current_pos = Vector2(V * RADIUS, -(A * 2.0 - 1.0) * RADIUS)
	_trail.append(_current_pos)
	if _trail.size() > TRAIL_LEN:
		_trail.pop_front()
	queue_redraw()

func _draw() -> void:
	# Background circle
	draw_circle(Vector2.ZERO, RADIUS, Color(0.09, 0.09, 0.12, 1.0))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 64, Color(0.25, 0.25, 0.32), 1.5)

	# Region background zones
	for zone in REGION_ZONES:
		var zx: float = float(zone[1]) * RADIUS
		var zy: float = -(float(zone[2]) * 2.0 - 1.0) * RADIUS
		var zr: float = float(zone[3]) * RADIUS
		var zh: float = float(zone[4])
		draw_circle(Vector2(zx, zy), zr, Color.from_hsv(zh, 0.5, 0.3, 0.18))

	# Axes
	draw_line(Vector2(-RADIUS - 8, 0), Vector2(RADIUS + 8, 0), Color(0.35, 0.35, 0.42), 1.0)
	draw_line(Vector2(0, -RADIUS - 8), Vector2(0, RADIUS + 8), Color(0.35, 0.35, 0.42), 1.0)

	# Axis tick marks
	for v in [-0.5, 0.5]:
		var tx: float = v * RADIUS
		draw_line(Vector2(tx, -3), Vector2(tx, 3), Color(0.4, 0.4, 0.5), 1.0)
	for a in [-0.5, 0.5]:
		var ty: float = -(a * 2.0 - 1.0) * RADIUS * 0.5
		draw_line(Vector2(-3, ty * 2.0), Vector2(3, ty * 2.0), Color(0.4, 0.4, 0.5), 1.0)

	# Reference emotion dots (faint)
	for entry in EmotionClassifier.CENTROIDS:
		var ev: float = float(entry[1])
		var ea: float = float(entry[2])
		var dp: Vector2 = Vector2(ev * RADIUS, -(ea * 2.0 - 1.0) * RADIUS)
		draw_circle(dp, 3.0, Color(0.5, 0.55, 0.5, 0.45))

	# Trail
	if _trail.size() > 1:
		for i in range(1, _trail.size()):
			var alpha: float = float(i) / float(_trail.size()) * 0.55
			var t_color: Color = Color(0.85, 0.75, 0.25, alpha)
			draw_line(_trail[i - 1], _trail[i], t_color, 1.5)

	# Live dot
	if not AffectBus.current_state.is_empty():
		draw_circle(_current_pos, DOT_RADIUS, Color(0.95, 0.85, 0.25))
		draw_arc(_current_pos, DOT_RADIUS, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.8), 1.5)

		# Arousal ring (outer ring thickness = arousal)
		var A_val: float = float(AffectBus.current_state.get("A", 0.5))
		if A_val > 0.2:
			draw_arc(_current_pos, DOT_RADIUS + 3.0, 0.0, TAU * A_val, 32,
					Color(1.0, 0.6, 0.2, 0.5), 2.5)
