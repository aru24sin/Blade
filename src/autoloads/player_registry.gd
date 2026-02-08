extends Node
## PlayerRegistry - Tracks all connected players and their node references
## Autoload singleton for player management

signal player_spawned(peer_id: int, player_node: Node)
signal player_despawned(peer_id: int)
signal all_players_ready()

var players: Dictionary = {}  # peer_id -> Player node reference
var player_ready_status: Dictionary = {}  # peer_id -> bool

func _ready() -> void:
	NetworkManager.player_disconnected.connect(_on_player_disconnected)

func register_player_node(peer_id: int, player_node: Node) -> void:
	players[peer_id] = player_node
	player_spawned.emit(peer_id, player_node)

func unregister_player_node(peer_id: int) -> void:
	if peer_id in players:
		players.erase(peer_id)
		player_despawned.emit(peer_id)

func get_player(peer_id: int) -> Node:
	return players.get(peer_id, null)

func get_all_players() -> Array:
	return players.values()

func get_all_player_ids() -> Array:
	return players.keys()

func get_player_count() -> int:
	return players.size()

func set_player_ready(peer_id: int, ready: bool) -> void:
	player_ready_status[peer_id] = ready
	_check_all_ready()

func is_player_ready(peer_id: int) -> bool:
	return player_ready_status.get(peer_id, false)

func are_all_players_ready() -> bool:
	if player_ready_status.is_empty():
		return false
	for peer_id in player_ready_status:
		if not player_ready_status[peer_id]:
			return false
	return true

func reset_ready_status() -> void:
	for peer_id in player_ready_status:
		player_ready_status[peer_id] = false

func _check_all_ready() -> void:
	if are_all_players_ready():
		all_players_ready.emit()

func _on_player_disconnected(peer_id: int) -> void:
	unregister_player_node(peer_id)
	player_ready_status.erase(peer_id)

func get_closest_enemy(from_position: Vector3, my_peer_id: int, my_team: GameState.Team = GameState.Team.NONE) -> Node:
	var closest: Node = null
	var closest_distance: float = INF

	for peer_id in players:
		if peer_id == my_peer_id:
			continue

		# In team mode, skip teammates
		if GameState.game_mode == GameState.GameMode.TEAM_BATTLE:
			if GameState.get_player_team(peer_id) == my_team and my_team != GameState.Team.NONE:
				continue

		var player = players[peer_id]
		if player and is_instance_valid(player):
			var distance = from_position.distance_to(player.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest = player

	return closest

func get_enemies_in_range(from_position: Vector3, range_distance: float, my_peer_id: int, my_team: GameState.Team = GameState.Team.NONE) -> Array:
	var enemies = []

	for peer_id in players:
		if peer_id == my_peer_id:
			continue

		# In team mode, skip teammates
		if GameState.game_mode == GameState.GameMode.TEAM_BATTLE:
			if GameState.get_player_team(peer_id) == my_team and my_team != GameState.Team.NONE:
				continue

		var player = players[peer_id]
		if player and is_instance_valid(player):
			var distance = from_position.distance_to(player.global_position)
			if distance <= range_distance:
				enemies.append(player)

	return enemies

# Network RPCs for ready status
@rpc("any_peer", "call_local", "reliable")
func request_set_ready(ready: bool) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = NetworkManager.get_my_id()
	set_player_ready(sender_id, ready)

	if NetworkManager.is_server():
		sync_ready_status.rpc(player_ready_status)

@rpc("authority", "call_local", "reliable")
func sync_ready_status(status: Dictionary) -> void:
	player_ready_status = status
