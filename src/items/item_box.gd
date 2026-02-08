extends Area3D
## ItemBox - Mystery box that gives random items when collected

signal item_collected(collector_peer_id: int, item_type: String)

const ITEM_POOL = [
	{ "type": "speed_boost", "weight": 20 },
	{ "type": "damage_boost", "weight": 15 },
	{ "type": "shield", "weight": 15 },
	{ "type": "health_restore", "weight": 20 },
	{ "type": "kunai", "weight": 15 },
	{ "type": "smoke_bomb", "weight": 10 },
	{ "type": "dual_swords", "weight": 5 }
]

@export var respawn_time: float = 15.0
@export var spin_speed: float = 2.0

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var respawn_timer: Timer = $RespawnTimer

var is_active: bool = true
var total_weight: int = 0

func _ready() -> void:
	# Calculate total weight
	for item in ITEM_POOL:
		total_weight += item.weight

	body_entered.connect(_on_body_entered)
	respawn_timer.timeout.connect(_on_respawn_timer_timeout)

func _process(_delta: float) -> void:
	# Rotation handled by item_box_psx.gd
	pass

func _on_body_entered(body: Node3D) -> void:
	if not is_active:
		return

	if not body.is_in_group("player"):
		return

	# Only server handles item collection
	if not multiplayer.is_server() and multiplayer.has_multiplayer_peer():
		return

	var peer_id = 1
	if body.has_method("get_multiplayer_authority"):
		peer_id = body.get_multiplayer_authority()
	elif "peer_id" in body:
		peer_id = body.peer_id

	# Check if player already has an item
	if "current_item" in body and body.current_item != "":
		return  # Player already has an item

	var item_type = _roll_random_item()
	_collect_item.rpc(peer_id, item_type)

@rpc("authority", "call_local", "reliable")
func _collect_item(peer_id: int, item_type: String) -> void:
	is_active = false
	visible = false
	collision.disabled = true

	item_collected.emit(peer_id, item_type)

	# Give item to player
	var player = PlayerRegistry.get_player(peer_id)
	if player:
		_apply_item_to_player(player, item_type)

	# Start respawn timer
	respawn_timer.start(respawn_time)

func _apply_item_to_player(player: Node, item_type: String) -> void:
	match item_type:
		"speed_boost":
			player.set_item("speed_boost", 1)
			_activate_speed_boost(player)
		"damage_boost":
			player.set_item("damage_boost", 1)
			_activate_damage_boost(player)
		"shield":
			player.set_item("shield", 1)
			_activate_shield(player)
		"health_restore":
			_activate_health_restore(player)
		"kunai":
			player.set_item("kunai", 3)
		"smoke_bomb":
			player.set_item("smoke_bomb", 1)
		"dual_swords":
			player.set_item("dual_swords", 1)
			_activate_dual_swords(player)

func _activate_speed_boost(player: Node) -> void:
	player.speed_multiplier = 1.5
	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(player):
		player.speed_multiplier = 1.0
		if player.current_item == "speed_boost":
			player.current_item = ""

func _activate_damage_boost(player: Node) -> void:
	player.damage_multiplier = 1.25
	await get_tree().create_timer(10.0).timeout
	if is_instance_valid(player):
		player.damage_multiplier = 1.0
		if player.current_item == "damage_boost":
			player.current_item = ""

func _activate_shield(player: Node) -> void:
	player.shield_health = 50.0

func _activate_health_restore(player: Node) -> void:
	player.health = min(player.health + 50, player.max_health)

func _activate_dual_swords(player: Node) -> void:
	player.attack_speed_multiplier = 2.0
	player.damage_multiplier = 1.1
	await get_tree().create_timer(15.0).timeout
	if is_instance_valid(player):
		player.attack_speed_multiplier = 1.0
		player.damage_multiplier = 1.0
		if player.current_item == "dual_swords":
			player.current_item = ""

func _on_respawn_timer_timeout() -> void:
	_respawn.rpc()

@rpc("authority", "call_local", "reliable")
func _respawn() -> void:
	is_active = true
	visible = true
	collision.disabled = false

func _roll_random_item() -> String:
	var roll = randi() % total_weight
	var cumulative = 0

	for item in ITEM_POOL:
		cumulative += item.weight
		if roll < cumulative:
			return item.type

	return ITEM_POOL[0].type
