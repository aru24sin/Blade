class_name PostureComponent
extends Node
## PostureComponent - Sekiro-style posture system that rewards aggression

signal posture_changed(current: float, maximum: float)
signal posture_broken()
signal posture_recovered()

@export var max_posture: float = 100.0
@export var regen_rate_idle: float = 12.0  # Per second when not blocking/attacking
@export var regen_rate_blocking: float = 8.0  # Per second while blocking

var current_posture: float = 0.0
var is_broken: bool = false
var regen_paused: bool = false  # Pause during hitstun
var low_hp_penalty: bool = false  # Halves recovery when below 30% HP

# Network sync
var owner_player: Node = null

func _ready() -> void:
	current_posture = 0.0
	owner_player = get_parent()

func _physics_process(delta: float) -> void:
	if is_broken or regen_paused:
		return

	# Regenerate posture over time
	if current_posture > 0:
		var regen = regen_rate_idle

		# Check if blocking
		if owner_player and owner_player.has_method("is_blocking") and owner_player.is_blocking():
			regen = regen_rate_blocking

		# Low HP penalty
		if low_hp_penalty:
			regen *= 0.5

		current_posture = max(current_posture - regen * delta, 0.0)
		posture_changed.emit(current_posture, max_posture)

func add_posture_damage(amount: float) -> void:
	if is_broken:
		return

	current_posture = min(current_posture + amount, max_posture)
	posture_changed.emit(current_posture, max_posture)

	if current_posture >= max_posture:
		_break_posture()

func _break_posture() -> void:
	is_broken = true
	current_posture = max_posture
	posture_broken.emit()

	# Sync over network
	if owner_player and owner_player.is_multiplayer_authority():
		_sync_posture_break.rpc()

@rpc("any_peer", "call_local", "reliable")
func _sync_posture_break() -> void:
	if not owner_player or not owner_player.is_multiplayer_authority():
		is_broken = true
		current_posture = max_posture
		posture_broken.emit()

func recover_from_break() -> void:
	is_broken = false
	current_posture = 0.0
	posture_changed.emit(current_posture, max_posture)
	posture_recovered.emit()

func pause_regen() -> void:
	regen_paused = true

func resume_regen() -> void:
	regen_paused = false

func set_low_hp_penalty(enabled: bool) -> void:
	low_hp_penalty = enabled

func get_percentage() -> float:
	return current_posture / max_posture

func is_near_break() -> bool:
	return current_posture >= max_posture * 0.75

func reset() -> void:
	current_posture = 0.0
	is_broken = false
	regen_paused = false
	low_hp_penalty = false
	posture_changed.emit(current_posture, max_posture)

# Network sync for posture value
@rpc("any_peer", "unreliable")
func sync_posture(value: float) -> void:
	if not owner_player or not owner_player.is_multiplayer_authority():
		current_posture = value
		posture_changed.emit(current_posture, max_posture)

func _on_authority_sync() -> void:
	if owner_player and owner_player.is_multiplayer_authority():
		sync_posture.rpc(current_posture)
