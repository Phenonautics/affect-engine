extends Node2D

# The affective face: all geometry is computed from φ(t).
# No animation assets, no sprites — pure procedural _draw().

func _ready() -> void:
	AffectBus.state_updated.connect(_on_state_updated)

func _on_state_updated(_state: Dictionary) -> void:
	queue_redraw()

func _draw() -> void:
	var st: Dictionary = AffectBus.current_state
	if st.is_empty():
		_draw_neutral()
		return

	var V: float = float(st.get("V", 0.0))
	var A: float = float(st.get("A", 0.35))
	var D: float = float(st.get("D", 0.0))
	var C: float = float(st.get("C", 0.0))
	var R: float = float(st.get("R", 0.2))
	var S: float = float(st.get("S", 0.0))
	var T: float = float(st.get("T", 0.0))

	# --- Derived geometry parameters ---
	var base_r: float = 52.0 + R * 22.0
	var y_scale: float = 1.0 + D * 0.28      # dominance → vertical elongation
	var face_color: Color = _face_color(V, A)
	var face_color_dark: Color = face_color.darkened(0.3)

	# --- Temporal radial lines (drawn behind face) ---
	if abs(T) > 0.12:
		var n_lines: int = int(abs(T) * 5.0) + 1
		var t_color: Color = Color(0.7, 0.8, 1.0, 0.35) if T > 0.0 else Color(1.0, 0.8, 0.55, 0.35)
		for k in range(n_lines):
			var ta: float = (TAU / float(n_lines)) * k + PI / 7.0
			var r0: float = base_r + 6.0
			var r1: float = base_r + 18.0 + abs(T) * 14.0
			draw_line(
				Vector2(r0 * cos(ta), r0 * sin(ta) * y_scale),
				Vector2(r1 * cos(ta), r1 * sin(ta) * y_scale),
				t_color, 1.5
			)

	# --- Face body (irregular hexagon scaled by D and V) ---
	var verts: PackedVector2Array = PackedVector2Array()
	for k in range(6):
		var angle: float = PI / 3.0 * float(k) - PI / 2.0
		var rx: float = base_r * (1.0 + D * 0.12 * cos(angle))
		var ry: float = base_r * y_scale * (1.0 + V * 0.08 * sin(angle))
		verts.append(Vector2(rx * cos(angle), ry * sin(angle)))
	draw_colored_polygon(verts, face_color)
	# Subtle border
	var outline_pts: PackedVector2Array = verts
	outline_pts.append(verts[0])
	draw_polyline(outline_pts, face_color_dark, 1.8)

	# --- Eyes ---
	var eye_sep: float = 22.0 + S * 10.0
	var eye_h: float = 3.5 + A * 12.0
	var eye_w: float = 10.0
	var pupil_r: float = 2.5 + (A + R) * 0.5 * 4.5
	var eye_y: float = -base_r * 0.22 * y_scale

	for side in [-1, 1]:
		var ex: float = float(side) * eye_sep
		_draw_ellipse(Vector2(ex, eye_y), eye_w, eye_h, Color(0.95, 0.95, 0.98))
		# Pupil shifts slightly toward social target
		var pupil_shift_x: float = float(side) * S * 3.0
		draw_circle(Vector2(ex + pupil_shift_x, eye_y), pupil_r, Color(0.05, 0.05, 0.06))
		# Highlight
		draw_circle(Vector2(ex + pupil_shift_x + 2.0, eye_y - 2.0), pupil_r * 0.35, Color(1.0, 1.0, 1.0, 0.7))

	# --- Brows ---
	var brow_furl: float = -PI / 10.0 * (1.0 - V)  # negative V → furrowed brows
	var brow_y: float = eye_y - eye_h - 7.0
	for side in [-1, 1]:
		var bx: float = float(side) * (eye_sep + 5.0)
		var bw: float = 12.0
		var dx: float = bw * cos(brow_furl) * float(side)
		var dy: float = bw * sin(brow_furl)
		draw_line(
			Vector2(bx - dx * 0.5, brow_y + dy * 0.5),
			Vector2(bx + dx * 0.5, brow_y - dy * 0.5),
			Color(0.85, 0.85, 0.88, 0.9), 2.8
		)

	# --- Nose slit (certainty indicator) ---
	var slit_alpha: float = clampf(0.25 + C * 0.45, 0.05, 0.75)
	var slit_len: float = 8.0 + C * 6.0
	draw_line(Vector2(0, -4.0), Vector2(0, slit_len), Color(0.7, 0.7, 0.75, slit_alpha), 2.0)

	# --- Mouth (Bezier curve via polyline, 13 sample points) ---
	var mouth_w: float = 16.0 + A * 16.0
	var mouth_y: float = base_r * 0.32 * y_scale
	var curve_dip: float = -V * 13.0   # negative = smile, positive = frown
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(13):
		var tt: float = float(i) / 12.0
		var px: float = lerpf(-mouth_w, mouth_w, tt)
		# Quadratic Bezier: endpoints at ±mouth_w, control point at (0, mouth_y + curve_dip)
		var t1: float = 1.0 - tt
		var bx: float = t1 * t1 * (-mouth_w) + 2.0 * t1 * tt * 0.0 + tt * tt * mouth_w
		var by: float = t1 * t1 * mouth_y + 2.0 * t1 * tt * (mouth_y + curve_dip) + tt * tt * mouth_y
		pts.append(Vector2(bx, by))
	draw_polyline(pts, Color(0.85, 0.85, 0.88, 0.88), 2.2)

	# --- Arousal micro-lines (tension marks at high arousal + low dominance) ---
	if A > 0.6 and D < -0.1:
		var tension_alpha: float = (A - 0.6) * 2.0 * (0.1 - minf(D, 0.0))
		tension_alpha = clampf(tension_alpha * 1.5, 0.0, 0.55)
		for side in [-1, 1]:
			for k in range(2):
				var lx: float = float(side) * (eye_sep + 14.0 + float(k) * 6.0)
				var ly: float = eye_y + 5.0 + float(k) * 7.0
				draw_line(Vector2(lx, ly), Vector2(lx, ly + 8.0),
						Color(0.85, 0.65, 0.65, tension_alpha), 1.2)

func _draw_ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(24):
		var a: float = TAU * float(i) / 24.0
		pts.append(center + Vector2(rx * cos(a), ry * sin(a)))
	draw_colored_polygon(pts, color)

func _draw_neutral() -> void:
	draw_circle(Vector2.ZERO, 50.0, Color(0.18, 0.18, 0.22))
	draw_arc(Vector2.ZERO, 50.0, 0.0, TAU, 32, Color(0.35, 0.35, 0.42), 1.5)

func _face_color(V: float, A: float) -> Color:
	# Joy=warm gold, Fear=cold blue, Anger=deep red, Calm=soft green
	# Hue: 0.33 (green) baseline, shifted by V and A
	var hue: float = 0.33 - V * 0.20 + A * 0.06
	var sat: float = clampf(0.35 + abs(V) * 0.35 + A * 0.20, 0.0, 1.0)
	var val: float = clampf(0.38 + V * 0.18, 0.18, 0.68)
	return Color.from_hsv(fmod(hue + 1.0, 1.0), sat, val)
