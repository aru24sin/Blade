class_name BlockState
extends PlayerState
## BlockState - Souls-style hold to block with stamina drain and guard break

var block_start_time: float = 0.0
var was_hit: bool = false

func enter(_msg: Dictionary = {}) -> void:
	block_start_time = Time.get_ticks_msec() / 1000.0
	was_hit = false

	# Check stamina - can't block if depleted
	if player.stamina_component and player.stamina_component.current_stamina < CombatData.STAMINA_DEPLETED_THRESHOLD:
		state_machine.transition_to("Idle")
		return

	# Set hurtbox to blocking mode
	if player.hurtbox:
		player.hurtbox.set_blocking(true)

	# Play block animation
	if player.animation_player:
		player.animation_player.play("block")

	# Sync over network
	if player.is_multiplayer_authority():
		_sync_block_start.rpc()

@rpc("any_peer", "call_local", "reliable")
func _sync_block_start() -> void:
	if not player.is_multiplayer_authority():
		if player.hurtbox:
			player.hurtbox.set_blocking(true)
		if player.animation_player:
			player.animation_player.play("block")

const BLOCK_STAMINA_DRAIN_RATE: float = 2.0  # Stamina per second while blocking (slow drain)

func physics_update(delta: float) -> void:
	# Drain stamina while blocking
	if player.stamina_component:
		player.stamina_component.spend(BLOCK_STAMINA_DRAIN_RATE * delta)

	# Reduced movement while blocking
	var direction = get_input_direction()
	var move_speed = player.base_speed * CombatData.BLOCK_MOVEMENT_MULT
	apply_movement(direction, move_speed)
	apply_gravity(delta)
	player.move_and_slide()

func exit() -> void:
	if player.hurtbox:
		player.hurtbox.set_blocking(false)

	# Reset to default stance
	if player.animation_player and not was_hit:
		player.animation_player.play("RESET")

	# Sync over network
	if player.is_multiplayer_authority():
		_sync_block_end.rpc()

@rpc("any_peer", "call_local", "reliable")
func _sync_block_end() -> void:
	if not player.is_multiplayer_authority():
		if player.hurtbox:
			player.hurtbox.set_blocking(false)

func handle_input(event: InputEvent) -> void:
	# Jump cancel
	if event.is_action_pressed("space") and player.jump_count < player.max_jump_count:
		state_machine.transition_to("Air")
		return

	# Dash cancel
	if (event.is_action_pressed("f") or event.is_action_pressed("dash")) and player.dash_count < player.max_dash_count:
		state_machine.transition_to("Dash")
		return

	# Attack cancel
	if event.is_action_pressed("attack"):
		state_machine.transition_to("Attack")
		return

func get_transition() -> String:
	# Jump cancel
	if Input.is_action_just_pressed("space") and player.jump_count < player.max_jump_count:
		return "Air"

	# Dash cancel
	if (Input.is_action_just_pressed("f") or Input.is_action_just_pressed("dash")) and player.dash_count < player.max_dash_count:
		return "Dash"

	# Attack cancel
	if Input.is_action_just_pressed("attack"):
		return "Attack"

	# Airborne check
	if not player.is_on_floor():
		return "Air"

	# Guard break - stamina depleted while blocking
	if player.stamina_component and player.stamina_component.current_stamina < CombatData.STAMINA_DEPLETED_THRESHOLD:
		# Transition to stun state for guard break
		state_machine.transition_to("Stun", {
			"stun_type": "guard_break",
			"duration": CombatData.GUARD_BREAK_STUN
		})
		return ""

	# Release block
	if not Input.is_action_pressed("block"):
		if has_movement_input():
			return "Move"
		return "Idle"

	return ""

# Called by hurtbox when damage is blocked
func on_damage_blocked(damage: int, attacker_id: int, attack_name: String) -> void:
	was_hit = true

	# Get stamina cost based on attack type
	var stamina_cost = CombatData.get_block_stamina_cost(attack_name)

	# Drain stamina
	if player.stamina_component:
		player.stamina_component.spend(stamina_cost)

	# Apply posture damage (reduced since blocking)
	var posture_damage = CombatData.get_posture_damage_blocked(attack_name)
	if player.posture_component:
		player.posture_component.add_posture_damage(posture_damage)

	# Play deflect animation for visual feedback
	if player.animation_player and player.animation_player.has_animation("deflect"):
		player.animation_player.play("deflect")

	# Apply knockback (defender pushed)
	var knockback_dir = -player.global_transform.basis.z
	player.velocity += knockback_dir * CombatData.KNOCKBACK_BLOCKED

	# Spawn block sparks
	_spawn_block_sparks()

func _spawn_block_sparks() -> void:
	# Simple spark effect at sword position
	var sword_node = player.get_node_or_null("head/Sword")
	if sword_node:
		var spark_pos = sword_node.global_position
		# Could instantiate a spark particle here if we have one
		# For now, just visual feedback through animation

# Helper to check if player is blocking (for posture component)
func is_blocking() -> bool:
	return true
