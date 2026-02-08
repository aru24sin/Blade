class_name HitboxComponent
extends Area3D
## HitboxComponent - Deals damage and posture damage when overlapping with hurtboxes

signal hit_landed(hurtbox: Node, damage: int, was_blocked: bool)

@export var base_damage: int = 0
@export var owner_id: int = 0  # Multiplayer peer ID

var is_active: bool = false
var current_damage: int = 0
var current_attack_type: String = ""
var posture_damage: float = 10.0  # Set by attack_state
var hit_targets: Array = []
var collision_shape: CollisionShape3D
var default_shape_size: Vector3 = Vector3(1.5, 0.5, 2.0)
var default_position: Vector3 = Vector3(0, 0, 0)

# Reference to owner player for knockback direction
var owner_player: Node = null

func _ready() -> void:
	monitoring = false
	monitorable = false
	collision_layer = 0
	collision_mask = 2  # Hurtbox layer

	area_entered.connect(_on_area_entered)

	# Cache collision shape reference
	collision_shape = get_node_or_null("CollisionShape3D")
	if collision_shape:
		default_position = collision_shape.position
		if collision_shape.shape is BoxShape3D:
			default_shape_size = (collision_shape.shape as BoxShape3D).size

	# Get owner player
	owner_player = get_parent()

func activate(damage: int, attack_type: String, attacker_id: int) -> void:
	current_damage = damage
	current_attack_type = attack_type
	owner_id = attacker_id
	is_active = true
	hit_targets.clear()
	monitoring = true

func activate_with_shape(damage: int, attack_type: String, attacker_id: int, hitbox_size: Vector3, hitbox_offset: Vector3) -> void:
	# Update hitbox shape and position for this attack
	if collision_shape:
		if collision_shape.shape is BoxShape3D:
			var box = collision_shape.shape as BoxShape3D
			box.size = hitbox_size
		collision_shape.position = hitbox_offset

	# Call regular activate
	activate(damage, attack_type, attacker_id)

func deactivate() -> void:
	is_active = false
	monitoring = false
	current_damage = 0
	current_attack_type = ""
	posture_damage = 10.0
	hit_targets.clear()

	# Reset hitbox to default size
	if collision_shape:
		if collision_shape.shape is BoxShape3D:
			var box = collision_shape.shape as BoxShape3D
			box.size = default_shape_size
		collision_shape.position = default_position

func _on_area_entered(area: Area3D) -> void:
	if not is_active:
		return

	if area is HurtboxComponent:
		var hurtbox = area as HurtboxComponent

		# Don't hit yourself
		if hurtbox.owner_id == owner_id:
			return

		# Don't hit same target twice in one attack
		if hurtbox in hit_targets:
			return

		hit_targets.append(hurtbox)

		# Let the hurtbox handle the hit
		var hit_result = hurtbox.receive_hit(self)

		# Check if it was blocked or parried
		var was_blocked = hit_result.get("blocked", false)
		var was_parried = hit_result.get("parried", false)

		# Emit signal for attack state
		hit_landed.emit(hurtbox, current_damage, was_blocked)

		# Apply knockback to target
		_apply_knockback_to_target(hurtbox, was_blocked)

		# Spawn appropriate effect
		if was_parried:
			# Parry spark handled by parry state
			pass
		elif was_blocked:
			_spawn_block_spark(hurtbox.global_position)
		else:
			_spawn_hit_spark(hurtbox.global_position)

		# Apply game feel effects
		HitFeedback.on_hit_landed(current_attack_type, was_blocked)

func _apply_knockback_to_target(hurtbox: HurtboxComponent, was_blocked: bool) -> void:
	var target_player = hurtbox.get_parent()
	if not target_player or not target_player.has_method("apply_knockback"):
		return

	var knockback_force = CombatData.get_knockback(current_attack_type)
	if was_blocked:
		knockback_force = CombatData.KNOCKBACK_BLOCKED

	# Direction from attacker to target
	var knockback_dir = Vector3.ZERO
	if owner_player:
		knockback_dir = (target_player.global_position - owner_player.global_position).normalized()
		knockback_dir.y = 0

	target_player.apply_knockback(knockback_dir * knockback_force)

func _spawn_hit_spark(hit_pos: Vector3) -> void:
	var scene_root = get_tree().current_scene
	if scene_root:
		HitSpark.spawn_at(scene_root, hit_pos)

func _spawn_block_spark(hit_pos: Vector3) -> void:
	var scene_root = get_tree().current_scene
	if scene_root:
		# Use same hit spark but could be different color
		HitSpark.spawn_at(scene_root, hit_pos)

# Get attack data for the current attack
func get_current_attack_data() -> Dictionary:
	return CombatData.get_attack(current_attack_type)
