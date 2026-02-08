class_name AirState
extends PlayerState
## AirState - ULTRAKILL style with enhanced air control, bunny hop, wall detection

# Enhanced constants
const AIR_SPEED := 20.0           # Increased from 12.0
const AIR_ACCEL := 100.0          # Instant direction changes
const AIR_DECEL := 80.0           # Quick stops
const COYOTE_TIME := 0.1          # Grace period after leaving ground
const JUMP_BUFFER := 0.15         # Buffer jump input before landing

# Bunny hop constants
const BHOP_WINDOW := 0.12         # ~7 frames at 60fps
const BHOP_SPEED_BONUS := 1.15
const BHOP_MAX_MULT := 1.6
const BHOP_DECAY := 0.95

# Wall detection
const WALL_DETECT_SPEED := 10.0   # Min speed for wall run

# State tracking
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var momentum_speed: float = 0.0
var bhop_multiplier: float = 1.0
var was_on_floor_last_frame: bool = false

func enter(msg: Dictionary = {}) -> void:
	was_on_floor_last_frame = player.is_on_floor()

	# Set coyote time if just left ground
	if was_on_floor_last_frame:
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer = 0.0

	# Check for jump input
	if Input.is_action_just_pressed("space"):
		if player.jump_count < player.max_jump_count:
			_perform_jump()
		jump_buffer_timer = 0.0

	# Capture entry momentum for bunny hop
	momentum_speed = Vector2(player.velocity.x, player.velocity.z).length()

	# Check for bunny hop chain continuation
	if msg.get("bhop_chain", false):
		bhop_multiplier = min(bhop_multiplier * BHOP_SPEED_BONUS, BHOP_MAX_MULT)
		player.bhop_chain += 1
	else:
		bhop_multiplier = 1.0
		player.bhop_chain = 0

func physics_update(delta: float) -> void:
	# Update timers
	coyote_timer = max(0, coyote_timer - delta)
	jump_buffer_timer = max(0, jump_buffer_timer - delta)

	# Enhanced air control - ULTRAKILL style instant response
	var direction = get_input_direction()

	if direction.length() > 0.1:
		var rotated_dir = direction.rotated(Vector3.UP, player.rotation.y)
		var target_vel = rotated_dir * AIR_SPEED * bhop_multiplier

		# Instant acceleration toward target
		player.velocity.x = move_toward(player.velocity.x, target_vel.x, AIR_ACCEL * delta)
		player.velocity.z = move_toward(player.velocity.z, target_vel.z, AIR_ACCEL * delta)
	else:
		# Quick deceleration when no input
		player.velocity.x = move_toward(player.velocity.x, 0, AIR_DECEL * delta)
		player.velocity.z = move_toward(player.velocity.z, 0, AIR_DECEL * delta)

	# Apply gravity
	apply_gravity(delta)

	# Apply extra velocity (from dash)
	player.velocity.x += player.extra_velocity.x
	player.velocity.z += player.extra_velocity.z
	player.extra_velocity = player.extra_velocity.lerp(Vector3.ZERO, 0.3)

	player.move_and_slide()

	# Decay bhop multiplier in air
	bhop_multiplier = max(1.0, bhop_multiplier * BHOP_DECAY)

	# Update camera angles based on movement
	player.ang_for_cam_to_lerp_to = direction.x * -3.0
	player.x_ang_for_cam_to_lerp_to = clamp(player.velocity.y * 0.3, -10, 10)

	# Update player momentum multiplier for external reference
	player.momentum_multiplier = bhop_multiplier

func handle_input(event: InputEvent) -> void:
	# Double jump / coyote jump
	if event.is_action_pressed("space"):
		if coyote_timer > 0 and player.jump_count == 0:
			# Coyote jump - first jump even after leaving platform
			_perform_jump()
		elif player.jump_count < player.max_jump_count:
			_perform_jump()
		else:
			# Buffer jump for landing
			jump_buffer_timer = JUMP_BUFFER

	# Ground slam (crouch in air)
	if event.is_action_pressed("crouch"):
		state_machine.transition_to("GroundSlam")
		return

func _perform_jump() -> void:
	player.jump_count += 1
	coyote_timer = 0.0

	if player.jump_count == 1:
		player.velocity.y = player.jump_strength
	else:
		# Double jump - reset vertical velocity first for consistent height
		player.velocity.y = player.double_jump_strength

	# Preserve horizontal momentum
	var horiz_speed = Vector2(player.velocity.x, player.velocity.z).length()
	if horiz_speed > AIR_SPEED:
		# Maintain momentum above base speed
		var horiz_dir = Vector2(player.velocity.x, player.velocity.z).normalized()
		player.velocity.x = horiz_dir.x * horiz_speed
		player.velocity.z = horiz_dir.y * horiz_speed

func get_transition() -> String:
	# Landing with bunny hop detection
	if player.is_on_floor():
		player.dash_count = 0

		# Check for bunny hop
		var bhop_success = jump_buffer_timer > 0 or Input.is_action_pressed("space")

		if bhop_success and player.jump_count < player.max_jump_count:
			# Successful bunny hop - immediate jump with momentum bonus
			state_machine.transition_to("Air", {"bhop_chain": true})
			return ""

		player.jump_count = 0
		player.momentum_multiplier = 1.0

		if has_movement_input():
			return "Move"
		return "Idle"

	# Wall run detection
	if Vector2(player.velocity.x, player.velocity.z).length() >= WALL_DETECT_SPEED:
		var wall_info = _detect_wall()
		if wall_info.detected:
			state_machine.transition_to("WallRun", {
				"wall_normal": wall_info.normal,
				"wall_side": wall_info.side
			})
			return ""

	# Dash
	if (Input.is_action_just_pressed("f") or Input.is_action_just_pressed("dash")) and player.dash_count < player.max_dash_count:
		return "Dash"

	# Attack
	if Input.is_action_just_pressed("attack"):
		return "Attack"

	# Parry/Block
	if Input.is_action_just_pressed("block"):
		return "Parry"

	return ""

func _detect_wall() -> Dictionary:
	var result = {"detected": false, "normal": Vector3.ZERO, "side": 0}

	# Get player's forward direction from camera
	var cam_forward = -player.camera.global_transform.basis.z
	cam_forward.y = 0
	cam_forward = cam_forward.normalized()

	# Calculate left and right directions
	var left_dir = cam_forward.rotated(Vector3.UP, PI/2)
	var right_dir = cam_forward.rotated(Vector3.UP, -PI/2)

	# Raycast parameters
	var space = player.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.new()
	query.from = player.global_position + Vector3.UP * 1.0  # Chest height
	query.collision_mask = 1  # World geometry layer
	query.exclude = [player.get_rid()]

	# Detection distance
	const DETECT_DIST := 0.8

	# Check left wall
	query.to = query.from + left_dir * DETECT_DIST
	var left_hit = space.intersect_ray(query)
	if left_hit:
		# Verify it's a valid wall (mostly vertical surface)
		if abs(left_hit.normal.y) < 0.3:
			result.detected = true
			result.normal = left_hit.normal
			result.side = -1
			return result

	# Check right wall
	query.to = query.from + right_dir * DETECT_DIST
	var right_hit = space.intersect_ray(query)
	if right_hit:
		if abs(right_hit.normal.y) < 0.3:
			result.detected = true
			result.normal = right_hit.normal
			result.side = 1
			return result

	return result
