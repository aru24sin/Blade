class_name HurtboxComponent
extends Area3D
## HurtboxComponent - Receives damage and posture damage from hitboxes

signal damage_received(amount: int, attacker_id: int, attack_name: String)
signal blocked(amount: int, attacker_id: int, attack_name: String)
signal parried(attacker_id: int, attack_name: String)
signal posture_damage_received(amount: float)

@export var owner_id: int = 0

var is_blocking: bool = false
var is_parrying: bool = false
var is_invincible: bool = false

# Reference to owner player for state access
var owner_player: Node = null

func _ready() -> void:
	monitoring = false
	monitorable = true
	collision_layer = 2  # Hurtbox layer
	collision_mask = 0
	owner_player = get_parent()

func set_blocking(blocking: bool) -> void:
	is_blocking = blocking
	if not blocking:
		is_parrying = false

func set_parrying(parrying: bool) -> void:
	is_parrying = parrying

func set_invincible(invincible: bool) -> void:
	is_invincible = invincible

func receive_hit(hitbox: HitboxComponent) -> Dictionary:
	var result = {
		"hit": true,
		"damage": 0,
		"posture_damage": 0.0,
		"parried": false,
		"blocked": false
	}

	if is_invincible:
		result.hit = false
		return result

	var attack_name = hitbox.current_attack_type
	var posture_dmg = hitbox.posture_damage

	# === PARRY ===
	if is_parrying:
		result.parried = true
		result.damage = 0
		result.posture_damage = 0
		parried.emit(hitbox.owner_id, attack_name)
		return result

	# === BLOCK ===
	if is_blocking:
		var reduced_damage = int(hitbox.current_damage * (1.0 - CombatData.BLOCK_DAMAGE_REDUCTION))
		var blocked_posture = CombatData.get_posture_damage_blocked(attack_name)

		result.blocked = true
		result.damage = reduced_damage
		result.posture_damage = blocked_posture

		# Apply posture damage to owner
		_apply_posture_damage(blocked_posture)

		# Emit signals
		blocked.emit(reduced_damage, hitbox.owner_id, attack_name)
		damage_received.emit(reduced_damage, hitbox.owner_id, attack_name)

		# Notify block state
		_notify_block_state(reduced_damage, hitbox.owner_id, attack_name)

		return result

	# === FULL HIT ===
	var full_posture = CombatData.get_posture_damage(attack_name)

	result.damage = hitbox.current_damage
	result.posture_damage = full_posture

	# Apply posture damage
	_apply_posture_damage(full_posture)

	# Emit signal
	damage_received.emit(hitbox.current_damage, hitbox.owner_id, attack_name)
	posture_damage_received.emit(full_posture)

	# Pause posture regen during hitstun
	if owner_player and owner_player.posture_component:
		owner_player.posture_component.pause_regen()

	return result

func _apply_posture_damage(amount: float) -> void:
	if owner_player and owner_player.posture_component:
		owner_player.posture_component.add_posture_damage(amount)

func _notify_block_state(damage: int, attacker_id: int, attack_name: String) -> void:
	# Find block state and notify it
	if owner_player and owner_player.state_machine:
		var current_state = owner_player.state_machine.current_state
		if current_state and current_state.has_method("on_damage_blocked"):
			current_state.on_damage_blocked(damage, attacker_id, attack_name)

# Called when player takes damage (for external use)
func receive_damage(damage: int, attacker_id: int) -> void:
	if is_invincible:
		return

	if is_blocking:
		var reduced_damage = int(damage * (1.0 - CombatData.BLOCK_DAMAGE_REDUCTION))
		blocked.emit(reduced_damage, attacker_id, "")
		damage_received.emit(reduced_damage, attacker_id, "")
	else:
		damage_received.emit(damage, attacker_id, "")
