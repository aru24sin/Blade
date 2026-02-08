class_name CombatData
extends RefCounted
## CombatData - Simplified combat system with 3 core attacks + posture system

# Attack categories
enum AttackCategory {
	LIGHT,
	HEAVY,
	THRUST,
	AERIAL
}

# Simplified attack database - only 7 attacks total
const ATTACKS = {
	# === LIGHT COMBO CHAIN (Click) ===
	"light_1": {
		"damage": 15,
		"posture_damage": 10,
		"posture_damage_blocked": 8,
		"stamina_cost": 8,
		"startup_time": 0.15,
		"active_time": 0.17,
		"recovery_time": 0.23,
		"hitstun": 0.25,
		"knockback": 5.0,
		"can_combo_to": ["light_2", "heavy"],
		"combo_window": 0.5,
		"animation": "slash_1",
		"category": AttackCategory.LIGHT,
		"movement_impulse": Vector3.ZERO,
		"hitbox_scale": Vector3(1.5, 0.5, 2.0),
		"hitbox_offset": Vector3(0, 0.8, -1.0),
		"hitstop": 0.04,
		"screen_shake": 0.3
	},
	"light_2": {
		"damage": 18,
		"posture_damage": 12,
		"posture_damage_blocked": 10,
		"stamina_cost": 8,
		"startup_time": 0.12,
		"active_time": 0.18,
		"recovery_time": 0.25,
		"hitstun": 0.3,
		"knockback": 6.0,
		"can_combo_to": ["light_3", "heavy"],
		"combo_window": 0.45,
		"animation": "slash_2",
		"category": AttackCategory.LIGHT,
		"movement_impulse": Vector3.ZERO,
		"hitbox_scale": Vector3(1.5, 0.5, 2.0),
		"hitbox_offset": Vector3(0, 0.8, -1.0),
		"hitstop": 0.04,
		"screen_shake": 0.3
	},
	"light_3": {
		"damage": 25,
		"posture_damage": 18,
		"posture_damage_blocked": 15,
		"stamina_cost": 10,
		"startup_time": 0.18,
		"active_time": 0.22,
		"recovery_time": 0.30,
		"hitstun": 0.4,
		"knockback": 10.0,
		"can_combo_to": [],
		"combo_window": 0.0,
		"animation": "slash_3",
		"category": AttackCategory.LIGHT,
		"movement_impulse": Vector3(0, 0, -2),
		"hitbox_scale": Vector3(1.8, 0.6, 2.2),
		"hitbox_offset": Vector3(0, 0.6, -1.2),
		"hitstop": 0.05,
		"screen_shake": 0.5
	},

	# === HEAVY ATTACK (Hold Click) ===
	"heavy": {
		"damage": 35,
		"posture_damage": 30,
		"posture_damage_blocked": 20,
		"stamina_cost": 18,
		"startup_time": 0.30,
		"active_time": 0.20,
		"recovery_time": 0.40,
		"hitstun": 0.6,
		"knockback": 12.0,
		"can_combo_to": [],
		"combo_window": 0.0,
		"animation": "overhead",
		"category": AttackCategory.HEAVY,
		"movement_impulse": Vector3(0, 0, -1),
		"hitbox_scale": Vector3(1.4, 2.0, 1.8),
		"hitbox_offset": Vector3(0, 1.2, -1.0),
		"hitstop": 0.07,
		"screen_shake": 0.8
	},

	# === THRUST ATTACK (W + Click) ===
	"thrust": {
		"damage": 22,
		"posture_damage": 15,
		"posture_damage_blocked": 12,
		"stamina_cost": 12,
		"startup_time": 0.20,
		"active_time": 0.18,
		"recovery_time": 0.27,
		"hitstun": 0.35,
		"knockback": 3.0,
		"can_combo_to": [],
		"combo_window": 0.0,
		"animation": "thrust",
		"category": AttackCategory.THRUST,
		"movement_impulse": Vector3(0, 0, -4),
		"hitbox_scale": Vector3(0.6, 0.6, 2.8),
		"hitbox_offset": Vector3(0, 0.8, -1.5),
		"hitstop": 0.05,
		"screen_shake": 0.4
	},

	# === AERIAL ATTACKS ===
	"air_light": {
		"damage": 15,
		"posture_damage": 10,
		"posture_damage_blocked": 8,
		"stamina_cost": 8,
		"startup_time": 0.08,
		"active_time": 0.15,
		"recovery_time": 0.15,
		"hitstun": 0.3,
		"knockback": 4.0,
		"can_combo_to": ["air_light"],
		"combo_window": 0.4,
		"animation": "air_slash",
		"category": AttackCategory.AERIAL,
		"movement_impulse": Vector3.ZERO,
		"hitbox_scale": Vector3(1.5, 0.5, 2.0),
		"hitbox_offset": Vector3(0, 0.5, -1.0),
		"preserve_momentum": 0.8,
		"hitstop": 0.03,
		"screen_shake": 0.3
	},
	"air_heavy": {
		"damage": 30,
		"posture_damage": 25,
		"posture_damage_blocked": 18,
		"stamina_cost": 15,
		"startup_time": 0.10,
		"active_time": 0.20,
		"recovery_time": 0.20,
		"hitstun": 0.5,
		"knockback": 8.0,
		"can_combo_to": [],
		"combo_window": 0.0,
		"animation": "air_slash_2",
		"category": AttackCategory.AERIAL,
		"movement_impulse": Vector3(0, -35, 0),
		"hitbox_scale": Vector3(1.5, 1.5, 1.5),
		"hitbox_offset": Vector3(0, 0, -0.5),
		"shockwave_radius": 2.0,
		"shockwave_damage": 12,
		"hitstop": 0.06,
		"screen_shake": 1.0
	}
}

# === POSTURE SYSTEM CONSTANTS ===
const MAX_POSTURE: float = 100.0
const POSTURE_BREAK_STUN: float = 1.5
const POSTURE_REGEN_IDLE: float = 12.0
const POSTURE_REGEN_BLOCKING: float = 8.0
const LOW_HP_THRESHOLD: float = 0.3  # Below 30% HP = recovery halved
const DEATHBLOW_HP_THRESHOLD: float = 0.5  # Below 50% HP = deathblow available
const DEATHBLOW_DAMAGE: int = 60
const PARRY_POSTURE_DAMAGE: float = 25.0  # Posture damage to attacker on parry

# === DEFENSE CONSTANTS ===
const PARRY_WINDOW: float = 0.2
const BLOCK_DAMAGE_REDUCTION: float = 0.7
const BLOCK_STAMINA_COST_LIGHT: float = 15.0
const BLOCK_STAMINA_COST_HEAVY: float = 25.0
const PARRY_STAMINA_COST: float = 12.0
const GUARD_BREAK_STUN: float = 1.0
const COUNTER_WINDOW: float = 0.6
const COUNTER_DAMAGE_MULT: float = 1.5
const BLOCK_MOVEMENT_MULT: float = 0.5

# === STAMINA CONSTANTS ===
const STAMINA_MAX: float = 100.0
const STAMINA_REGEN: float = 30.0
const STAMINA_REGEN_DELAY: float = 0.4
const STAMINA_DEPLETED_THRESHOLD: float = 5.0  # Can't block/parry/heavy below this

# === HITSTOP & GAME FEEL ===
const HITSTOP_PARRY: float = 0.05
const HITSTOP_BREAK: float = 0.12
const PARRY_SLOWMO_DURATION: float = 0.08
const SCREEN_SHAKE_PARRY: float = 0.5
const SCREEN_SHAKE_BREAK: float = 1.5

# === KNOCKBACK ===
const KNOCKBACK_BLOCKED: float = 4.0
const KNOCKBACK_PARRY: float = 8.0

# === STUN DURATIONS ===
const PARRIED_STUN_DURATION: float = 0.4
const HIT_STUN_BASE: float = 0.3

# Movement in combat
const ATTACK_MOVEMENT_SPEED: float = 12.0

# Static helper functions
static func get_attack(attack_name: String) -> Dictionary:
	if ATTACKS.has(attack_name):
		return ATTACKS[attack_name].duplicate()
	return {}

static func get_damage(attack_name: String) -> int:
	var attack = get_attack(attack_name)
	return attack.get("damage", 0)

static func get_posture_damage(attack_name: String) -> float:
	var attack = get_attack(attack_name)
	return attack.get("posture_damage", 0.0)

static func get_posture_damage_blocked(attack_name: String) -> float:
	var attack = get_attack(attack_name)
	return attack.get("posture_damage_blocked", 0.0)

static func get_stamina_cost(attack_name: String) -> float:
	var attack = get_attack(attack_name)
	return attack.get("stamina_cost", 0.0)

static func get_total_duration(attack_name: String) -> float:
	var attack = get_attack(attack_name)
	return attack.get("startup_time", 0) + attack.get("active_time", 0) + attack.get("recovery_time", 0)

static func can_combo_to(from_attack: String, to_attack: String) -> bool:
	var attack = get_attack(from_attack)
	var combo_options = attack.get("can_combo_to", [])
	return to_attack in combo_options

static func get_animation_name(attack_name: String) -> String:
	var attack = get_attack(attack_name)
	return attack.get("animation", "")

static func get_movement_impulse(attack_name: String) -> Vector3:
	var attack = get_attack(attack_name)
	return attack.get("movement_impulse", Vector3.ZERO)

static func get_hitbox_scale(attack_name: String) -> Vector3:
	var attack = get_attack(attack_name)
	return attack.get("hitbox_scale", Vector3(1.5, 0.5, 2.0))

static func get_hitbox_offset(attack_name: String) -> Vector3:
	var attack = get_attack(attack_name)
	return attack.get("hitbox_offset", Vector3(0, 0.8, -1.0))

static func is_aerial_attack(attack_name: String) -> bool:
	var attack = get_attack(attack_name)
	return attack.get("category", -1) == AttackCategory.AERIAL

static func get_combo_options(attack_name: String) -> Array:
	var attack = get_attack(attack_name)
	return attack.get("can_combo_to", [])

static func get_hitstop(attack_name: String) -> float:
	var attack = get_attack(attack_name)
	return attack.get("hitstop", 0.03)

static func get_screen_shake(attack_name: String) -> float:
	var attack = get_attack(attack_name)
	return attack.get("screen_shake", 0.3)

static func get_knockback(attack_name: String) -> float:
	var attack = get_attack(attack_name)
	return attack.get("knockback", 5.0)

static func get_block_stamina_cost(attack_name: String) -> float:
	var attack = get_attack(attack_name)
	if attack.get("category", -1) == AttackCategory.HEAVY:
		return BLOCK_STAMINA_COST_HEAVY
	return BLOCK_STAMINA_COST_LIGHT

# Input helpers for simplified attack selection
static func get_attack_for_input(is_holding: bool, is_forward: bool, is_airborne: bool) -> String:
	if is_airborne:
		return "air_heavy" if is_holding else "air_light"
	if is_forward:
		return "thrust"
	if is_holding:
		return "heavy"
	return "light_1"

static func get_next_combo_attack(current_attack: String) -> String:
	var combo_options = get_combo_options(current_attack)
	if combo_options.is_empty():
		return ""
	# Return the first light attack in combo, not heavy
	for option in combo_options:
		if option.begins_with("light"):
			return option
	return combo_options[0]
