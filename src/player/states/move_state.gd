class_name MoveState
extends PlayerState
## MoveState - Player moving on ground, handles walking and sprinting

const SPRINT_SPEED_MULTIPLIER := 1.6
const SPRINT_STAMINA_COST := 20.0  # Per second

var is_sprinting: bool = false

func enter(_msg: Dictionary = {}) -> void:
	is_sprinting = false

	# Play run animation for sword bobbing while moving
	if player.animation_player and player.animation_player.has_animation("run"):
		player.animation_player.play("run")

func physics_update(delta: float) -> void:
	var direction = get_input_direction()

	# Check for sprint
	is_sprinting = false
	if Input.is_action_pressed("sprint") and player.stamina.has_stamina(SPRINT_STAMINA_COST * delta):
		if player.stamina.use_continuous(SPRINT_STAMINA_COST, delta):
			is_sprinting = true

	# Calculate speed (apply player's speed multiplier from items)
	var current_speed = player.base_speed * player.speed_multiplier
	if is_sprinting:
		current_speed *= SPRINT_SPEED_MULTIPLIER

	# Apply movement - ULTRAKILL style instant response
	apply_movement(direction, current_speed)
	apply_gravity(delta)

	# Apply extra velocity (from dash) - decay quickly on ground
	player.velocity.x += player.extra_velocity.x
	player.velocity.z += player.extra_velocity.z
	player.extra_velocity = player.extra_velocity.lerp(Vector3.ZERO, 0.4)

	player.move_and_slide()

	# Update camera bob angles based on movement
	player.ang_for_cam_to_lerp_to = direction.x * -2.5
	player.x_ang_for_cam_to_lerp_to = direction.z * 7.5

	# Reset jump and dash when on floor
	if player.is_on_floor():
		player.jump_count = 0
		player.dash_count = 0

func exit() -> void:
	is_sprinting = false
	player.ang_for_cam_to_lerp_to = 0.0
	player.x_ang_for_cam_to_lerp_to = 0.0

func get_transition() -> String:
	if not player.is_on_floor():
		return "Air"

	if not has_movement_input():
		return "Idle"

	if Input.is_action_just_pressed("crouch"):
		if is_sprinting:
			return "Slide"
		return "Crouch"

	if Input.is_action_just_pressed("space"):
		return "Air"

	if (Input.is_action_just_pressed("f") or Input.is_action_just_pressed("dash")) and player.dash_count < player.max_dash_count:
		return "Dash"

	if Input.is_action_just_pressed("attack"):
		return "Attack"

	if Input.is_action_just_pressed("block"):
		return "Parry"

	return ""
