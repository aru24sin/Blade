extends Control
## Lobby - Pre-game lobby for players to ready up and select teams

@onready var player_list: VBoxContainer = $Panel/VBoxContainer/PlayerList
@onready var team_panel: Control = $Panel/VBoxContainer/TeamPanel
@onready var ready_button: Button = $Panel/VBoxContainer/ButtonContainer/ReadyButton
@onready var start_button: Button = $Panel/VBoxContainer/ButtonContainer/StartButton
@onready var game_mode_label: Label = $Panel/VBoxContainer/GameModeLabel
@onready var map_label: Label = $Panel/VBoxContainer/MapLabel

var player_slots: Dictionary = {}  # peer_id -> slot node

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Update UI based on game mode
	var mode = GameState.game_mode
	game_mode_label.text = "Mode: " + ("Team Battle" if mode == GameState.GameMode.TEAM_BATTLE else "Free For All")
	team_panel.visible = mode == GameState.GameMode.TEAM_BATTLE

	# Update map label
	map_label.text = "Map: " + MapData.get_selected_map_name()

	# Only host can start game
	start_button.visible = NetworkManager.is_server()
	start_button.disabled = false  # Allow starting immediately with 1 player

	# Connect signals
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	PlayerRegistry.all_players_ready.connect(_on_all_players_ready)

	# Add existing players (including self)
	_refresh_player_list()

func _refresh_player_list() -> void:
	# Clear existing slots
	for child in player_list.get_children():
		child.queue_free()
	player_slots.clear()

	# Add all registered players
	for peer_id in GameState.player_names:
		_add_player_slot(peer_id)

func _add_player_slot(peer_id: int) -> void:
	var slot = HBoxContainer.new()

	var name_label = Label.new()
	name_label.text = GameState.player_names.get(peer_id, "Player " + str(peer_id))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 8)
	slot.add_child(name_label)

	# Team indicator (for team mode)
	if GameState.game_mode == GameState.GameMode.TEAM_BATTLE:
		var team_label = Label.new()
		var team = GameState.get_player_team(peer_id)
		team_label.text = _get_team_text(team)
		team_label.custom_minimum_size.x = 40
		team_label.add_theme_font_size_override("font_size", 8)
		slot.add_child(team_label)

	# Ready indicator
	var ready_label = Label.new()
	ready_label.text = "Ready" if PlayerRegistry.is_player_ready(peer_id) else "..."
	ready_label.custom_minimum_size.x = 30
	ready_label.add_theme_font_size_override("font_size", 8)
	slot.add_child(ready_label)

	player_list.add_child(slot)
	player_slots[peer_id] = slot

func _get_team_text(team: GameState.Team) -> String:
	match team:
		GameState.Team.RED:
			return "[RED]"
		GameState.Team.BLUE:
			return "[BLUE]"
		_:
			return "[-]"

func _on_player_connected(peer_id: int) -> void:
	GameState.register_player(peer_id, "Player " + str(peer_id))
	_refresh_player_list()

func _on_player_disconnected(peer_id: int) -> void:
	_refresh_player_list()

func _on_all_players_ready() -> void:
	# Not needed anymore since we allow starting anytime
	pass

func _on_ready_button_pressed() -> void:
	var my_id = NetworkManager.get_my_id()
	var currently_ready = PlayerRegistry.is_player_ready(my_id)
	PlayerRegistry.request_set_ready.rpc(!currently_ready)

	ready_button.text = "Unready" if !currently_ready else "Ready"
	_refresh_player_list()

func _on_start_button_pressed() -> void:
	if not NetworkManager.is_server():
		return

	# Start the game - no longer requires all players to be ready
	GameState.set_match_phase(GameState.MatchPhase.STARTING)
	_start_game.rpc()

@rpc("authority", "call_local", "reliable")
func _start_game() -> void:
	GameState.set_match_phase(GameState.MatchPhase.PLAYING)
	get_tree().change_scene_to_file(MapData.get_selected_map_path())

func _on_back_button_pressed() -> void:
	NetworkManager.disconnect_game()
	GameState.set_match_phase(GameState.MatchPhase.MENU)
	get_tree().change_scene_to_file("res://src/ui/main_menu/main_menu.tscn")

# Team selection
func _on_red_team_pressed() -> void:
	var my_id = NetworkManager.get_my_id()
	_request_team_change.rpc_id(1, my_id, GameState.Team.RED)

func _on_blue_team_pressed() -> void:
	var my_id = NetworkManager.get_my_id()
	_request_team_change.rpc_id(1, my_id, GameState.Team.BLUE)

@rpc("any_peer", "reliable")
func _request_team_change(peer_id: int, team: int) -> void:
	if not multiplayer.is_server():
		return

	GameState.set_player_team(peer_id, team as GameState.Team)
	_sync_team_change.rpc(peer_id, team)

@rpc("authority", "call_local", "reliable")
func _sync_team_change(peer_id: int, team: int) -> void:
	GameState.set_player_team(peer_id, team as GameState.Team)
	_refresh_player_list()
