extends Control
## MainMenu - Main menu UI for hosting/joining games

signal host_pressed()
signal join_pressed()
signal settings_pressed()
signal quit_pressed()

@onready var main_panel: Control = $MainPanel
@onready var host_panel: Control = $HostPanel
@onready var join_panel: Control = $JoinPanel
@onready var settings_panel: Control = $SettingsPanel

# Host panel
@onready var port_input: LineEdit = $HostPanel/Panel/VBoxContainer/PortInput
@onready var max_players_slider: HSlider = $HostPanel/Panel/VBoxContainer/MaxPlayersSlider
@onready var max_players_label: Label = $HostPanel/Panel/VBoxContainer/MaxPlayersLabel
@onready var game_mode_option: OptionButton = $HostPanel/Panel/VBoxContainer/GameModeOption
@onready var map_option: OptionButton = $HostPanel/Panel/VBoxContainer/MapOption
@onready var map_description: Label = $HostPanel/Panel/VBoxContainer/MapDescription

# Join panel
@onready var address_input: LineEdit = $JoinPanel/Panel/VBoxContainer/AddressInput
@onready var join_port_input: LineEdit = $JoinPanel/Panel/VBoxContainer/PortInput
@onready var connection_status: Label = $JoinPanel/Panel/VBoxContainer/ConnectionStatus

# Settings panel
@onready var sens_slider: HSlider = $SettingsPanel/Panel/VBoxContainer/SensSlider
@onready var fov_slider: HSlider = $SettingsPanel/Panel/VBoxContainer/FovSlider
@onready var fov_label: Label = $SettingsPanel/Panel/VBoxContainer/FovLabel
@onready var aspect_option: OptionButton = $SettingsPanel/Panel/VBoxContainer/AspectOption

func _ready() -> void:
	_show_main_panel()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Apply PSX theme
	theme = PSXTheme.create_theme()

	# Set up game mode options
	game_mode_option.add_item("FREE FOR ALL", 0)
	game_mode_option.add_item("TEAM BATTLE", 1)

	# Set up map options from MapData
	var map_ids = MapData.get_map_ids()
	for i in range(map_ids.size()):
		var map_id = map_ids[i]
		var map_info = MapData.get_map_info(map_id)
		map_option.add_item(map_info["name"].to_upper(), i)

	# Set default selection and update description
	var default_index = MapData.get_index_by_map_id(MapData.selected_map)
	if default_index >= 0:
		map_option.selected = default_index
	_update_map_description()

	# Set up aspect ratio options
	aspect_option.add_item("AUTO", 0)
	aspect_option.add_item("16:9", 1)
	aspect_option.add_item("4:3", 2)
	aspect_option.add_item("21:9", 3)

	# Load saved settings
	sens_slider.value = GameState.mouse_sensitivity
	fov_slider.value = GameState.player_fov
	fov_label.text = "FOV: " + str(int(GameState.player_fov))
	aspect_option.selected = GameState.aspect_ratio

	# Connect network signals
	NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
	NetworkManager.connection_failed.connect(_on_connection_failed)

func _show_main_panel() -> void:
	main_panel.visible = true
	host_panel.visible = false
	join_panel.visible = false
	settings_panel.visible = false

func _show_host_panel() -> void:
	main_panel.visible = false
	host_panel.visible = true
	join_panel.visible = false
	settings_panel.visible = false

func _show_join_panel() -> void:
	main_panel.visible = false
	host_panel.visible = false
	join_panel.visible = true
	settings_panel.visible = false
	connection_status.text = ""

func _show_settings_panel() -> void:
	main_panel.visible = false
	host_panel.visible = false
	join_panel.visible = false
	settings_panel.visible = true

# Main panel buttons
func _on_host_button_pressed() -> void:
	_show_host_panel()

func _on_join_button_pressed() -> void:
	_show_join_panel()

func _on_settings_button_pressed() -> void:
	_show_settings_panel()

func _on_quit_button_pressed() -> void:
	get_tree().quit()

# Host panel
func _on_max_players_slider_value_changed(value: float) -> void:
	max_players_label.text = "MAX PLAYERS: " + str(int(value))

func _on_start_host_pressed() -> void:
	var port = int(port_input.text) if port_input.text.is_valid_int() else 7777
	var max_players = int(max_players_slider.value)
	var mode = game_mode_option.selected

	# Set game mode
	GameState.set_game_mode(mode as GameState.GameMode)

	# Start hosting
	var error = NetworkManager.host_game(port, max_players)
	if error == OK:
		GameState.set_match_phase(GameState.MatchPhase.LOBBY)
		GameState.register_player(1, "Host")  # Server is always peer 1
		get_tree().change_scene_to_file("res://src/ui/lobby/lobby.tscn")
	else:
		print("Failed to host: ", error)

func _on_host_back_pressed() -> void:
	_show_main_panel()

# Join panel
func _on_connect_pressed() -> void:
	var address = address_input.text if address_input.text != "" else "127.0.0.1"
	var port = int(join_port_input.text) if join_port_input.text.is_valid_int() else 7777

	connection_status.text = "Connecting..."
	NetworkManager.join_game(address, port)

func _on_join_back_pressed() -> void:
	NetworkManager.disconnect_game()
	_show_main_panel()

func _on_connection_succeeded() -> void:
	connection_status.text = "Connected!"
	GameState.set_match_phase(GameState.MatchPhase.LOBBY)
	GameState.register_player(NetworkManager.get_my_id(), "Player")
	get_tree().change_scene_to_file("res://src/ui/lobby/lobby.tscn")

func _on_connection_failed() -> void:
	connection_status.text = "Connection failed!"

# Settings panel
func _on_settings_back_pressed() -> void:
	_show_main_panel()

func _on_sens_slider_value_changed(value: float) -> void:
	GameState.mouse_sensitivity = value

func _on_fov_slider_value_changed(value: float) -> void:
	GameState.player_fov = value
	fov_label.text = "FOV: " + str(int(value))

func _on_aspect_option_item_selected(index: int) -> void:
	GameState.aspect_ratio = index
	_apply_aspect_ratio(index)

func _on_map_option_item_selected(index: int) -> void:
	var map_id = MapData.get_map_id_by_index(index)
	MapData.set_selected_map(map_id)
	_update_map_description()

func _update_map_description() -> void:
	var map_info = MapData.get_map_info(MapData.selected_map)
	if map_info.size() > 0:
		map_description.text = map_info["description"]
	else:
		map_description.text = ""

func _apply_aspect_ratio(index: int) -> void:
	var viewport_size = get_viewport().size
	match index:
		0:  # Auto - use window aspect
			pass
		1:  # 16:9
			var target_width = viewport_size.y * 16.0 / 9.0
			get_viewport().size = Vector2i(int(target_width), viewport_size.y)
		2:  # 4:3
			var target_width = viewport_size.y * 4.0 / 3.0
			get_viewport().size = Vector2i(int(target_width), viewport_size.y)
		3:  # 21:9
			var target_width = viewport_size.y * 21.0 / 9.0
			get_viewport().size = Vector2i(int(target_width), viewport_size.y)
