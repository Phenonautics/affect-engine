class_name StreamSampler

# Derives the normalised 9-stream input vector from the current world/agent context.
# All outputs are in [0, 1] before being passed to AffectEngine.

# context dict keys expected:
#   energy: float [0,1]          S1 interoception
#   grid_pos: Vector2i           current grid cell
#   velocity: Vector2            current movement velocity
#   max_speed: float
#   goal_pos: Vector2i
#   grid_world: GridWorld node   for spatial queries
#   mood_v: float [-1,1]         V component of current mood

const MAX_HAZARD_SEARCH: int = 6      # cells to search for hazard proximity
const MAX_GOAL_DIST: float = 24.0     # normalisation denominator for goal distance
const MAX_OTHER_DIST: float = 10.0    # normalisation denominator for other-agent

static func sample(ctx: Dictionary, overrides: Dictionary) -> Array:
	var s: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

	var gw: GridWorld = ctx.get("grid_world", null)
	var gp: Vector2i = ctx.get("grid_pos", Vector2i(1, 1))
	var vel: Vector2 = ctx.get("velocity", Vector2.ZERO)
	var max_spd: float = ctx.get("max_speed", 100.0)
	var goal: Vector2i = ctx.get("goal_pos", Vector2i(4, 14))
	var energy: float = clampf(ctx.get("energy", 0.5), 0.0, 1.0)
	var mood_v: float = ctx.get("mood_v", 0.0)

	# S1 — Interoception: energy level
	s[0] = energy

	# S2 — Exteroception: threat proximity (1 = hazard adjacent, 0 = no hazard nearby)
	if gw:
		var haz_dist: float = gw.get_nearest_hazard_distance(gp, MAX_HAZARD_SEARCH)
		s[1] = clampf(1.0 - (haz_dist / float(MAX_HAZARD_SEARCH)), 0.0, 1.0)
	else:
		s[1] = 0.0

	# S3 — Proprioception: normalised movement speed
	if max_spd > 0.0:
		s[2] = clampf(vel.length() / max_spd, 0.0, 1.0)
	else:
		s[2] = 0.0

	# S4 — Relational Memory: cell familiarity
	if gw:
		s[3] = gw.get_familiarity(gp)
	else:
		s[3] = 0.0

	# S5 — Goal/Task: proximity to goal (1 = at goal, 0 = far)
	var goal_dist: float = float(abs(gp.x - goal.x) + abs(gp.y - goal.y))
	s[4] = clampf(1.0 - (goal_dist / MAX_GOAL_DIST), 0.0, 1.0)

	# S6 — Mood: re-centre V ([-1,1] → [0,1])
	s[5] = clampf(mood_v * 0.5 + 0.5, 0.0, 1.0)

	# S7 — Intersubjective: other-agent proximity
	if gw:
		var other_dist: float = gw.get_other_agent_distance(gp)
		s[6] = clampf(1.0 - (other_dist / MAX_OTHER_DIST), 0.0, 1.0)
	else:
		s[6] = 0.0

	# S8 — Effort/Resource: derived from speed + energy drain
	var speed_effort: float = s[2] * 0.6
	var energy_drain_effort: float = clampf(1.0 - energy, 0.0, 1.0) * 0.4
	s[7] = clampf(speed_effort + energy_drain_effort, 0.0, 1.0)

	# S9 — Prediction Error: filled by AffectEngine.tick(); 0 here as placeholder
	s[8] = 0.0

	# Apply manual overrides from AffectBus
	for idx in overrides:
		if int(idx) >= 0 and int(idx) < 9:
			s[int(idx)] = clampf(float(overrides[idx]), 0.0, 1.0)

	return s
