class_name CameraEffects
extends Node
## CameraEffects - Handles FOV, shake, and motion effects for ULTRAKILL-style feel

@export var camera: Camera3D
@export var base_fov: float = 75.0
@export var max_fov: float = 100.0
@export var fov_speed_scale: float = 0.5
@export var shake_decay: float = 5.0

# Speed-based FOV
var speed_fov_target: float = 0.0
var current_fov_offset: float = 0.0

# Screen shake
var shake_intensity: float = 0.0
var shake_offset: Vector3 = Vector3.ZERO

# Tilt
var tilt_target: float = 0.0
var current_tilt: float = 0.0

# Speed lines reference
var speed_lines: SpeedLines

func _ready() -> void:
	# Try to find camera if not set
	if not camera:
		var parent = get_parent()
		if parent:
			camera = parent.get_node_or_null("head/Camera3D")

	# Create speed lines as child of camera
	if camera:
		speed_lines = SpeedLines.new()
		camera.add_child(speed_lines)
		speed_lines.position = Vector3(0, 0, -0.5)

func _process(delta: float) -> void:
	if not camera:
		return

	# Update FOV
	current_fov_offset = lerp(current_fov_offset, speed_fov_target, 5.0 * delta)
	camera.fov = clamp(base_fov + current_fov_offset, base_fov, max_fov)

	# Update shake
	if shake_intensity > 0.01:
		shake_offset = Vector3(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity),
			0
		)
		shake_intensity *= exp(-shake_decay * delta)
	else:
		shake_offset = Vector3.ZERO
		shake_intensity = 0

	# Apply shake to camera
	camera.h_offset = shake_offset.x
	camera.v_offset = shake_offset.y

	# Update tilt
	current_tilt = lerp(current_tilt, tilt_target, 8.0 * delta)
	camera.rotation_degrees.z = current_tilt

func set_speed_effects(speed: float) -> void:
	# FOV change based on speed
	speed_fov_target = clamp(speed * fov_speed_scale - 10.0, 0, max_fov - base_fov)

	# Update speed lines
	if speed_lines:
		speed_lines.set_speed(speed)

func add_shake(intensity: float) -> void:
	shake_intensity = max(shake_intensity, intensity)

func set_tilt(angle: float) -> void:
	tilt_target = angle

func reset() -> void:
	speed_fov_target = 0.0
	shake_intensity = 0.0
	tilt_target = 0.0
	current_fov_offset = 0.0
	current_tilt = 0.0
	if camera:
		camera.fov = base_fov
		camera.h_offset = 0
		camera.v_offset = 0
		camera.rotation_degrees.z = 0
