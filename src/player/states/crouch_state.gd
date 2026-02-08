class_name CrouchState
extends PlayerState
## CrouchState - Player crouching, reduced speed and hitbox

const CROUCH_SPEED_MULTIPLIER := 0.5
const CROUCH_HEIGHT_MULTIPLIER := 0.5
const DEFAULT_COLLISION_HEIGHT := 2.0
const DEFAULT_COLLISION_Y := 1.0

var collision_modified: bool = false

func enter(_msg: Dictionary = {}) -> void:
	# Modify collision shape for crouching
	var collision = player.get_node_or_null("CollisionShape3D")
	if collision and collision.shape is CapsuleShape3D:
		# Make a unique copy to avoid affecting other players
		if not collision.shape.resource_local_to_scene:
			collision.shape = collision.shape.duplicate()
		collision.shape.height = DEFAULT_COLLISION_HEIGHT * CROUCH_HEIGHT_MULTIPLIER
		collision.position.y = collision.shape.height / 2
		collision_modified = true

func physics_update(delta: float) -> void:
	var direction = get_input_direction()

	# Apply reduced movement speed
	apply_movement(direction, player.base_speed * CROUCH_SPEED_MULTIPLIER)
	apply_gravity(delta)

	player.move_and_slide()

func exit() -> void:
	# Always restore collision shape to defaults
	_restore_collision()

func _restore_collision() -> void:
	# Always restore collision to defaults, regardless of flag
	var collision = player.get_node_or_null("CollisionShape3D")
	if collision and collision.shape is CapsuleShape3D:
		collision.shape.height = DEFAULT_COLLISION_HEIGHT
		collision.position.y = DEFAULT_COLLISION_Y
	collision_modified = false

func get_transition() -> String:
	if not player.is_on_floor():
		return "Air"

	if not Input.is_action_pressed("crouch"):
		# Check if we can stand up (raycast for ceiling)
		if _can_stand_up():
			if has_movement_input():
				return "Move"
			return "Idle"

	if Input.is_action_just_pressed("attack"):
		return "Attack"

	if Input.is_action_just_pressed("block"):
		return "Parry"

	return ""

func _can_stand_up() -> bool:
	# Always allow standing up - no ceiling check needed for this game style
	# If there's a ceiling, the player will just bump into it
	return true
