class_name DashState
extends PlayerState
## DashState - ULTRAKILL style with directional variants

# Base dash constants
const FORWARD_DASH_SPEED := 40.0
const FORWARD_DASH_DURATION := 0.12
const SIDE_DASH_SPEED := 38.0
const SIDE_DASH_DURATION := 0.10
const BACK_DASH_SPEED := 32.0
const BACK_DASH_DURATION := 0.14
const BACK_DASH_IFRAMES := 0.08

# FOV effect
const DASH_FOV_CHANGE := 15.0

enum DashType { FORWARD, LEFT, RIGHT, BACK }

var dash_timer: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO
var dash_type: DashType = DashType.FORWARD
var iframe_timer: float = 0.0
var original_fov: float = 75.0

func enter(_msg: Dictionary = {}) -> void:
	player.dash_count += 1

	# Determine dash type from input
	var input_dir = get_input_direction()
	_determine_dash_type(input_dir)

	# Set dash parameters based on type
	match dash_type:
		DashType.FORWARD:
			dash_timer = FORWARD_DASH_DURATION
			dash_direction = -player.camera.global_transform.basis.z

		DashType.LEFT:
			dash_timer = SIDE_DASH_DURATION
			dash_direction = -player.camera.global_transform.basis.x

		DashType.RIGHT:
			dash_timer = SIDE_DASH_DURATION
			dash_direction = player.camera.global_transform.basis.x

		DashType.BACK:
			dash_timer = BACK_DASH_DURATION
			dash_direction = player.camera.global_transform.basis.z
			iframe_timer = BACK_DASH_IFRAMES
			# Enable invincibility for back dash
			if player.hurtbox:
				player.hurtbox.set_invincible(true)

	dash_direction = dash_direction.normalized()

	# FOV effect
	if player.camera:
		original_fov = player.camera.fov
		var tween = create_tween()
		tween.tween_property(player.camera, "fov", original_fov + DASH_FOV_CHANGE, 0.05)

	# Camera tilt based on dash direction
	match dash_type:
		DashType.LEFT:
			player.ang_for_cam_to_lerp_to = 8.0
		DashType.RIGHT:
			player.ang_for_cam_to_lerp_to = -8.0
		DashType.BACK:
			player.x_ang_for_cam_to_lerp_to = -5.0
		DashType.FORWARD:
			player.x_ang_for_cam_to_lerp_to = 3.0

	# Play dash animation if exists
	if player.animation_player and player.animation_player.has_animation("dash"):
		player.animation_player.play("dash")

	player.dash_performed.emit()

func _determine_dash_type(input_dir: Vector3) -> void:
	# No input = forward dash
	if input_dir.length() < 0.3:
		dash_type = DashType.FORWARD
		return

	# Determine based on input direction
	if input_dir.z < -0.5:
		dash_type = DashType.FORWARD
	elif input_dir.z > 0.5:
		dash_type = DashType.BACK
	elif input_dir.x < -0.5:
		dash_type = DashType.LEFT
	elif input_dir.x > 0.5:
		dash_type = DashType.RIGHT
	else:
		dash_type = DashType.FORWARD

func physics_update(delta: float) -> void:
	dash_timer -= delta

	# Update iframe timer for back dash
	if iframe_timer > 0:
		iframe_timer -= delta
		if iframe_timer <= 0 and player.hurtbox:
			player.hurtbox.set_invincible(false)

	# Get dash speed based on type
	var speed: float
	match dash_type:
		DashType.FORWARD:
			speed = FORWARD_DASH_SPEED
		DashType.LEFT, DashType.RIGHT:
			speed = SIDE_DASH_SPEED
		DashType.BACK:
			speed = BACK_DASH_SPEED

	# Apply dash velocity
	player.velocity = dash_direction * speed

	player.move_and_slide()

func exit() -> void:
	# Reset FOV
	if player.camera:
		var tween = create_tween()
		tween.tween_property(player.camera, "fov", original_fov, 0.1)

	# Reset camera tilt
	player.ang_for_cam_to_lerp_to = 0.0
	player.x_ang_for_cam_to_lerp_to = 0.0

	# Ensure invincibility is disabled
	if player.hurtbox:
		player.hurtbox.set_invincible(false)

	# Momentum preservation based on dash type
	var preserve_mult: float
	match dash_type:
		DashType.FORWARD:
			preserve_mult = 0.25
		DashType.LEFT, DashType.RIGHT:
			preserve_mult = 0.15
		DashType.BACK:
			preserve_mult = 0.1

	player.extra_velocity = dash_direction * (FORWARD_DASH_SPEED * preserve_mult)

func get_transition() -> String:
	if dash_timer <= 0:
		if player.is_on_floor():
			if has_movement_input():
				return "Move"
			return "Idle"
		return "Air"

	# Allow dash chaining with remaining dashes
	if (Input.is_action_just_pressed("f") or Input.is_action_just_pressed("dash")):
		if player.dash_count < player.max_dash_count:
			# Chain into another dash
			state_machine.transition_to("Dash")
			return ""

	return ""
