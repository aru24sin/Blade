class_name GroundSlamState
extends PlayerState
## GroundSlamState - Fast downward dive with shockwave on landing

const SLAM_SPEED := 65.0
const STARTUP_TIME := 0.08  # Brief hover before slam
const RECOVERY_TIME := 0.15
const SHOCKWAVE_RADIUS := 4.0
const SHOCKWAVE_DAMAGE := 25
const CAMERA_SHAKE_INTENSITY := 0.4

enum Phase { STARTUP, FALLING, RECOVERY }

var current_phase: Phase = Phase.STARTUP
var phase_timer: float = 0.0
var start_height: float = 0.0

func enter(_msg: Dictionary = {}) -> void:
	current_phase = Phase.STARTUP
	phase_timer = STARTUP_TIME
	start_height = player.global_position.y

	# Brief pause in air before slam
	player.velocity = Vector3.ZERO

	# Camera effect - look down
	player.x_ang_for_cam_to_lerp_to = 15.0

	# Play slam windup animation if exists
	if player.animation_player and player.animation_player.has_animation("slam_windup"):
		player.animation_player.play("slam_windup")

func physics_update(delta: float) -> void:
	phase_timer -= delta

	match current_phase:
		Phase.STARTUP:
			if phase_timer <= 0:
				_enter_falling_phase()

		Phase.FALLING:
			# Maintain slam velocity
			player.velocity.y = -SLAM_SPEED
			# Allow slight horizontal control
			var dir = get_input_direction()
			if dir.length() > 0.1:
				var rotated = dir.rotated(Vector3.UP, player.rotation.y)
				player.velocity.x = rotated.x * 5.0
				player.velocity.z = rotated.z * 5.0
			else:
				player.velocity.x *= 0.9
				player.velocity.z *= 0.9

			# Check for landing
			if player.is_on_floor():
				_on_slam_landed()

		Phase.RECOVERY:
			# Minimal movement during recovery
			player.velocity.x *= 0.8
			player.velocity.z *= 0.8
			apply_gravity(delta)

	player.move_and_slide()

func _enter_falling_phase() -> void:
	current_phase = Phase.FALLING
	phase_timer = 999.0  # Until landing

	# Intense downward velocity
	player.velocity.y = -SLAM_SPEED

	# Camera effect - motion blur hint
	player.x_ang_for_cam_to_lerp_to = 25.0

	# Play slam animation if exists
	if player.animation_player and player.animation_player.has_animation("slam_fall"):
		player.animation_player.play("slam_fall")

func _on_slam_landed() -> void:
	current_phase = Phase.RECOVERY
	phase_timer = RECOVERY_TIME

	# Calculate slam intensity based on fall distance
	var fall_distance = start_height - player.global_position.y
	var intensity_mult = clamp(fall_distance / 10.0, 0.5, 2.0)

	# Create shockwave damage
	_create_shockwave(SHOCKWAVE_RADIUS * intensity_mult, int(SHOCKWAVE_DAMAGE * intensity_mult * player.damage_multiplier))

	# Visual effects
	_spawn_slam_effects(intensity_mult)

	# Camera shake
	_apply_camera_shake(CAMERA_SHAKE_INTENSITY * intensity_mult)

	# Reset jump and dash on landing
	player.jump_count = 0
	player.dash_count = 0

	# Slam recovery animation if exists
	if player.animation_player and player.animation_player.has_animation("slam_land"):
		player.animation_player.play("slam_land")

func _create_shockwave(radius: float, damage: int) -> void:
	var space = player.get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = radius
	query.shape = sphere
	query.transform = player.global_transform
	query.collision_mask = 2  # Hurtbox layer

	var results = space.intersect_shape(query)
	for result in results:
		var collider = result.collider
		if collider.has_method("receive_damage") and collider.get("owner_id") != player.peer_id:
			collider.receive_damage(damage, player.peer_id)

func _spawn_slam_effects(intensity: float) -> void:
	# Spawn ring of PSX-style sparks
	var spark_count = int(12 * intensity)
	for i in range(spark_count):
		var angle = (float(i) / spark_count) * TAU
		var offset = Vector3(cos(angle) * 0.5, 0.1, sin(angle) * 0.5)
		var spark_pos = player.global_position + offset
		HitSpark.spawn_at(get_tree().current_scene, spark_pos, Color(1.0, 0.8, 0.3))

func _apply_camera_shake(intensity: float) -> void:
	# Apply camera shake via tween
	if player.camera:
		var original_pos = player.camera.position
		var tween = create_tween()
		for i in range(6):
			var offset = Vector3(
				randf_range(-intensity, intensity),
				randf_range(-intensity, intensity),
				0
			)
			tween.tween_property(player.camera, "position", original_pos + offset, 0.03)
		tween.tween_property(player.camera, "position", original_pos, 0.05)

func exit() -> void:
	player.x_ang_for_cam_to_lerp_to = 0.0

func get_transition() -> String:
	# Recovery complete
	if current_phase == Phase.RECOVERY and phase_timer <= 0:
		if has_movement_input():
			return "Move"
		return "Idle"

	# Can cancel recovery with dash
	if current_phase == Phase.RECOVERY:
		if (Input.is_action_just_pressed("f") or Input.is_action_just_pressed("dash")) and player.dash_count < player.max_dash_count:
			return "Dash"
		if Input.is_action_just_pressed("space"):
			return "Air"
		if Input.is_action_just_pressed("attack"):
			return "Attack"

	return ""
