extends Node
## NetworkManager - Handles multiplayer connections via ENet
## Autoload singleton for managing host/join and peer events

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal connection_succeeded()
signal connection_failed()
signal server_disconnected()

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 16

var peer: ENetMultiplayerPeer = null

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_game(port: int = DEFAULT_PORT, max_clients: int = MAX_PLAYERS) -> Error:
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, max_clients)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		print("Server started on port ", port)
	else:
		print("Failed to start server: ", error)
	return error

func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, port)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		print("Connecting to ", address, ":", port)
	else:
		print("Failed to connect: ", error)
	return error

func disconnect_game() -> void:
	if peer:
		peer.close()
		multiplayer.multiplayer_peer = null
		peer = null
		print("Disconnected from game")

func is_server() -> bool:
	return multiplayer.is_server()

func is_connected_to_game() -> bool:
	return peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func get_my_id() -> int:
	return multiplayer.get_unique_id()

func get_player_ids() -> Array:
	var ids = multiplayer.get_peers().duplicate()
	ids.append(get_my_id())
	return ids

func _on_peer_connected(id: int) -> void:
	print("Player connected: ", id)
	player_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	print("Player disconnected: ", id)
	player_disconnected.emit(id)

func _on_connected_to_server() -> void:
	print("Connected to server")
	connection_succeeded.emit()

func _on_connection_failed() -> void:
	print("Connection failed")
	peer = null
	connection_failed.emit()

func _on_server_disconnected() -> void:
	print("Server disconnected")
	peer = null
	server_disconnected.emit()
