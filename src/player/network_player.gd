extends CharacterBody3D
## NetworkPlayer - Networked player wrapper with RPCs and synchronization

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
var health: float = 100.0

# Movement - ULTRAKILL style: fast, snappy, responsive
@export var base_speed: float = 18.0  # Faster base movement
@export var gravity: float = -30.0  # Light gravity for extended airtime
@export var jump_strength: float = 16.0  # Vertical jump
@export var double_jump_strength: float = 18.0  # Stronger double jump
@export var max_jump_count: int = 2
@export var max_dash_count: int = 3  # 3 dashes for more mobility

# Wall running
@export var wall_run_speed: float = 20.0
@export var wall_run_gravity: float = -8.0
@export var wall_run_max_time: float = 1.2
@export var wall_jump_horizontal: float = 14.0
@export var wall_jump_vertical: float = 15.0

# Ground slam
@export var slam_speed: float = 65.0
@export var slam_shockwave_radius: float = 4.0
@export var slam_shockwave_damage: int = 25

# Bunny hop
@export var bhop_window: float = 0.12
@export var bhop_speed_bonus: float = 1.15
@export var bhop_max_multiplier: float = 1.6

# Camera
@export var mouse_sensitivity: float = 0.010
var ang_for_cam_to_lerp_to: float = 0.0
var x_ang_for_cam_to_lerp_to: float = 0.0

# Combat modifiers (can be changed by items)
var damage_multiplier: float = 1.0
var speed_multiplier: float = 1.0
var attack_speed_multiplier: float = 1.0

# Effect durations (in seconds, 0 = inactive)
var speed_boost_timer: float = 0.0
var damage_boost_timer: float = 0.0
var dual_swords_timer: float = 0.0
const EFFECT_DURATION: float = 10.0  # All timed effects last 10 seconds

# State tracking
var jump_count: int = 0
var dash_count: int = 0
var extra_velocity: Vector3 = Vector3.ZERO
var is_dead: bool = false

# Momentum system
var momentum_multiplier: float = 1.0
var bhop_chain: int = 0
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

# Item
var current_item: String = ""
var item_uses: int = 0

# Shield (from item)
var shield_health: float = 0.0

# Sync state (for MultiplayerSynchronizer)
var sync_position: Vector3 = Vector3.ZERO
var sync_rotation: float = 0.0
var sync_velocity: Vector3 = Vector3.ZERO
var sync_state: String = "Idle"

# Node references
@onready var head: Node3D = $head
@onready var camera: Camera3D = $head/Camera3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var stamina: StaminaComponent = $StaminaComponent
@onready var stamina_component: StaminaComponent = $StaminaComponent  # Alias for new combat system
@onready var posture_component: PostureComponent = $PostureComponent
@onready var hitbox: HitboxComponent = $HitboxComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var state_machine: PlayerStateMachine = $StateMachine
@onready var camera_effects: CameraEffects = $CameraEffects
@onready var main_sword: MeshInstance3D = $head/Sword
@onready var second_sword: MeshInstance3D = $head/SecondSword

# Viewmodel rendering (prevents sword clipping into world)
var viewmodel_viewport: SubViewport
var viewmodel_camera: Camera3D
var viewmodel_container: SubViewportContainer

# Dual wielding state
var is_dual_wielding: bool = false

var is_local_player: bool = false

func _ready() -> void:
	# Determine if this is the local player
	is_local_player = peer_id == multiplayer.get_unique_id()

	if is_local_player:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		camera.current = true
		# Apply player settings
		camera.fov = GameState.player_fov
		mouse_sensitivity = GameState.mouse_sensitivity
		# Setup viewmodel rendering to prevent sword clipping
		_setup_viewmodel_rendering()
	else:
		camera.current = false
		# For remote players, disable state machine input handling
		set_process_unhandled_input(false)

	# Set owner IDs for hit detection
	if hitbox:
		hitbox.owner_id = peer_id
	if hurtbox:
		hurtbox.owner_id = peer_id
		hurtbox.damage_received.connect(_on_damage_received)
		hurtbox.blocked.connect(_on_damage_blocked)

	# Register with player registry
	PlayerRegistry.register_player_node(peer_id, self)

	# Setup posture component
	_ready_posture()

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
	# Update effect timers
	_update_effect_timers(delta)

	# Sync viewmodel camera with main camera (for sword rendering)
	if is_local_player and viewmodel_camera and camera:
		viewmodel_camera.global_transform = camera.global_transform
		viewmodel_camera.fov = camera.fov

	if is_local_player:
		# Update sync vars for network
		sync_position = global_position
		sync_rotation = rotation.y
		sync_velocity = velocity
		sync_state = state_machine.get_current_state_name()

		# Use item
		if Input.is_action_just_pressed("use_item") and current_item != "":
			if multiplayer.is_server():
				# We are the server, use item directly
				if item_uses > 0:
					confirm_use_item.rpc(current_item)
			else:
				request_use_item.rpc_id(1)  # Request to server

		# Camera bob lerping
		head.rotation_degrees.z = lerp(head.rotation_degrees.z, ang_for_cam_to_lerp_to, 0.1)
		camera.rotation_degrees.x = lerp(camera.rotation_degrees.x, x_ang_for_cam_to_lerp_to, 0.1)

		# Update camera effects with speed
		if camera_effects:
			var speed = Vector2(velocity.x, velocity.z).length()
			camera_effects.set_speed_effects(speed)
	else:
		# Interpolate remote player position
		global_position = global_position.lerp(sync_position, 0.5)
		rotation.y = lerp_angle(rotation.y, sync_rotation, 0.5)

func _update_effect_timers(delta: float) -> void:
	# Speed boost timer
	if speed_boost_timer > 0:
		speed_boost_timer -= delta
		if speed_boost_timer <= 0:
			speed_boost_timer = 0.0
			speed_multiplier = 1.0

	# Damage boost timer
	if damage_boost_timer > 0:
		damage_boost_timer -= delta
		if damage_boost_timer <= 0:
			damage_boost_timer = 0.0
			damage_multiplier = 1.0

	# Dual swords timer
	if dual_swords_timer > 0:
		dual_swords_timer -= delta
		if dual_swords_timer <= 0:
			dual_swords_timer = 0.0
			attack_speed_multiplier = 1.0
			# Only reset damage if not from separate damage boost
			if damage_boost_timer <= 0:
				damage_multiplier = 1.0
			_hide_second_sword()

func _on_damage_received(amount: int, attacker_id: int) -> void:
	if not is_multiplayer_authority():
		return

	# Request damage from server
	request_damage.rpc_id(1, amount, attacker_id)

func _on_damage_blocked(amount: int, attacker_id: int, attack_name: String = "light_1") -> void:
	if state_machine.is_in_state("Block"):
		var block_state = state_machine.current_state as BlockState
		if block_state:
			block_state.on_damage_blocked(amount, attacker_id, attack_name)

# === Network RPCs ===

@rpc("any_peer", "reliable")
func request_damage(amount: int, attacker_id: int) -> void:
	if not multiplayer.is_server():
		return

	# Server validates and applies damage
	apply_damage.rpc(amount, attacker_id)

@rpc("authority", "call_local", "reliable")
func apply_damage(amount: int, attacker_id: int) -> void:
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
		server_die.rpc_id(1, attacker_id)
	else:
		# Apply hitstun
		var knockback = Vector3.ZERO
		var attacker = PlayerRegistry.get_player(attacker_id)
		if attacker:
			# Use default knockback value
			knockback = (global_position - attacker.global_position).normalized() * 5.0
		state_machine.transition_to("Stun", {
			"stun_type": "hit",
			"duration": CombatData.HIT_STUN_BASE,
			"knockback": knockback
		})

@rpc("any_peer", "reliable")
func server_die(killer_id: int) -> void:
	if not multiplayer.is_server():
		return

	# Server confirms death and broadcasts
	confirm_death.rpc(killer_id)

	# Schedule respawn
	await get_tree().create_timer(3.0).timeout
	var spawn_pos = _get_spawn_position()
	confirm_respawn.rpc(spawn_pos)

@rpc("authority", "call_local", "reliable")
func confirm_death(killer_id: int) -> void:
	is_dead = true
	health = 0
	died.emit(killer_id)
	GameState.add_kill(killer_id, peer_id)

	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)

@rpc("authority", "call_local", "reliable")
func confirm_respawn(spawn_pos: Vector3) -> void:
	is_dead = false
	health = max_health
	stamina.reset()
	shield_health = 0
	current_item = ""
	item_uses = 0
	damage_multiplier = 1.0
	speed_multiplier = 1.0
	attack_speed_multiplier = 1.0
	speed_boost_timer = 0.0
	damage_boost_timer = 0.0
	dual_swords_timer = 0.0
	_hide_second_sword()

	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)

	global_position = spawn_pos
	state_machine.transition_to("Idle")
	respawned.emit()

@rpc("any_peer", "reliable")
func request_attack(attack_type: String) -> void:
	if not multiplayer.is_server():
		return

	# Server validates attack
	var sender_id = multiplayer.get_remote_sender_id()
	var player = PlayerRegistry.get_player(sender_id)
	if player and player == self:
		confirm_attack.rpc(attack_type)

@rpc("authority", "call_local", "reliable")
func confirm_attack(attack_type: String) -> void:
	state_machine.transition_to("Attack", {"attack_type": attack_type})

@rpc("any_peer", "reliable")
func request_use_item() -> void:
	if not multiplayer.is_server():
		return

	if current_item != "" and item_uses > 0:
		confirm_use_item.rpc(current_item)

@rpc("authority", "call_local", "reliable")
func confirm_use_item(item_type: String) -> void:
	# Handle item usage
	item_uses -= 1
	if item_uses <= 0:
		current_item = ""

	# Apply item effects with visuals
	_apply_item_effect(item_type)

func _apply_item_effect(item_type: String) -> void:
	match item_type:
		"kunai":
			_throw_kunai()
		"smoke_bomb":
			_use_smoke_bomb()
		"speed_boost":
			_use_speed_boost()
		"damage_boost":
			_use_damage_boost()
		"shield":
			_use_shield()
		"health_restore":
			_use_health_restore()
		"dual_swords":
			_use_dual_swords()

func _throw_kunai() -> void:
	# Create kunai projectile from camera position
	var kunai_scene = load("res://src/items/items/kunai.tscn")
	if kunai_scene:
		var kunai = kunai_scene.instantiate()
		var throw_dir = -camera.global_transform.basis.z
		kunai.global_position = camera.global_position + throw_dir * 0.5
		kunai.direction = throw_dir
		kunai.owner_id = peer_id
		kunai.damage = int(25 * damage_multiplier)
		get_tree().current_scene.add_child(kunai)
	_create_powerup_flash(Color(0.8, 0.8, 0.8))  # White flash for throw

func _use_smoke_bomb() -> void:
	# Create smoke effect at player position
	var smoke_scene = load("res://src/items/items/smoke_bomb.tscn")
	if smoke_scene:
		var smoke = smoke_scene.instantiate()
		smoke.global_position = global_position
		get_tree().current_scene.add_child(smoke)
	_create_powerup_flash(Color(0.5, 0.5, 0.5))  # Gray flash for smoke

func _use_speed_boost() -> void:
	speed_multiplier = 1.5
	speed_boost_timer = EFFECT_DURATION
	_create_powerup_flash(Color(0, 1, 1))  # Cyan flash

func _use_damage_boost() -> void:
	damage_multiplier = 1.5
	damage_boost_timer = EFFECT_DURATION
	_create_powerup_flash(Color(1, 0.5, 0))  # Orange flash

func _use_shield() -> void:
	shield_health = 50.0
	_create_powerup_flash(Color(0, 0.5, 1))  # Blue flash

func _use_health_restore() -> void:
	health = min(health + 50, max_health)
	_create_powerup_flash(Color(0, 1, 0))  # Green flash

func _use_dual_swords() -> void:
	attack_speed_multiplier = 1.5  # Faster attacks with two swords
	damage_multiplier = 1.35  # More damage
	dual_swords_timer = EFFECT_DURATION
	_show_second_sword()
	_create_powerup_flash(Color(0.8, 0.2, 0.9))  # Purple flash

func _show_second_sword() -> void:
	# Show the second sword mesh and enable dual wield mode
	is_dual_wielding = true
	if second_sword:
		second_sword.visible = true

func _hide_second_sword() -> void:
	# Hide the second sword mesh and disable dual wield mode
	is_dual_wielding = false
	if second_sword:
		second_sword.visible = false

func is_dual_wield_active() -> bool:
	return is_dual_wielding and dual_swords_timer > 0

func _create_powerup_flash(color: Color) -> void:
	# Simple visual feedback - flash the screen or create particle effect
	if is_local_player and camera:
		# Create a brief color overlay effect
		var flash = ColorRect.new()
		flash.color = Color(color.r, color.g, color.b, 0.3)
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		camera.add_child(flash)
		# Fade out and remove
		var tween = create_tween()
		tween.tween_property(flash, "color:a", 0.0, 0.3)
		tween.tween_callback(flash.queue_free)

func apply_parry_stun() -> void:
	state_machine.transition_to("Stun", {
		"stun_type": "parried",
		"duration": CombatData.PARRIED_STUN_DURATION,
		"knockback": -global_transform.basis.z * CombatData.KNOCKBACK_PARRY
	})

func set_item(item_type: String, uses: int = 1) -> void:
	current_item = item_type
	item_uses = uses

func get_throw_transform() -> Transform3D:
	return camera.global_transform

func take_damage(amount: int, attacker_id: int = 0) -> void:
	_on_damage_received(amount, attacker_id)

func _get_spawn_position() -> Vector3:
	# Get a random spawn point from the level
	var spawn_points = get_tree().get_nodes_in_group("spawn_point")
	if spawn_points.size() > 0:
		var spawn = spawn_points[randi() % spawn_points.size()]
		return spawn.global_position
	return Vector3(0, 5, 0)

func _setup_viewmodel_rendering() -> void:
	# Main camera should NOT render layer 2 (swords) - only layers 1, 3-20
	camera.cull_mask = camera.cull_mask & ~2  # Remove layer 2 from main camera

	# Create a CanvasLayer for the viewmodel overlay (renders on top of everything)
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100  # High layer to render on top
	add_child(canvas_layer)

	# Create SubViewportContainer to display the viewmodel
	viewmodel_container = SubViewportContainer.new()
	viewmodel_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewmodel_container.stretch = true
	viewmodel_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(viewmodel_container)

	# Create SubViewport for viewmodel rendering
	viewmodel_viewport = SubViewport.new()
	viewmodel_viewport.transparent_bg = true  # Transparent background to see world behind
	viewmodel_viewport.handle_input_locally = false
	viewmodel_viewport.size = Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width", 1920),
		ProjectSettings.get_setting("display/window/size/viewport_height", 1080)
	)
	viewmodel_container.add_child(viewmodel_viewport)

	# Create viewmodel camera (synced with main camera)
	viewmodel_camera = Camera3D.new()
	viewmodel_camera.cull_mask = 2  # ONLY render layer 2 (swords)
	viewmodel_camera.near = 0.01  # Very close near plane so sword never clips
	viewmodel_camera.far = 10.0  # Short far plane (sword is close)
	viewmodel_camera.fov = camera.fov
	viewmodel_viewport.add_child(viewmodel_camera)

	# Reparent swords to viewmodel viewport so they render there
	# We need to sync sword transforms with head movement
	call_deferred("_reparent_swords_to_viewmodel")

func _reparent_swords_to_viewmodel() -> void:
	if not viewmodel_viewport or not viewmodel_camera:
		return

	# Store original transforms
	var sword_transform = main_sword.transform
	var second_sword_transform = second_sword.transform
	var second_visible = second_sword.visible

	# Reparent swords to viewmodel camera (so they follow camera movement)
	main_sword.get_parent().remove_child(main_sword)
	second_sword.get_parent().remove_child(second_sword)
	viewmodel_camera.add_child(main_sword)
	viewmodel_camera.add_child(second_sword)

	# Restore transforms relative to viewmodel camera
	main_sword.transform = sword_transform
	second_sword.transform = second_sword_transform
	second_sword.visible = second_visible

	# Update animation paths to point to new sword locations
	# The animations animate head/Sword and head/SecondSword
	# We need to remap them to the viewmodel camera children
	_update_animation_paths()

func _update_animation_paths() -> void:
	# Since swords are now children of viewmodel_camera which syncs with main camera,
	# we need to change animation targets from "head/Sword" to use the new sword references
	# The cleanest way is to animate the swords directly by reference
	if not animation_player:
		return

	# Get all animation libraries
	for lib_name in animation_player.get_animation_library_list():
		var lib = animation_player.get_animation_library(lib_name)
		for anim_name in lib.get_animation_list():
			var anim = lib.get_animation(anim_name)
			_remap_animation_tracks(anim)

func _remap_animation_tracks(anim: Animation) -> void:
	# Remap track paths from head/Sword to the new viewmodel sword location
	# AnimationPlayer looks for paths relative to its root (this node)
	# After reparenting, swords are at: CanvasLayer/SubViewportContainer/SubViewport/Camera3D/Sword

	if not viewmodel_camera:
		return

	# Get the relative path from this node to the viewmodel camera
	var viewmodel_path = get_path_to(viewmodel_camera)

	for i in range(anim.get_track_count()):
		var path = anim.track_get_path(i)
		var path_str = str(path)

		# Skip non-sword tracks
		if "Sword" not in path_str:
			continue

		# Build the new path relative to this node (AnimationPlayer's root)
		var new_path_str = path_str
		if "head/Sword:" in path_str:
			# Get the property part (e.g., ":position" or ":rotation")
			var prop_part = path_str.substr(path_str.find(":"))
			new_path_str = str(viewmodel_path) + "/Sword" + prop_part
		elif "head/SecondSword:" in path_str:
			var prop_part = path_str.substr(path_str.find(":"))
			new_path_str = str(viewmodel_path) + "/SecondSword" + prop_part

		if new_path_str != path_str:
			anim.track_set_path(i, NodePath(new_path_str))

# === Combat Helper Methods ===

func apply_knockback(knockback: Vector3) -> void:
	velocity += knockback

func apply_hitstop(duration: float) -> void:
	HitFeedback.apply_hitstop(duration)

func apply_screen_shake(intensity: float) -> void:
	HitFeedback.apply_shake(intensity)

func is_blocking() -> bool:
	return state_machine.is_in_state("Block")

# Get health values (posture needs to check HP for low HP penalty)
var current_health: float:
	get:
		return health

func _ready_posture() -> void:
	# Connect posture signals
	if posture_component:
		posture_component.posture_broken.connect(_on_posture_broken)

func _on_posture_broken() -> void:
	# Transition to posture break stun
	state_machine.transition_to("Stun", {
		"stun_type": "posture_break",
		"duration": CombatData.POSTURE_BREAK_STUN
	})

	# Update low HP penalty
	if posture_component:
		var hp_percent = health / max_health
		posture_component.set_low_hp_penalty(hp_percent < CombatData.LOW_HP_THRESHOLD)
