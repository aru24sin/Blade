extends Area3D
## Kunai - Throwable projectile that deals damage

@export var speed: float = 50.0
@export var damage: int = 25
@export var max_distance: float = 30.0
@export var owner_id: int = 0

var direction: Vector3 = Vector3.FORWARD
var traveled_distance: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	var move_amount = speed * delta
	global_position += direction * move_amount
	traveled_distance += move_amount

	if traveled_distance >= max_distance:
		queue_free()

func setup(throw_direction: Vector3, thrower_id: int, throw_damage: int = 25) -> void:
	direction = throw_direction.normalized()
	owner_id = thrower_id
	damage = throw_damage

	# Rotate to face direction
	look_at(global_position + direction)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		var body_peer_id = 0
		if "peer_id" in body:
			body_peer_id = body.peer_id

		# Don't hit the thrower
		if body_peer_id == owner_id:
			return

		# Deal damage
		if body.has_method("take_damage"):
			body.take_damage(damage, owner_id)

		queue_free()
	else:
		# Hit environment
		queue_free()

func _on_area_entered(area: Area3D) -> void:
	# Could hit hurtbox directly
	if area is HurtboxComponent:
		if area.owner_id != owner_id:
			area.damage_received.emit(damage, owner_id)
			queue_free()
