class_name ParryState
extends PlayerState
## ParryState - Tap to parry with 0.2s window, staggers attacker and deals posture damage

var parry_timer: float = 0.0
var parry_successful: bool = false
var counter_available: bool = false
var counter_timer: float = 0.0

func enter(_msg: Dictionary = {}) -> void:
	parry_timer = CombatData.PARRY_WINDOW
	parry_successful = false
	counter_available = false
	counter_timer = 0.0

	# Check stamina - can't parry if depleted
	if player.stamina_component and player.stamina_component.current_stamina < CombatData.STAMINA_DEPLETED_THRESHOLD:
		state_machine.transition_to("Idle")
		return

	# Spend stamina for parry attempt
	if player.stamina_component:
		player.stamina_component.spend(CombatData.PARRY_STAMINA_COST)

	# Set hurtbox to parry mode
	if player.hurtbox:
		player.hurtbox.set_parrying(true)
		player.hurtbox.parried.connect(_on_parry_success)

	# Play parry startup animation
	if player.animation_player:
		player.animation_player.play("block")

	# Sync over network
	if player.is_multiplayer_authority():
		_sync_parry_start.rpc()

@rpc("any_peer", "call_local", "reliable")
func _sync_parry_start() -> void:
	if not player.is_multiplayer_authority():
		if player.hurtbox:
			player.hurtbox.set_parrying(true)
		if player.animation_player:
			player.animation_player.play("block")

func physics_update(delta: float) -> void:
	if not parry_successful:
		parry_timer -= delta

		# End parry window - failed if no parry
		if parry_timer <= 0:
			if player.hurtbox:
				player.hurtbox.set_parrying(false)
	else:
		# Parry was successful, count down counter window
		counter_timer -= delta

	# Reduced movement during parry
	var direction = get_input_direction()
	var move_speed = player.base_speed * CombatData.BLOCK_MOVEMENT_MULT
	apply_movement(direction, move_speed)
	apply_gravity(delta)
	player.move_and_slide()

func handle_input(event: InputEvent) -> void:
	# Jump cancel
	if event.is_action_pressed("space") and player.jump_count < player.max_jump_count:
		state_machine.transition_to("Air")
		return

	# Dash cancel
	if (event.is_action_pressed("f") or event.is_action_pressed("dash")) and player.dash_count < player.max_dash_count:
		state_machine.transition_to("Dash")
		return

	# Counter attack after successful parry (bonus damage)
	if counter_available and event.is_action_pressed("attack"):
		state_machine.transition_to("Attack", {
			"attack_type": "light_1",
			"is_counter": true
		})
		return

func _on_parry_success(attacker_id: int, attack_name: String) -> void:
	parry_successful = true
	counter_available = true
	counter_timer = CombatData.COUNTER_WINDOW

	# Play deflect animation
	if player.animation_player and player.animation_player.has_animation("deflect"):
		player.animation_player.play("deflect")

	# Apply posture damage to attacker
	var attacker = _get_player_by_id(attacker_id)
	if attacker:
		# Stun the attacker
		if attacker.has_method("apply_parry_stun"):
			attacker.apply_parry_stun()

		# Deal posture damage to attacker
		if attacker.posture_component:
			attacker.posture_component.add_posture_damage(CombatData.PARRY_POSTURE_DAMAGE)

		# Push attacker back
		var push_dir = (attacker.global_position - player.global_position).normalized()
		push_dir.y = 0
		attacker.velocity += push_dir * CombatData.KNOCKBACK_PARRY

	# Spawn parry spark effect
	_spawn_parry_spark()

	# Apply hitstop for juicy feel
	if player.has_method("apply_hitstop"):
		player.apply_hitstop(CombatData.HITSTOP_PARRY)

	# Screen shake
	if player.has_method("apply_screen_shake"):
		player.apply_screen_shake(CombatData.SCREEN_SHAKE_PARRY)

	# Brief slowmo for parry emphasis
	_apply_parry_slowmo()

	# Sync over network
	if player.is_multiplayer_authority():
		_sync_parry_success.rpc(attacker_id)

@rpc("any_peer", "call_local", "reliable")
func _sync_parry_success(attacker_id: int) -> void:
	if not player.is_multiplayer_authority():
		parry_successful = true
		if player.animation_player and player.animation_player.has_animation("deflect"):
			player.animation_player.play("deflect")
		_spawn_parry_spark()

func _spawn_parry_spark() -> void:
	var sword_node = player.get_node_or_null("head/Sword")
	if not sword_node:
		return

	# Try to spawn parry spark effect
	var spark_scene = load("res://src/effects/parry_spark.tscn")
	if spark_scene:
		var spark = spark_scene.instantiate()
		get_tree().current_scene.add_child(spark)
		spark.global_position = sword_node.global_position

func _apply_parry_slowmo() -> void:
	# Brief time slowdown for emphasis
	Engine.time_scale = 0.2
	await get_tree().create_timer(CombatData.PARRY_SLOWMO_DURATION * 0.2).timeout
	Engine.time_scale = 1.0

func _get_player_by_id(peer_id: int) -> Node:
	# Try PlayerRegistry first
	if Engine.has_singleton("PlayerRegistry"):
		var registry = Engine.get_singleton("PlayerRegistry")
		if registry.has_method("get_player"):
			return registry.get_player(peer_id)

	# Fallback: search for player in scene
	var players = get_tree().get_nodes_in_group("players")
	for p in players:
		if p.get("peer_id") == peer_id:
			return p
	return null

func exit() -> void:
	if player.hurtbox:
		player.hurtbox.set_parrying(false)
		if player.hurtbox.parried.is_connected(_on_parry_success):
			player.hurtbox.parried.disconnect(_on_parry_success)

	# Reset stance unless going to block
	if player.animation_player and not Input.is_action_pressed("block"):
		player.animation_player.play("RESET")

	parry_successful = false
	counter_available = false

	# Ensure time scale is reset
	Engine.time_scale = 1.0

	# Sync over network
	if player.is_multiplayer_authority():
		_sync_parry_end.rpc()

@rpc("any_peer", "call_local", "reliable")
func _sync_parry_end() -> void:
	if not player.is_multiplayer_authority():
		if player.hurtbox:
			player.hurtbox.set_parrying(false)

func get_transition() -> String:
	# Jump cancel
	if Input.is_action_just_pressed("space") and player.jump_count < player.max_jump_count:
		return "Air"

	# Dash cancel
	if (Input.is_action_just_pressed("f") or Input.is_action_just_pressed("dash")) and player.dash_count < player.max_dash_count:
		return "Dash"

	if not player.is_on_floor():
		return "Air"

	# Counter window expired after successful parry
	if parry_successful and counter_timer <= 0:
		if Input.is_action_pressed("block"):
			return "Block"
		if has_movement_input():
			return "Move"
		return "Idle"

	# Parry window ended without success
	if not parry_successful and parry_timer <= 0:
		# If still holding block, transition to block state
		if Input.is_action_pressed("block"):
			return "Block"
		if has_movement_input():
			return "Move"
		return "Idle"

	return ""
