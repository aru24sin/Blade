extends Node3D
## Arena - Main multiplayer game level

const NETWORK_PLAYER_SCENE = preload("res://src/player/network_player.tscn")
const ITEM_BOX_SCENE = preload("res://src/items/item_box.tscn")
const HUD_SCENE = preload("res://src/ui/hud/hud.tscn")

@onready var player_spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var spawn_points: Node3D = $SpawnPoints
@onready var item_spawner: Node3D = $ItemSpawner

var spawned_players: Dictionary = {}
var hud: CanvasLayer = null

func _ready() -> void:
	# Configure spawner
	player_spawner.spawn_function = _spawn_player
	player_spawner.spawn_path = NodePath("Players")

	# Setup network callbacks
	if multiplayer.is_server():
		NetworkManager.player_connected.connect(_on_player_connected)
		NetworkManager.player_disconnected.connect(_on_player_disconnected)

		# Spawn all connected players
		_spawn_all_players()
	else:
		# Client waits for server to spawn players
		pass

	# Setup HUD
	_setup_hud()

	# Spawn item boxes
	if multiplayer.is_server():
		_spawn_item_boxes()

func _setup_hud() -> void:
	hud = HUD_SCENE.instantiate()
	add_child(hud)

	# Try to connect to local player immediately
	var local_player = PlayerRegistry.get_player(multiplayer.get_unique_id())
	if local_player:
		hud.set_local_player(local_player)
	else:
		# Wait for player to spawn and connect then
		PlayerRegistry.player_spawned.connect(_on_local_player_spawned)

func _on_local_player_spawned(peer_id: int, player_node: Node) -> void:
	if peer_id == multiplayer.get_unique_id():
		hud.set_local_player(player_node)
		# Disconnect after finding our player
		PlayerRegistry.player_spawned.disconnect(_on_local_player_spawned)

func _spawn_all_players() -> void:
	# Spawn server player (host)
	_spawn_player_for_peer(1)

	# Spawn all connected clients
	for peer_id in multiplayer.get_peers():
		_spawn_player_for_peer(peer_id)

func _spawn_player_for_peer(peer_id: int) -> void:
	if peer_id in spawned_players:
		return

	var spawn_pos = _get_spawn_position(peer_id)
	var player = NETWORK_PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.peer_id = peer_id
	player.global_position = spawn_pos

	$Players.add_child(player, true)
	spawned_players[peer_id] = player

	# Set authority
	player.set_multiplayer_authority(peer_id)

func _spawn_player(data) -> Node:
	# Called by MultiplayerSpawner
	var peer_id = data as int
	var player = NETWORK_PLAYER_SCENE.instantiate()
	player.peer_id = peer_id
	player.global_position = _get_spawn_position(peer_id)
	return player

func _get_spawn_position(peer_id: int) -> Vector3:
	var points = get_tree().get_nodes_in_group("spawn_point")

	if points.is_empty():
		return Vector3(0, 5, 0)

	# For team mode, try to get team-specific spawn
	if GameState.game_mode == GameState.GameMode.TEAM_BATTLE:
		var team = GameState.get_player_team(peer_id)
		var team_points = []
		for point in points:
			if "team" in point and point.team == team:
				team_points.append(point)
		if not team_points.is_empty():
			points = team_points

	# Pick a random spawn point
	var spawn_point = points[randi() % points.size()]
	return spawn_point.global_position

func _spawn_item_boxes() -> void:
	var item_points = $ItemSpawner.get_children()
	for point in item_points:
		if point is Marker3D:
			var box = ITEM_BOX_SCENE.instantiate()
			box.global_position = point.global_position
			$ItemBoxes.add_child(box, true)

func _on_player_connected(peer_id: int) -> void:
	# Spawn player for newly connected peer
	_spawn_player_for_peer(peer_id)

func _on_player_disconnected(peer_id: int) -> void:
	if peer_id in spawned_players:
		var player = spawned_players[peer_id]
		if is_instance_valid(player):
			player.queue_free()
		spawned_players.erase(peer_id)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("quit"):
		if hud:
			hud.toggle_pause()
