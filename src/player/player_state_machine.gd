class_name PlayerStateMachine
extends Node
## PlayerStateMachine - Manages player state transitions and updates

signal state_changed(old_state: String, new_state: String)

@export var initial_state: NodePath

var current_state: PlayerState
var states: Dictionary = {}
var player: CharacterBody3D

func _ready() -> void:
	await owner.ready
	player = owner as CharacterBody3D

	# Register all child states
	for child in get_children():
		if child is PlayerState:
			states[child.name] = child
			child.player = player
			child.state_machine = self

	# Set initial state
	if initial_state:
		current_state = get_node(initial_state)
	elif states.size() > 0:
		current_state = states.values()[0]

	if current_state:
		current_state.enter()

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)
		_check_transition()

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)

func _check_transition() -> void:
	if current_state:
		var next_state_name = current_state.get_transition()
		if next_state_name != "" and next_state_name != current_state.name:
			transition_to(next_state_name)

func transition_to(state_name: String, msg: Dictionary = {}) -> void:
	if not states.has(state_name):
		push_error("State not found: " + state_name)
		return

	var old_state_name = current_state.name if current_state else ""

	if current_state:
		current_state.exit()

	current_state = states[state_name]
	current_state.enter(msg)

	state_changed.emit(old_state_name, state_name)

func get_current_state_name() -> String:
	return current_state.name if current_state else ""

func is_in_state(state_name: String) -> bool:
	return current_state != null and current_state.name == state_name

func force_transition(state_name: String, msg: Dictionary = {}) -> void:
	transition_to(state_name, msg)
