class_name IdleState
extends PlayerState
## IdleState - Player standing still on ground

func enter(_msg: Dictionary = {}) -> void:
	player.velocity.x = 0
	player.velocity.z = 0

	# Play idle sway animation for subtle sword movement
	if player.animation_player and player.animation_player.has_animation("idle_sway"):
		player.animation_player.play("idle_sway")

func physics_update(delta: float) -> void:
	apply_gravity(delta)
	player.move_and_slide()

	# Reset jump and dash when on floor
	if player.is_on_floor():
		player.jump_count = 0
		player.dash_count = 0

func get_transition() -> String:
	if not player.is_on_floor():
		return "Air"

	if has_movement_input():
		return "Move"

	if Input.is_action_just_pressed("crouch"):
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
