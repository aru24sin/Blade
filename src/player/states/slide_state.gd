class_name SlideState
extends PlayerState
## SlideState - Fast, dynamic slide that integrates with movement system
## ULTRAKILL-inspired: chains into jumps, attacks, and other moves for momentum

# Slide parameters - fast and responsive
const SLIDE_INITIAL_SPEED := 28.0  # Burst of speed at start
const SLIDE_MIN_SPEED := 18.0  # Minimum slide speed
const SLIDE_DURATION := 0.6  # Base slide duration
const SLIDE_STAMINA_COST := 10.0  # Lower cost for more frequent use
const SLIDE_JUMP_BOOST := 1.35  # Speed multiplier when jump canceling
const SLIDE_ATTACK_DAMAGE_BOOST := 1.25  # Damage boost for slide attacks

# Camera effects
const SLIDE_CAMERA_DROP := -0.25  # How much camera drops during slide
const SLIDE_FOV_BOOST := 5.0  # FOV increase for speed feel

# Collision
const SLIDE_HEIGHT_MULTIPLIER := 0.45
const DEFAULT_COLLISION_HEIGHT := 2.0
const DEFAULT_COLLISION_Y := 1.0

var slide_timer: float = 0.0
var slide_direction: Vector3
var current_speed: float
var collision_modified: bool = false
var original_camera_y: float = 0.0
var can_redirect: bool = true  # Allow direction changes during slide

func enter(_msg: Dictionary = {}) -> void:
	# Check stamina
	if not player.stamina.use(SLIDE_STAMINA_COST):
		state_machine.transition_to("Crouch")
		return

	slide_timer = SLIDE_DURATION
	can_redirect = true

	# Get slide direction - always relative to camera facing
	var input_dir = get_input_direction()
	if input_dir.length() > 0.1:
		# Rotate input by player's Y rotation (camera facing)
		slide_direction = input_dir.rotated(Vector3.UP, player.rotation.y).normalized()
	elif player.velocity.length() > 1.0:
		slide_direction = Vector3(player.velocity.x, 0, player.velocity.z).normalized()
	else:
		# Default to camera forward direction
		slide_direction = Vector3(0, 0, -1).rotated(Vector3.UP, player.rotation.y)

	# Initial speed burst
	current_speed = SLIDE_INITIAL_SPEED

	# Inherit momentum if already moving fast
	var current_horizontal = Vector2(player.velocity.x, player.velocity.z).length()
	if current_horizontal > SLIDE_INITIAL_SPEED * 0.8:
		current_speed = max(current_speed, current_horizontal * 1.1)

	# Reduce collision height
	var collision = player.get_node_or_null("CollisionShape3D")
	if collision and collision.shape is CapsuleShape3D:
		if not collision.shape.resource_local_to_scene:
			collision.shape = collision.shape.duplicate()
		collision.shape.height = DEFAULT_COLLISION_HEIGHT * SLIDE_HEIGHT_MULTIPLIER
		collision.position.y = collision.shape.height / 2
		collision_modified = true

	# Store original camera position and drop it
	if player.camera:
		original_camera_y = player.camera.position.y
		# FOV boost for speed feel
		if player.camera_effects:
			player.camera_effects.set_speed_effects(current_speed * 1.5)

func physics_update(delta: float) -> void:
	slide_timer -= delta

	# Allow direction adjustment during slide (but reduced control)
	if can_redirect:
		var input_dir = get_input_direction()
		if input_dir.length() > 0.1:
			# Rotate input by player's Y rotation and blend with current direction
			var world_input = input_dir.rotated(Vector3.UP, player.rotation.y).normalized()
			slide_direction = (slide_direction * 0.7 + world_input * 0.3).normalized()

	# Speed decay - starts fast, decelerates smoothly
	var progress = 1.0 - (slide_timer / SLIDE_DURATION)
	# Eased deceleration - fast at start, slower decay later
	var ease_factor = 1.0 - pow(progress, 0.6)
	current_speed = lerp(SLIDE_MIN_SPEED, SLIDE_INITIAL_SPEED, ease_factor)

	# Apply slide velocity
	player.velocity.x = slide_direction.x * current_speed
	player.velocity.z = slide_direction.z * current_speed

	# Apply gravity (reduced during slide for smoother feel)
	player.velocity.y += player.gravity * 0.5 * delta

	player.move_and_slide()

	# Camera bob during slide
	if player.camera:
		var target_y = original_camera_y + SLIDE_CAMERA_DROP
		player.camera.position.y = lerp(player.camera.position.y, target_y, 0.15)

	# Regenerate a tiny bit of stamina while sliding (reward for good movement)
	player.stamina.add(2.0 * delta)

func exit() -> void:
	_restore_collision()

	# Restore camera position
	if player.camera:
		player.camera.position.y = original_camera_y

func _restore_collision() -> void:
	var collision = player.get_node_or_null("CollisionShape3D")
	if collision and collision.shape is CapsuleShape3D:
		collision.shape.height = DEFAULT_COLLISION_HEIGHT
		collision.position.y = DEFAULT_COLLISION_Y
	collision_modified = false

func handle_input(event: InputEvent) -> void:
	# Jump cancel - gives momentum boost!
	if event.is_action_pressed("space"):
		# Apply slide momentum to jump
		player.extra_velocity = slide_direction * current_speed * SLIDE_JUMP_BOOST * 0.4
		state_machine.transition_to("Air")
		return

	# Dash cancel
	if (event.is_action_pressed("f") or event.is_action_pressed("dash")) and player.dash_count < player.max_dash_count:
		# Carry momentum into dash
		player.extra_velocity = slide_direction * current_speed * 0.3
		state_machine.transition_to("Dash")
		return

	# Slide attack - upward sweeping attack
	if event.is_action_pressed("attack"):
		# Set damage boost for slide attack
		player.damage_multiplier *= SLIDE_ATTACK_DAMAGE_BOOST
		state_machine.transition_to("Attack", {"attack_type": "slide_attack"})
		return

func get_transition() -> String:
	# Fall off edge
	if not player.is_on_floor():
		# Keep momentum when falling
		player.extra_velocity = slide_direction * current_speed * 0.5
		return "Air"

	# Slide duration ended
	if slide_timer <= 0:
		if Input.is_action_pressed("crouch"):
			return "Crouch"
		if has_movement_input():
			return "Move"
		return "Idle"

	# Also check jump in get_transition for redundancy
	if Input.is_action_just_pressed("space"):
		player.extra_velocity = slide_direction * current_speed * SLIDE_JUMP_BOOST * 0.4
		return "Air"

	# Dash cancel
	if (Input.is_action_just_pressed("f") or Input.is_action_just_pressed("dash")) and player.dash_count < player.max_dash_count:
		player.extra_velocity = slide_direction * current_speed * 0.3
		return "Dash"

	# Attack cancel
	if Input.is_action_just_pressed("attack"):
		player.damage_multiplier *= SLIDE_ATTACK_DAMAGE_BOOST
		return "Attack"

	# Release crouch early to end slide
	if not Input.is_action_pressed("crouch") and slide_timer < SLIDE_DURATION * 0.5:
		if has_movement_input():
			return "Move"
		return "Idle"

	return ""
