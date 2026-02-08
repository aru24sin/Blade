class_name HitFeedback
extends Node
## HitFeedback - Manages hitstop, screen shake, and camera effects for impactful combat

# Singleton access
static var instance: HitFeedback = null

# Hitstop state
var is_frozen: bool = false
var freeze_timer: float = 0.0
var original_time_scale: float = 1.0

# Screen shake state
var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var shake_timer: float = 0.0
var camera: Camera3D = null

# Camera punch
var fov_punch_amount: float = 0.0
var fov_punch_timer: float = 0.0
var original_fov: float = 75.0

func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS  # Run even when tree is paused

func _process(delta: float) -> void:
	# Handle hitstop
	if is_frozen:
		freeze_timer -= delta
		if freeze_timer <= 0:
			_end_hitstop()

	# Handle screen shake
	if shake_timer > 0:
		shake_timer -= delta
		_apply_shake()
	elif shake_intensity > 0:
		shake_intensity = 0.0
		_reset_camera_offset()

	# Handle FOV punch
	if fov_punch_timer > 0:
		fov_punch_timer -= delta
		_apply_fov_punch()

# === HITSTOP ===

static func apply_hitstop(duration: float) -> void:
	if instance:
		instance._apply_hitstop(duration)

func _apply_hitstop(duration: float) -> void:
	if is_frozen:
		# Extend existing hitstop if longer
		freeze_timer = max(freeze_timer, duration)
		return

	is_frozen = true
	freeze_timer = duration
	original_time_scale = Engine.time_scale

	# Freeze game
	Engine.time_scale = 0.0

func _end_hitstop() -> void:
	is_frozen = false
	Engine.time_scale = original_time_scale

# === SCREEN SHAKE ===

static func apply_shake(intensity: float, duration: float = 0.15) -> void:
	if instance:
		instance._apply_screen_shake(intensity, duration)

func _apply_screen_shake(intensity: float, duration: float) -> void:
	# Stack shakes by taking max intensity
	shake_intensity = max(shake_intensity, intensity)
	shake_duration = duration
	shake_timer = duration

	# Find camera if not cached
	if not camera:
		camera = get_viewport().get_camera_3d()

func _apply_shake() -> void:
	if not camera:
		return

	# Calculate shake offset with decay
	var decay = shake_timer / shake_duration
	var current_intensity = shake_intensity * decay

	# Random offset
	var offset = Vector3(
		randf_range(-1, 1) * current_intensity * 0.1,
		randf_range(-1, 1) * current_intensity * 0.1,
		0
	)

	# Apply to camera
	camera.h_offset = offset.x
	camera.v_offset = offset.y

func _reset_camera_offset() -> void:
	if camera:
		camera.h_offset = 0
		camera.v_offset = 0

# === FOV PUNCH ===

static func apply_fov_punch(amount: float, duration: float = 0.1) -> void:
	if instance:
		instance._apply_fov_punch_internal(amount, duration)

func _apply_fov_punch_internal(amount: float, duration: float) -> void:
	if not camera:
		camera = get_viewport().get_camera_3d()

	if camera:
		original_fov = camera.fov
		fov_punch_amount = amount
		fov_punch_timer = duration

func _apply_fov_punch() -> void:
	if not camera:
		return

	# Lerp back to original FOV
	var t = fov_punch_timer / 0.1  # Normalize
	var current_punch = fov_punch_amount * t
	camera.fov = original_fov + current_punch

	if fov_punch_timer <= 0:
		camera.fov = original_fov

# === COMBINED HIT EFFECT ===

static func on_hit_landed(attack_name: String, is_blocked: bool = false) -> void:
	if not instance:
		return

	var hitstop = CombatData.get_hitstop(attack_name)
	var shake = CombatData.get_screen_shake(attack_name)

	if is_blocked:
		hitstop *= 0.5
		shake *= 0.5

	instance._apply_hitstop(hitstop)
	instance._apply_screen_shake(shake, 0.15)
	instance._apply_fov_punch_internal(3.0, 0.1)

static func on_parry() -> void:
	if not instance:
		return

	instance._apply_hitstop(CombatData.HITSTOP_PARRY)
	instance._apply_screen_shake(CombatData.SCREEN_SHAKE_PARRY, 0.2)
	instance._apply_fov_punch_internal(5.0, 0.15)

static func on_posture_break() -> void:
	if not instance:
		return

	instance._apply_hitstop(CombatData.HITSTOP_BREAK)
	instance._apply_screen_shake(CombatData.SCREEN_SHAKE_BREAK, 0.3)
	instance._apply_fov_punch_internal(8.0, 0.2)

# === SLOWMO ===

static func apply_slowmo(time_scale: float, duration: float) -> void:
	if instance:
		instance._apply_slowmo(time_scale, duration)

func _apply_slowmo(time_scale: float, duration: float) -> void:
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration * time_scale).timeout
	Engine.time_scale = 1.0
