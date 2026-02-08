class_name StunState
extends PlayerState
## StunState - Player is stunned (parried, guard broken, posture broken, or hit)

enum StunType {
	HIT,
	PARRIED,
	GUARD_BREAK,
	POSTURE_BREAK
}

var stun_timer: float = 0.0
var stun_type: StunType = StunType.HIT
var is_deathblow_vulnerable: bool = false

func enter(msg: Dictionary = {}) -> void:
	var type_str = msg.get("stun_type", "hit")
	stun_type = _parse_stun_type(type_str)
	stun_timer = msg.get("duration", CombatData.HIT_STUN_BASE)
	is_deathblow_vulnerable = false

	# Deactivate hitbox if we were attacking
	if player.hitbox:
		player.hitbox.deactivate()

	# Deactivate blocking/parrying
	if player.hurtbox:
		player.hurtbox.set_blocking(false)
		player.hurtbox.set_parrying(false)

	# Apply knockback if provided
	var knockback = msg.get("knockback", Vector3.ZERO)
	if knockback != Vector3.ZERO:
		player.velocity += knockback

	# Pause posture regen during stun
	if player.posture_component:
		player.posture_component.pause_regen()

	# Handle different stun types
	match stun_type:
		StunType.PARRIED:
			_on_parried_stun()
		StunType.GUARD_BREAK:
			_on_guard_break()
		StunType.POSTURE_BREAK:
			_on_posture_break()
		_:
			_on_hit_stun()

	# Sync over network
	if player.is_multiplayer_authority():
		_sync_stun_start.rpc(type_str, stun_timer)

@rpc("any_peer", "call_local", "reliable")
func _sync_stun_start(type_str: String, duration: float) -> void:
	if not player.is_multiplayer_authority():
		stun_type = _parse_stun_type(type_str)
		stun_timer = duration
		if player.animation_player:
			player.animation_player.stop()

func _parse_stun_type(type_str: String) -> StunType:
	match type_str:
		"parried":
			return StunType.PARRIED
		"guard_break":
			return StunType.GUARD_BREAK
		"posture_break":
			return StunType.POSTURE_BREAK
		_:
			return StunType.HIT

func _on_hit_stun() -> void:
	# Standard hit stun - short duration
	if player.animation_player:
		player.animation_player.stop()

func _on_parried_stun() -> void:
	# Parried - medium duration, attacker gets counter window
	if player.animation_player:
		player.animation_player.stop()

func _on_guard_break() -> void:
	# Guard broken - staggered from stamina depletion
	stun_timer = CombatData.GUARD_BREAK_STUN
	if player.animation_player:
		player.animation_player.stop()
	# Could play guard break animation here

func _on_posture_break() -> void:
	# Posture broken - long stun, vulnerable to deathblow
	stun_timer = CombatData.POSTURE_BREAK_STUN
	is_deathblow_vulnerable = true

	# Apply game feel
	HitFeedback.on_posture_break()

	if player.animation_player:
		player.animation_player.stop()
	# Could play posture break animation (kneeling, etc.)

func physics_update(delta: float) -> void:
	stun_timer -= delta

	# Can't control during stun, but still affected by physics
	apply_gravity(delta)

	# Slow down horizontal velocity (friction)
	player.velocity.x = lerp(player.velocity.x, 0.0, 0.15)
	player.velocity.z = lerp(player.velocity.z, 0.0, 0.15)

	player.move_and_slide()

func handle_input(_event: InputEvent) -> void:
	# No input during stun
	pass

func exit() -> void:
	# Resume posture regen
	if player.posture_component:
		player.posture_component.resume_regen()

		# Reset posture if we were posture broken
		if stun_type == StunType.POSTURE_BREAK:
			player.posture_component.recover_from_break()

	is_deathblow_vulnerable = false

	# Sync over network
	if player.is_multiplayer_authority():
		_sync_stun_end.rpc()

@rpc("any_peer", "call_local", "reliable")
func _sync_stun_end() -> void:
	pass  # Remote players will handle their own state transitions

func get_transition() -> String:
	if stun_timer <= 0:
		if not player.is_on_floor():
			return "Air"
		if has_movement_input():
			return "Move"
		return "Idle"

	return ""

# Called when player receives a deathblow attack while posture broken
func receive_deathblow(attacker_id: int) -> bool:
	if not is_deathblow_vulnerable:
		return false

	# Check if player HP is below threshold for instant kill
	var hp_percent = player.current_health / float(player.max_health)
	if hp_percent <= CombatData.DEATHBLOW_HP_THRESHOLD:
		# Instant kill
		player.take_damage(player.current_health, attacker_id)
		return true
	else:
		# High damage
		player.take_damage(CombatData.DEATHBLOW_DAMAGE, attacker_id)
		return true
