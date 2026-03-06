class_name BTBoid
extends Resource

#--------------------------------------------------------------------------------------
# Condition: Is the NPC currently in a flock?
#--------------------------------------------------------------------------------------
class InFlock extends BTCondition:
	func test(ctx: BaseController) -> bool:
		return ctx.is_in_flock()

	func _type_name() -> String:
		return "InFlock"


#--------------------------------------------------------------------------------------
# Action: UpdateBoid — Reynolds-style flocking (Separation, Alignment, Cohesion)
# Drives Vehicle.set_target_direction(Vector2)
#--------------------------------------------------------------------------------------
class UpdateBoid extends BTNode:
	# ---------------------- Perception ----------------------
	@export var perception_radius :float = 6000.0
	@export var separation_radius :float = 120.0
	# Optional: restrict neighbors to a forward cone using cos(FOV/2).
	# -1 disables FOV. Example: 120° FOV -> cos(60°)=0.5
	@export_range(-1.0, 1.0, 0.01) var neighbor_fov_cos :float = -1.0

	# ---------------------- Weights -------------------------
	@export var separation_weight  :float = 2.0
	@export var alignment_weight   :float = 1.0
	@export var cohesion_weight    :float = 1.0

	@export var follow_target      := false
	# ---------------------- Leader following ----------------
	# When one or more leaders (controllers with is_flock_lead == true) are within perception:
	# - steer toward the leaders' center (seek) and match their average heading (align)
	# - optionally down-weight normal alignment/cohesion so leaders dominate
	@export var lead_follow_weight: float = 1.0
	@export var lead_align_weight:  float = 1.0
	@export var downweight_non_lead_when_present: bool = true
	@export_range(0.0, 1.0, 0.01) var non_lead_scale_when_lead: float = 0.5
	# If true, ignore non-lead neighbors entirely when at least one leader is perceived
	@export var prefer_lead_only     := false
	@export var lead_follow_time_out := 1.0
	# ---------------------- Steering ------------------------
	# Small random nudge to avoid perfect symmetry (0..0.2 typical)
	@export_range(0.0, 0.5, 0.001) var jitter_strength: float = 0.00

	# ---------------------- Private -------------------------
	var m_rng := RandomNumberGenerator.new()
	var m_is_moving := false

	func _type_name() -> String:
		return "UpdateBoid"

	func _tick(ctx: BaseController, _delta: float) -> int:
		if not ctx.is_valid():
			return BTTypes.Status.FAILURE
		if ctx.is_flock_lead():
			return BTTypes.Status.FAILURE
		
		var self_pos: Vector2 = ctx.get_global_position()
		var current_dir: Vector2 = _safe_dir(ctx.get_direction_vector())
		
		var neighbors: Array = ctx.get_flockmates_in_radius(perception_radius) if ctx.has_method("get_flockmates_in_radius") else []
		if follow_target and ctx.get_target_controller():
			neighbors.append(ctx.get_target_controller())
		if neighbors.is_empty():
			return BTTypes.Status.FAILURE

		var perception_r2 := perception_radius * perception_radius
		var separation_r2 := separation_radius * separation_radius

		# Accumulators (non-lead) ---
		var sep := Vector2.ZERO
		var pos_sum := Vector2.ZERO
		var vel_sum := Vector2.ZERO
		var sep_count := 0
		var ali_count := 0
		var coh_count := 0
		
		# --- Accumulators (leaders) ---
		var lead_pos_sum := Vector2.ZERO
		var lead_direction_sum := Vector2.ZERO
		var lead_vel_sum := Vector2.ZERO
		var lead_count := 0
		var last_lead_active_time := 0.0

		for n in neighbors:
			# Skip self if flock API returns it
			if n == ctx:
				continue
			
			var is_lead = n.is_flock_lead()
			var to_n = n.get_global_position() - self_pos
			var d2   = to_n.length_squared()
			if d2 <= 0.000001 or d2 > perception_r2:
				continue

			# FOV gate (optional)
			if neighbor_fov_cos > -1.0:
				var cosang := current_dir.dot(to_n.normalized())
				if cosang < neighbor_fov_cos:
					continue
					
			# leaders and non-leaders both influence separation (to avoid clipping),
			# but we track alignment/cohesion separately.
			if d2 < separation_r2:
				sep -= to_n.normalized()
				sep_count += 1

			if is_lead:
				lead_pos_sum += n.get_global_position()
				if not follow_target:
					lead_direction_sum += n.get_direction_vector()
					lead_vel_sum += n.get_linear_velocity()
				lead_count += 1
			elif not prefer_lead_only:
				# Non-lead contributions (skipped entirely if prefer_lead_only)
				pos_sum += n.get_global_position()
				coh_count += 1
				
				vel_sum += n.get_direction_vector()
				ali_count += 1

		# --- Normalize/derive directions ---
		if sep_count > 0:
			sep = _safe_dir(sep)

		var ali_dir := Vector2.ZERO
		if ali_count > 0:
			ali_dir = _safe_dir(vel_sum / float(ali_count))

		var coh_dir := Vector2.ZERO
		if coh_count > 0:
			var center := pos_sum / float(coh_count)
			coh_dir = _safe_dir(center - self_pos)

		var lead_seek := Vector2.ZERO
		var lead_align := Vector2.ZERO
		var lead_velocity := Vector2.ZERO
		if lead_count > 0:
			var lead_center := lead_pos_sum / float(lead_count)
			lead_seek = _safe_dir(lead_center - self_pos)
			if lead_direction_sum.length_squared() > 0.0:
				lead_align = _safe_dir(lead_direction_sum / float(lead_count))
			if lead_vel_sum.length_squared() > 0.0:
				lead_velocity = lead_vel_sum / float(lead_count)
				if lead_velocity.length_squared() < 10.0:
					lead_velocity = Vector2.ZERO

				# --- Weighted sum ---
		var desired := Vector2.ZERO

		# Separation always applies
		desired += sep * separation_weight

		var non_lead_scale := 1.0
		if lead_count > 0 and downweight_non_lead_when_present:
			non_lead_scale = non_lead_scale_when_lead

		# Non-lead boids (optional downweight / optional skip by prefer_lead_only)
		if not prefer_lead_only or lead_count == 0:
			desired += ali_dir * (alignment_weight * non_lead_scale)
			desired += coh_dir * (cohesion_weight  * non_lead_scale)

		# Leader influence (takes precedence when present)
		if lead_count > 0:
			desired += lead_seek  * lead_follow_weight
			desired += lead_align * lead_align_weight

		if desired == Vector2.ZERO:
			desired = current_dir
		else:
			desired = desired.normalized()
		
		## Tiny jitter to avoid symmetry artifacts
		if jitter_strength > 0.0:
			var j := Vector2(m_rng.randf_range(-1.0, 1.0), m_rng.randf_range(-1.0, 1.0)).normalized()
			desired = _safe_dir(desired + j * jitter_strength)
#
		# RunningGear already manages smoothing steering(rotation) and maximum turning angle.
		if lead_velocity.length_squared() > 0.0 and lead_count > 0:
			last_lead_active_time = ctx.get_time_stamp()
		
		if (ctx.get_time_stamp() - last_lead_active_time) < lead_follow_time_out or lead_follow_time_out < 0.0 or not prefer_lead_only:
			ctx.set_target_direction(desired)
			ctx.move_forward()
		else:
			if m_is_moving:
				# Only stop the last movement started by UpdateBoid.
				ctx.stop_moving()
				m_is_moving = ctx.is_moving()
			return BTTypes.Status.FAILURE
		m_is_moving = ctx.is_moving()
		return BTTypes.Status.SUCCESS

	# ---------------------- Helpers ----------------------
	func _safe_dir(v: Vector2) -> Vector2:
		return v.normalized() if (v.length_squared() > 1e-6) else Vector2.ZERO

	func _clamp_turn(from_dir: Vector2, to_dir: Vector2, max_delta_angle: float) -> Vector2:
		var a := from_dir.angle()
		var b := to_dir.angle()
		var d := wrapf(b - a, -PI, PI)
		if absf(d) <= max_delta_angle:
			return to_dir
		var clamped = a + sign(d) * max_delta_angle
		return Vector2(cos(clamped), sin(clamped))
