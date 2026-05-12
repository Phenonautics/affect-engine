extends CharacterBody2D
class_name Agent

const MAX_SPEED: float = 80.0
const ACCELERATION: float = 400.0

# Energy — maps to S1 Interoception
var energy: float = 0.80
const ENERGY_MAX: float = 1.0
const ENERGY_PASSIVE_DRAIN: float = 0.0003   # per physics tick at 60Hz ≈ 0.018/s
const ENERGY_MOVE_DRAIN: float = 0.0006
const ENERGY_WALL_PENALTY: float = 0.04
const ENERGY_RESOURCE_GAIN: float = 0.30
const DAMAGE_HAZARD: float = 0.0            # damage not tracked separately; energy loss only

var _engine: AffectEngine = AffectEngine.new()
var _grid_world: GridWorld = null
var _prev_grid_pos: Vector2i = Vector2i(-1, -1)
var _is_dead: bool = false

func _ready() -> void:
	# Locate GridWorld sibling (set by parent scene)
	_grid_world = get_parent().get_node_or_null("GridWorld")
	if _grid_world:
		position = _grid_world.grid_to_world_center(Vector2i(1, 1))

func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	var phi: AffectState = _engine.get_state()
	var state_dict: Dictionary = phi.to_dict()

	# --- Input direction ---
	var input_dir: Vector2 = Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_up", "move_down")
	if input_dir.length_squared() > 0.0:
		input_dir = input_dir.normalized()

	# --- Affect-modulated auto-behaviour ---
	var auto_dir: Vector2 = _compute_auto_direction(phi)
	# Blend: player input takes priority; auto fills in when no input
	var effective_dir: Vector2
	if input_dir.length_squared() > 0.01:
		effective_dir = input_dir
	else:
		effective_dir = auto_dir

	# Speed modulation: arousal increases speed
	var speed_mult: float = 0.5 + phi.A * 0.8
	# Fear freeze: high arousal, very negative V, low D → occasional freeze
	if phi.V < -0.5 and phi.A > 0.65 and phi.D < -0.4:
		if randf() < 0.20:
			effective_dir = Vector2.ZERO

	var target_velocity: Vector2 = effective_dir * MAX_SPEED * speed_mult
	velocity = velocity.move_toward(target_velocity, ACCELERATION * delta)

	# --- Move and handle collisions ---
	var prev_velocity: Vector2 = velocity
	move_and_slide()
	if velocity.length() < prev_velocity.length() * 0.3 and prev_velocity.length() > 10.0:
		# Hit a wall
		energy -= ENERGY_WALL_PENALTY

	# --- Energy drain ---
	energy -= ENERGY_PASSIVE_DRAIN
	energy -= ENERGY_MOVE_DRAIN * (velocity.length() / MAX_SPEED)

	# --- Grid-cell interactions ---
	var gp: Vector2i = Vector2i(int(position.x / GridWorld.CELL_SIZE), int(position.y / GridWorld.CELL_SIZE))
	if _grid_world:
		_grid_world.record_visit(gp)
		var cell: int = _grid_world.get_cell(gp)
		match cell:
			GridWorld.CELL_RESOURCE:
				if _grid_world.consume_resource(gp):
					energy = minf(energy + ENERGY_RESOURCE_GAIN, ENERGY_MAX)
			GridWorld.CELL_HAZARD:
				energy -= 0.006  # per physics tick at 60Hz ≈ 0.36/s contact
		if gp != _prev_grid_pos:
			_prev_grid_pos = gp

	energy = clampf(energy, 0.0, ENERGY_MAX)

	# --- Death check ---
	if energy <= 0.0:
		_is_dead = true
		_engine.reset()
		energy = 0.80  # respawn
		if _grid_world:
			position = _grid_world.grid_to_world_center(Vector2i(1, 1))
		_is_dead = false

	# --- Build stream context and tick affect engine ---
	var ctx: Dictionary = {
		"energy": energy,
		"grid_pos": gp,
		"velocity": velocity,
		"max_speed": MAX_SPEED,
		"goal_pos": _grid_world.goal_pos if _grid_world else Vector2i(4, 14),
		"grid_world": _grid_world,
		"mood_v": float(_engine.get_state().mood[0]) if _engine.get_state().mood.size() > 0 else 0.0,
	}
	var streams: Array = StreamSampler.sample(ctx, AffectBus.manual_overrides)
	var new_state: AffectState = _engine.tick(streams, delta)
	AffectBus.push(new_state.to_dict())

func _compute_auto_direction(phi: AffectState) -> Vector2:
	if not _grid_world:
		return Vector2.ZERO

	var gp: Vector2i = Vector2i(int(position.x / GridWorld.CELL_SIZE), int(position.y / GridWorld.CELL_SIZE))
	var dir: Vector2 = Vector2.ZERO

	# High motivational relevance + positive dominance → steer toward goal
	if phi.R > 0.55 and phi.D > 0.1:
		var goal: Vector2i = _grid_world.goal_pos
		var to_goal: Vector2 = Vector2(goal.x - gp.x, goal.y - gp.y)
		if to_goal.length_squared() > 0.0:
			dir += to_goal.normalized() * 0.8

	# Low energy + nearby resource → steer toward nearest resource
	if energy < 0.35:
		var res_dist: float = _grid_world.get_nearest_resource_distance(gp)
		if res_dist < 8.0:
			# Simple gradient: walk toward lower-hazard, higher-resource direction
			dir += _gradient_toward_resource(gp) * 0.6

	# Threat nearby + negative V → steer away from hazard
	if phi.V < -0.3:
		var haz_dir: Vector2 = _gradient_away_from_hazard(gp)
		# Fear retreats; anger approaches (D distinguishes)
		dir += haz_dir * (0.7 if phi.D < 0.0 else -0.4)

	return dir.normalized() if dir.length_squared() > 0.01 else Vector2.ZERO

func _gradient_toward_resource(gp: Vector2i) -> Vector2:
	var best: Vector2 = Vector2.ZERO
	var best_dist: float = INF
	for dy in range(-8, 9):
		for dx in range(-8, 9):
			var p: Vector2i = gp + Vector2i(dx, dy)
			if _grid_world.get_cell(p) == GridWorld.CELL_RESOURCE:
				var d: float = sqrt(float(dx*dx + dy*dy))
				if d < best_dist:
					best_dist = d
					best = Vector2(float(dx), float(dy)).normalized()
	return best

func _gradient_away_from_hazard(gp: Vector2i) -> Vector2:
	var away: Vector2 = Vector2.ZERO
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var p: Vector2i = gp + Vector2i(dx, dy)
			if _grid_world.get_cell(p) == GridWorld.CELL_HAZARD:
				var d: float = sqrt(float(dx*dx + dy*dy))
				if d > 0.0:
					away -= Vector2(float(dx), float(dy)).normalized() / d
	return away.normalized() if away.length_squared() > 0.01 else Vector2.ZERO

func _draw() -> void:
	# Geometric triangle pointing in movement direction
	var phi: AffectState = _engine.get_state()
	var face_color: Color = _affect_to_color(phi)
	var spd: float = velocity.length()
	var angle: float = velocity.angle() if spd > 5.0 else 0.0
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(10.0, 0.0).rotated(angle),
		Vector2(-7.0, -6.0).rotated(angle),
		Vector2(-7.0,  6.0).rotated(angle),
	])
	draw_colored_polygon(pts, face_color)
	# Energy ring
	var ring_r: float = 11.0
	var arc_end: float = TAU * energy
	draw_arc(Vector2.ZERO, ring_r, -PI * 0.5, -PI * 0.5 + arc_end, 32,
			Color(0.3, 0.9, 0.3, 0.8) if energy > 0.3 else Color(0.9, 0.3, 0.1, 0.9), 2.0)

func _affect_to_color(phi: AffectState) -> Color:
	var hue: float = 0.33 - phi.V * 0.22 + phi.A * 0.07
	var sat: float = clampf(0.45 + abs(phi.V) * 0.3 + phi.A * 0.15, 0.0, 1.0)
	var val: float = clampf(0.5 + phi.V * 0.2, 0.25, 0.9)
	return Color.from_hsv(fmod(hue + 1.0, 1.0), sat, val)
