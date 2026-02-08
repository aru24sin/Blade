class_name AttackState
extends PlayerState
## AttackState - Simplified 3-attack system: Light (click), Heavy (hold), Thrust (W+click)

enum Phase { STARTUP, ACTIVE, RECOVERY }

var current_attack: String = ""
var current_phase: Phase = Phase.STARTUP
var phase_timer: float = 0.0
var attack_data: Dictionary = {}
var combo_buffer: bool = false  # Just tracks if player pressed attack during combo window
var combo_window_timer: float = 0.0
var can_combo: bool = false
var applied_impulse: bool = false
var combo_index: int = 0  # Track which attack in combo (0, 1, 2)


# Air slam specific
var is_slamming: bool = false

# Slash trail
var slash_trail: SlashTrail = null
var second_slash_trail: SlashTrail = null  # For dual wielding

func enter(msg: Dictionary = {}) -> void:
	# Reset state
	applied_impulse = false
	is_slamming = false

	# Determine attack type based on combo index
	if msg.has("combo_index"):
		combo_index = msg.get("combo_index")
	elif msg.has("attack_type"):
		# Legacy support
		current_attack = msg.get("attack_type")
		combo_index = 0
	else:
		# New attack - reset combo
		combo_index = 0

	current_attack = _get_attack_from_combo_index()

	attack_data = CombatData.get_attack(current_attack)

	if attack_data.is_empty():
		state_machine.transition_to("Idle")
		return

	# Check stamina
	var stamina_cost = attack_data.get("stamina_cost", 0.0)
	if player.stamina_component and not player.stamina_component.can_spend(stamina_cost):
		state_machine.transition_to("Idle")
		return

	# Spend stamina
	if player.stamina_component:
		player.stamina_component.spend(stamina_cost)

	# Initialize phase
	current_phase = Phase.STARTUP
	phase_timer = _get_scaled_time(attack_data.get("startup_time", 0.1))
	combo_buffer = false
	combo_window_timer = 0.0
	can_combo = false

	# Play animation
	_play_attack_animation()

	# Sync over network
	if player.is_multiplayer_authority():
		_sync_attack_start.rpc(current_attack)

@rpc("any_peer", "call_local", "reliable")
func _sync_attack_start(attack_name: String) -> void:
	if not player.is_multiplayer_authority():
		current_attack = attack_name
		attack_data = CombatData.get_attack(current_attack)
		_play_attack_animation()

func _get_attack_from_combo_index() -> String:
	# Simple combo chain based on index - same combo works on ground and in air
	match combo_index:
		0:
			return "light_1"
		1:
			return "light_2"
		2:
			return "light_3"
		_:
			return "light_1"

func physics_update(delta: float) -> void:
	phase_timer -= delta

	match current_phase:
		Phase.STARTUP:
			if phase_timer <= 0:
				_enter_active_phase()

		Phase.ACTIVE:
			# Special handling for air slam
			if current_attack == "air_heavy" and is_slamming:
				if player.is_on_floor():
					_on_slam_landed()
					_enter_recovery_phase()
			elif phase_timer <= 0:
				_enter_recovery_phase()

		Phase.RECOVERY:
			if combo_window_timer > 0:
				combo_window_timer -= delta
				can_combo = true  # Can combo during the combo window
			if phase_timer <= 0 and combo_window_timer <= 0:
				can_combo = false  # Combo window expired

	# Apply movement impulse at start of active phase
	if current_phase == Phase.ACTIVE and not applied_impulse:
		_apply_attack_movement()
		applied_impulse = true

	# Movement during attack
	var direction = get_input_direction()
	var move_speed = player.base_speed * player.speed_multiplier

	# Air slam overrides movement
	if is_slamming:
		player.velocity.y = attack_data.get("movement_impulse", Vector3.ZERO).y
		player.velocity.x *= 0.95
		player.velocity.z *= 0.95
	else:
		apply_movement(direction, move_speed)
		apply_gravity(delta)

	player.move_and_slide()

	# Update slash trail
	if current_phase == Phase.ACTIVE and slash_trail:
		_update_slash_trail()

func handle_input(event: InputEvent) -> void:
	# Jump cancel - always available
	if event.is_action_pressed("space") and player.jump_count < player.max_jump_count:
		state_machine.transition_to("Air")
		return

	# Dash cancel - always available
	if (event.is_action_pressed("f") or event.is_action_pressed("dash")) and player.dash_count < player.max_dash_count:
		state_machine.transition_to("Dash")
		return

	# Combo buffering - can buffer during any phase
	if event.is_action_pressed("attack"):
		_buffer_next_attack()

func _enter_active_phase() -> void:
	current_phase = Phase.ACTIVE

	# Special handling for air heavy (slam)
	if current_attack == "air_heavy":
		phase_timer = 999.0  # Until landing
		is_slamming = true
	else:
		phase_timer = _get_scaled_time(attack_data.get("active_time", 0.12))

	# Activate hitbox with proper sizing
	if player.hitbox:
		var damage = int(attack_data.get("damage", 15) * player.damage_multiplier)
		var posture_damage = attack_data.get("posture_damage", 10.0)
		var hitbox_scale = attack_data.get("hitbox_scale", Vector3(1.5, 0.5, 2.0))
		var hitbox_offset = attack_data.get("hitbox_offset", Vector3(0, 0.8, -1.0))
		player.hitbox.activate_with_shape(damage, current_attack, player.peer_id, hitbox_scale, hitbox_offset)
		player.hitbox.posture_damage = posture_damage

	# Screen shake on attack start
	var shake_intensity = attack_data.get("screen_shake", 0.3)
	if player.is_local_player:
		HitFeedback.apply_shake(shake_intensity * 0.5)  # Lighter shake on swing, heavier on hit

	# Start slash trail
	_start_slash_trail()

func _enter_recovery_phase() -> void:
	current_phase = Phase.RECOVERY
	phase_timer = _get_scaled_time(attack_data.get("recovery_time", 0.15))
	combo_window_timer = attack_data.get("combo_window", 0.4)
	is_slamming = false

	# Deactivate hitbox
	if player.hitbox:
		player.hitbox.deactivate()

	# Stop slash trail
	_stop_slash_trail()

func _apply_attack_movement() -> void:
	var impulse = attack_data.get("movement_impulse", Vector3.ZERO)
	if impulse != Vector3.ZERO:
		# Rotate impulse to player's facing direction
		var rotated = impulse.rotated(Vector3.UP, player.rotation.y)
		player.velocity += rotated

func _buffer_next_attack() -> void:
	# Simple combo - just mark that player wants to continue combo
	combo_buffer = true

func _on_slam_landed() -> void:
	# Shockwave damage
	var shockwave_radius = attack_data.get("shockwave_radius", 0.0)
	var shockwave_damage = attack_data.get("shockwave_damage", 0)

	if shockwave_radius > 0 and shockwave_damage > 0:
		_create_shockwave(shockwave_radius, int(shockwave_damage * player.damage_multiplier))

	# Screen shake for landing
	if player.has_method("apply_screen_shake"):
		player.apply_screen_shake(attack_data.get("screen_shake", 1.0))

func _create_shockwave(radius: float, damage: int) -> void:
	# Find all hurtboxes in radius
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

func _get_scaled_time(base_time: float) -> float:
	return base_time / player.attack_speed_multiplier

func _start_slash_trail() -> void:
	slash_trail = SlashTrail.new()
	slash_trail.trail_color = Color(0.9, 0.95, 1.0, 0.8)
	slash_trail.trail_width = 0.15
	get_tree().current_scene.add_child(slash_trail)
	slash_trail.start_trail()

	# Start second trail for dual wielding
	if player.is_dual_wield_active():
		second_slash_trail = SlashTrail.new()
		second_slash_trail.trail_color = Color(1.0, 0.85, 0.95, 0.8)  # Slightly pink tint
		second_slash_trail.trail_width = 0.15
		get_tree().current_scene.add_child(second_slash_trail)
		second_slash_trail.start_trail()

func _stop_slash_trail() -> void:
	if slash_trail:
		slash_trail.stop_trail()
		slash_trail = null
	if second_slash_trail:
		second_slash_trail.stop_trail()
		second_slash_trail = null

func _update_slash_trail() -> void:
	# Update main sword trail
	if slash_trail and player.main_sword:
		var sword_transform = player.main_sword.global_transform
		var tip_pos = sword_transform.origin + sword_transform.basis.z * -1.4
		var base_pos = sword_transform.origin
		slash_trail.add_point(tip_pos, base_pos)

	# Update second sword trail for dual wielding
	if second_slash_trail and player.second_sword and player.is_dual_wield_active():
		var sword_transform = player.second_sword.global_transform
		var tip_pos = sword_transform.origin + sword_transform.basis.z * -1.4
		var base_pos = sword_transform.origin
		second_slash_trail.add_point(tip_pos, base_pos)

func _play_attack_animation() -> void:
	var anim_name = attack_data.get("animation", "slash_1")

	if player.animation_player:
		player.animation_player.speed_scale = player.attack_speed_multiplier

		# Use dual sword animations if dual wielding
		if player.is_dual_wield_active():
			anim_name = _get_dual_sword_animation(anim_name)

		# Stop current animation and play from beginning to ensure combo animations work
		player.animation_player.stop()

		if player.animation_player.has_animation(anim_name):
			player.animation_player.play(anim_name)
		else:
			# Fallback animations
			var fallback = anim_name
			match current_attack:
				"light_1", "air_light":
					fallback = "dual_slash_1" if player.is_dual_wield_active() else "slash_1"
				"light_2":
					fallback = "dual_slash_2" if player.is_dual_wield_active() else "slash_2"
				"light_3":
					fallback = "dual_slash_3" if player.is_dual_wield_active() else "slash_3"
				"heavy", "air_heavy":
					fallback = "overhead"
				"thrust":
					fallback = "thrust"
				_:
					fallback = "dual_slash_1" if player.is_dual_wield_active() else "slash_1"
			player.animation_player.play(fallback)

func _get_dual_sword_animation(base_anim: String) -> String:
	# Map standard animations to dual sword variants
	match base_anim:
		"slash_1":
			return "dual_slash_1"
		"slash_2":
			return "dual_slash_2"
		"slash_3":
			return "dual_slash_3"
		_:
			return base_anim

func exit() -> void:
	# Ensure hitbox is deactivated
	if player.hitbox:
		player.hitbox.deactivate()

	# Stop slash trail
	_stop_slash_trail()

	# Reset animation speed
	if player.animation_player:
		player.animation_player.speed_scale = 1.0

	current_attack = ""
	combo_buffer = false
	can_combo = false
	is_slamming = false

func get_transition() -> String:
	# Jump cancel
	if Input.is_action_just_pressed("space") and player.jump_count < player.max_jump_count:
		return "Air"

	# Dash cancel
	if (Input.is_action_just_pressed("f") or Input.is_action_just_pressed("dash")) and player.dash_count < player.max_dash_count:
		return "Dash"

	# Execute buffered combo - can execute at end of active phase or during recovery/combo window
	var can_execute_combo = (current_phase == Phase.RECOVERY) or (current_phase == Phase.ACTIVE and phase_timer <= 0)
	if can_execute_combo and combo_buffer:
		# Advance to next attack in combo (wrap around after light_3)
		var next_index = (combo_index + 1) % 3
		state_machine.transition_to("Attack", {"combo_index": next_index})
		return ""

	# Attack finished - only exit if recovery done and combo window expired
	if current_phase == Phase.RECOVERY and phase_timer <= 0 and combo_window_timer <= 0:
		if not player.is_on_floor():
			return "Air"
		if has_movement_input():
			return "Move"
		return "Idle"

	return ""
