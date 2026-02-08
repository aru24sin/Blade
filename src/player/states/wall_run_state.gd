class_name WallRunState
extends PlayerState
## WallRunState - ULTRAKILL style wall running with wall jump

# Constants
const WALL_RUN_SPEED := 20.0
const WALL_GRAVITY := -8.0
const MAX_WALL_TIME := 1.2
const WALL_JUMP_HORIZONTAL := 14.0
const WALL_JUMP_VERTICAL := 15.0

# State tracking
var wall_timer: float = 0.0
var wall_normal: Vector3 = Vector3.ZERO
var wall_side: int = 0  # -1 = left, 1 = right
var entry_speed: float = 0.0

func enter(msg: Dictionary = {}) -> void:
	wall_timer = MAX_WALL_TIME
	wall_normal = msg.get("wall_normal", Vector3.ZERO)
	wall_side = msg.get("wall_side", 0)
	entry_speed = Vector2(player.velocity.x, player.velocity.z).length()

	# Reset vertical velocity for clean wall run start
	player.velocity.y = 0.0

	# Camera tilt toward wall
	player.ang_for_cam_to_lerp_to = wall_side * -8.0

	# Play wall run animation if exists
	if player.animation_player and player.animation_player.has_animation("wall_run"):
		player.animation_player.play("wall_run")

func physics_update(delta: float) -> void:
	wall_timer -= delta

	# Calculate wall-parallel movement direction
	var forward = -player.camera.global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()

	# Get wall-parallel direction (perpendicular to wall normal, in forward direction)
	var wall_forward = forward - wall_normal * forward.dot(wall_normal)
	wall_forward = wall_forward.normalized()

	# Apply wall run velocity
	var speed = max(entry_speed, WALL_RUN_SPEED)
	player.velocity.x = wall_forward.x * speed
	player.velocity.z = wall_forward.z * speed

	# Reduced gravity while on wall
	player.velocity.y += WALL_GRAVITY * delta

	# Clamp downward velocity on wall
	player.velocity.y = max(player.velocity.y, -15.0)

	player.move_and_slide()

	# Update wall detection
	_update_wall_detection()

	# Camera effects
	player.ang_for_cam_to_lerp_to = wall_side * -8.0

func handle_input(event: InputEvent) -> void:
	# Wall jump
	if event.is_action_pressed("space"):
		_perform_wall_jump()
		state_machine.transition_to("Air")
		return

	# Dash off wall
	if (event.is_action_pressed("f") or event.is_action_pressed("dash")) and player.dash_count < player.max_dash_count:
		state_machine.transition_to("Dash")
		return

	# Attack off wall
	if event.is_action_pressed("attack"):
		state_machine.transition_to("Attack")
		return

func _perform_wall_jump() -> void:
	# Jump away from wall with horizontal and vertical components
	var jump_dir = wall_normal * WALL_JUMP_HORIZONTAL
	player.velocity.x = jump_dir.x
	player.velocity.z = jump_dir.z
	player.velocity.y = WALL_JUMP_VERTICAL

	# Add forward momentum if moving forward
	var input_dir = get_input_direction()
	if input_dir.z < -0.5:  # Forward input
		var forward = -player.camera.global_transform.basis.z
		forward.y = 0
		forward = forward.normalized()
		player.velocity.x += forward.x * 8.0
		player.velocity.z += forward.z * 8.0

	# Use one jump charge
	player.jump_count += 1

func _update_wall_detection() -> bool:
	# Check if still touching wall using player's built-in collision
	for i in range(player.get_slide_collision_count()):
		var collision = player.get_slide_collision(i)
		var normal = collision.get_normal()
		# Check if this is a wall (mostly horizontal normal)
		if abs(normal.y) < 0.3:
			wall_normal = normal
			return true
	return false

func exit() -> void:
	player.ang_for_cam_to_lerp_to = 0.0

func get_transition() -> String:
	# Exit if wall time expired
	if wall_timer <= 0:
		return "Air"

	# Exit if no longer touching wall
	if not _update_wall_detection():
		return "Air"

	# Exit if landed
	if player.is_on_floor():
		player.jump_count = 0
		player.dash_count = 0
		if has_movement_input():
			return "Move"
		return "Idle"

	return ""
