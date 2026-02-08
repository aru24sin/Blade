class_name PlayerState
extends Node
## PlayerState - Base class for all player states

var player: CharacterBody3D
var state_machine: PlayerStateMachine

# Called when entering this state
func enter(_msg: Dictionary = {}) -> void:
	pass

# Called when exiting this state
func exit() -> void:
	pass

# Called every frame
func update(_delta: float) -> void:
	pass

# Called every physics frame
func physics_update(_delta: float) -> void:
	pass

# Called on input events
func handle_input(_event: InputEvent) -> void:
	pass

# Return state name to transition to, or empty string to stay
func get_transition() -> String:
	return ""

# Helper: Get movement input direction
func get_input_direction() -> Vector3:
	var dir := Vector3.ZERO
	dir.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	dir.z = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	return dir.normalized()

# Helper: Check if player has movement input
func has_movement_input() -> bool:
	return get_input_direction().length() > 0.1

# Helper: Apply gravity to player
func apply_gravity(delta: float) -> void:
	if not player.is_on_floor():
		player.velocity.y += player.gravity * delta

# Helper: Apply movement with rotation
func apply_movement(direction: Vector3, speed: float) -> void:
	var rotated_dir = direction.rotated(Vector3.UP, player.rotation.y)
	player.velocity.x = rotated_dir.x * speed
	player.velocity.z = rotated_dir.z * speed
