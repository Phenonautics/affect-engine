extends Node2D
class_name GridWorld

const CELL_SIZE: int = 32
const GRID_W: int = 16
const GRID_H: int = 16

# Cell type constants
const CELL_OPEN: int = 0
const CELL_WALL: int = 1
const CELL_RESOURCE: int = 2
const CELL_HAZARD: int = 3
const CELL_FAMILIAR: int = 4
const CELL_GOAL: int = 5
const CELL_OTHER_AGENT: int = 6

# Colours for each cell type (drawn procedurally — no texture assets)
const CELL_COLORS: Array = [
	Color(0.18, 0.18, 0.20, 1.0),  # 0 Open
	Color(0.08, 0.08, 0.10, 1.0),  # 1 Wall
	Color(0.85, 0.70, 0.15, 1.0),  # 2 Resource
	Color(0.75, 0.15, 0.10, 1.0),  # 3 Hazard
	Color(0.20, 0.45, 0.25, 1.0),  # 4 Familiar
	Color(0.90, 0.90, 0.90, 1.0),  # 5 Goal
	Color(0.20, 0.40, 0.80, 1.0),  # 6 Other Agent
]

# 16×16 grid layout. Index = row*16 + col. 0=open, 1=wall, 2=resource, etc.
const MAP: Array = [
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 4, 0, 0, 0, 1,
	1, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 0, 1,
	1, 0, 1, 0, 0, 3, 0, 0, 1, 0, 0, 0, 0, 1, 0, 1,
	1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
	1, 0, 0, 3, 0, 1, 1, 0, 0, 1, 1, 0, 3, 0, 0, 1,
	1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1,
	1, 0, 2, 0, 0, 0, 0, 6, 0, 0, 0, 0, 2, 0, 0, 1,
	1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
	1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1,
	1, 0, 3, 0, 0, 1, 1, 0, 0, 1, 1, 0, 3, 0, 0, 1,
	1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
	1, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 1,
	1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
	1, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
]

# Cells that have been "consumed" (resources depleted, regeneration timer)
var _depleted: Dictionary = {}   # Vector2i → float (seconds until regen)
const RESOURCE_REGEN_TIME: float = 15.0

# Visit counts for relational/familiarity stream
var visit_counts: Dictionary = {}  # Vector2i → int

# Goal position
var goal_pos: Vector2i = Vector2i(4, 14)
# Other agent position (mobile NPC)
var other_agent_pos: Vector2i = Vector2i(7, 7)
var _other_dir: Vector2i = Vector2i(1, 0)
var _other_move_timer: float = 0.0
const OTHER_MOVE_INTERVAL: float = 1.2

func _ready() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	# Regenerate depleted resources
	var to_remove: Array = []
	for pos in _depleted:
		_depleted[pos] -= delta
		if _depleted[pos] <= 0.0:
			to_remove.append(pos)
	for pos in to_remove:
		_depleted.erase(pos)
	if not to_remove.is_empty():
		queue_redraw()

	# Move other agent (simple wandering NPC)
	_other_move_timer += delta
	if _other_move_timer >= OTHER_MOVE_INTERVAL:
		_other_move_timer = 0.0
		_step_other_agent()

func get_cell(grid_pos: Vector2i) -> int:
	if grid_pos.x < 0 or grid_pos.x >= GRID_W or grid_pos.y < 0 or grid_pos.y >= GRID_H:
		return CELL_WALL
	var idx: int = grid_pos.y * GRID_W + grid_pos.x
	var base_type: int = MAP[idx]
	# Depleted resources show as open floor
	if base_type == CELL_RESOURCE and _depleted.has(grid_pos):
		return CELL_OPEN
	return base_type

func is_passable(grid_pos: Vector2i) -> bool:
	return get_cell(grid_pos) != CELL_WALL

func consume_resource(grid_pos: Vector2i) -> bool:
	if get_cell(grid_pos) == CELL_RESOURCE:
		_depleted[grid_pos] = RESOURCE_REGEN_TIME
		queue_redraw()
		return true
	return false

func record_visit(grid_pos: Vector2i) -> void:
	visit_counts[grid_pos] = visit_counts.get(grid_pos, 0) + 1

func get_familiarity(grid_pos: Vector2i) -> float:
	return clampf(float(visit_counts.get(grid_pos, 0)) / 12.0, 0.0, 1.0)

func get_nearest_hazard_distance(grid_pos: Vector2i, search_radius: int = 5) -> float:
	var min_dist: float = float(search_radius + 1)
	for dy in range(-search_radius, search_radius + 1):
		for dx in range(-search_radius, search_radius + 1):
			var p: Vector2i = grid_pos + Vector2i(dx, dy)
			if get_cell(p) == CELL_HAZARD:
				var d: float = sqrt(float(dx * dx + dy * dy))
				if d < min_dist:
					min_dist = d
	return min_dist

func get_nearest_resource_distance(grid_pos: Vector2i, search_radius: int = 8) -> float:
	var min_dist: float = float(search_radius + 1)
	for dy in range(-search_radius, search_radius + 1):
		for dx in range(-search_radius, search_radius + 1):
			var p: Vector2i = grid_pos + Vector2i(dx, dy)
			if get_cell(p) == CELL_RESOURCE:
				var d: float = sqrt(float(dx * dx + dy * dy))
				if d < min_dist:
					min_dist = d
	return min_dist

func get_other_agent_distance(grid_pos: Vector2i) -> float:
	var dx: float = float(other_agent_pos.x - grid_pos.x)
	var dy: float = float(other_agent_pos.y - grid_pos.y)
	return sqrt(dx * dx + dy * dy)

func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(world_pos.x / CELL_SIZE),
		int(world_pos.y / CELL_SIZE)
	)

func grid_to_world_center(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		grid_pos.x * CELL_SIZE + CELL_SIZE * 0.5,
		grid_pos.y * CELL_SIZE + CELL_SIZE * 0.5
	)

func _step_other_agent() -> void:
	# Try to move in current direction; if blocked, pick a random passable neighbour
	var candidates: Array = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	var next: Vector2i = other_agent_pos + _other_dir
	if is_passable(next) and next != other_agent_pos:
		other_agent_pos = next
	else:
		candidates.shuffle()
		for d in candidates:
			var try_pos: Vector2i = other_agent_pos + d
			if is_passable(try_pos):
				other_agent_pos = try_pos
				_other_dir = d
				break
	queue_redraw()

func _draw() -> void:
	for row in range(GRID_H):
		for col in range(GRID_W):
			var gp: Vector2i = Vector2i(col, row)
			var cell: int = get_cell(gp)
			var rect: Rect2 = Rect2(col * CELL_SIZE, row * CELL_SIZE, CELL_SIZE, CELL_SIZE)
			draw_rect(rect, CELL_COLORS[cell])
			# Cell border
			draw_rect(rect, Color(0.0, 0.0, 0.0, 0.3), false, 0.5)
			# Special cell markers
			match cell:
				CELL_RESOURCE:
					_draw_symbol(gp, "⚡", Color(1.0, 0.9, 0.2))
				CELL_HAZARD:
					_draw_symbol(gp, "✗", Color(1.0, 0.3, 0.2))
				CELL_GOAL:
					_draw_symbol(gp, "★", Color(1.0, 1.0, 1.0))
				CELL_FAMILIAR:
					draw_rect(Rect2(rect.position + Vector2(4,4), Vector2(CELL_SIZE-8, CELL_SIZE-8)),
							Color(0.3, 0.6, 0.35, 0.5), false, 1.5)
	# Other agent marker
	var oa_rect: Rect2 = Rect2(
		other_agent_pos.x * CELL_SIZE, other_agent_pos.y * CELL_SIZE,
		CELL_SIZE, CELL_SIZE
	)
	draw_rect(oa_rect, CELL_COLORS[CELL_OTHER_AGENT])
	_draw_symbol(other_agent_pos, "@", Color(0.8, 0.9, 1.0))

func _draw_symbol(grid_pos: Vector2i, _symbol: String, _color: Color) -> void:
	# Draw a simple geometric marker instead of text (no font dependency needed)
	var cx: float = grid_pos.x * CELL_SIZE + CELL_SIZE * 0.5
	var cy: float = grid_pos.y * CELL_SIZE + CELL_SIZE * 0.5
	draw_circle(Vector2(cx, cy), 5.0, _color)
