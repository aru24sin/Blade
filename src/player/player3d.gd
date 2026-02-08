extends CharacterBody3D
## Player3D - Main player controller using state machine for combat and movement

signal dash_performed()
signal damage_taken(amount: int, attacker_id: int)
signal died(killer_id: int)
signal respawned()

# Player identity
@export var peer_id: int = 1
@export var player_name: String = "Player"
@export var team: int = 0  # GameState.Team

# Health
@export var max_health: float = 100.0
@export var health: float = 100.0

# Movement
@export var base_speed: float = 15.0
@export var gravity: float = -0.7
@export var jump_strength: float = 17.0
@export var double_jump_strength: float = 22.0
@export var max_jump_count: int = 2
@export var max_dash_count: int = 2

# Camera
@export var mouse_sensitivity: float = 0.010
@export var ang_for_cam_to_lerp_to: float = 0.0
@export var x_ang_for_cam_to_lerp_to: float = 0.0

# Combat modifiers (can be changed by items)
var damage_multiplier: float = 1.0
var speed_multiplier: float = 1.0
var attack_speed_multiplier: float = 1.0

# State tracking
var jump_count: int = 0
var dash_count: int = 0
var extra_velocity: Vector3 = Vector3.ZERO
var is_dead: bool = false

# Item
var current_item: String = ""
var item_uses: int = 0

# Shield (from item)
var shield_health: float = 0.0

# Node references
@onready var head: Node3D = $head
@onready var camera: Camera3D = $head/Camera3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var stamina: StaminaComponent = $StaminaComponent
@onready var hitbox: HitboxComponent = $HitboxComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var state_machine: PlayerStateMachine = $StateMachine

var is_local_player: bool = true

func _ready() -> void:
	# Set up for local player
	if is_local_player:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		camera.current = true
	else:
		camera.current = false

	# Set owner IDs for hit detection
	if hitbox:
		hitbox.owner_id = peer_id
	if hurtbox:
		hurtbox.owner_id = peer_id
		hurtbox.damage_received.connect(_on_damage_received)
		hurtbox.blocked.connect(_on_damage_blocked)

	# Register with player registry
	PlayerRegistry.register_player_node(peer_id, self)

func _exit_tree() -> void:
	PlayerRegistry.unregister_player_node(peer_id)

func _input(event: InputEvent) -> void:
	if not is_local_player:
		return

	# Mouse look
	if event is InputEventMouseMotion:
		head.rotation.x += -event.relative.y * mouse_sensitivity
		rotation.y += -event.relative.x * mouse_sensitivity
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func _process(delta: float) -> void:
	if not is_local_player:
		return

	# Debug restart
	if Input.is_action_just_pressed("r"):
		get_tree().reload_current_scene()

	# Quit
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()

	# Use item
	if Input.is_action_just_pressed("use_item") and current_item != "":
		use_item()

	# Camera bob lerping
	head.rotation_degrees.z = lerp(head.rotation_degrees.z, ang_for_cam_to_lerp_to, 0.1)
	camera.rotation_degrees.x = lerp(camera.rotation_degrees.x, x_ang_for_cam_to_lerp_to, 0.1)

func _on_damage_received(amount: int, attacker_id: int) -> void:
	if is_dead:
		return

	# Shield absorbs damage first
	if shield_health > 0:
		var absorbed = min(shield_health, amount)
		shield_health -= absorbed
		amount -= int(absorbed)
		if amount <= 0:
			return

	health -= amount
	damage_taken.emit(amount, attacker_id)

	if health <= 0:
		_die(attacker_id)
	else:
		# Apply hitstun
		var knockback = Vector3.ZERO
		var attacker = PlayerRegistry.get_player(attacker_id)
		if attacker:
			knockback = (global_position - attacker.global_position).normalized() * 5.0
		state_machine.transition_to("Stun", {
			"stun_type": "hit",
			"duration": CombatData.HIT_STUN_BASE,
			"knockback": knockback
		})

func _on_damage_blocked(amount: int, attacker_id: int, attack_name: String = "light_1") -> void:
	# Notify block state
	if state_machine.is_in_state("Block"):
		var block_state = state_machine.current_state as BlockState
		if block_state:
			block_state.on_damage_blocked(amount, attacker_id, attack_name)

func apply_parry_stun() -> void:
	state_machine.transition_to("Stun", {
		"stun_type": "parried",
		"duration": CombatData.PARRIED_STUN_DURATION,
		"knockback": -global_transform.basis.z * CombatData.KNOCKBACK_PARRY
	})

func _die(killer_id: int) -> void:
	is_dead = true
	health = 0
	died.emit(killer_id)

	# Notify game state
	GameState.add_kill(killer_id, peer_id)

	# Disable collision
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)

	# Start respawn timer (server handles this in multiplayer)
	if NetworkManager.is_server() or not multiplayer.has_multiplayer_peer():
		await get_tree().create_timer(3.0).timeout
		respawn()

func respawn() -> void:
	is_dead = false
	health = max_health
	stamina.reset()
	shield_health = 0
	current_item = ""
	item_uses = 0
	damage_multiplier = 1.0
	speed_multiplier = 1.0
	attack_speed_multiplier = 1.0

	# Re-enable collision
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)

	# Move to spawn point (would be set by game manager)
	# global_position = spawn_point

	state_machine.transition_to("Idle")
	respawned.emit()

func set_item(item_type: String, uses: int = 1) -> void:
	current_item = item_type
	item_uses = uses

func use_item() -> void:
	if current_item == "" or item_uses <= 0:
		return

	# Item usage is handled by item scripts
	# This just decrements uses
	item_uses -= 1
	if item_uses <= 0:
		current_item = ""

func get_throw_transform() -> Transform3D:
	# Return transform for throwing projectiles
	return camera.global_transform

# Network helper for taking damage (called via RPC)
func take_damage(amount: int, attacker_id: int = 0) -> void:
	_on_damage_received(amount, attacker_id)

# Multiplayer helper
func set_as_remote_player() -> void:
	is_local_player = false
	if camera:
		camera.current = false

func set_as_local_player() -> void:
	is_local_player = true
	if camera:
		camera.current = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
