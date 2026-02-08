extends Node3D
## ItemSpawner - Manages item box spawn locations in a level

@export var item_box_scene: PackedScene
@export var spawn_points: Array[Marker3D] = []
@export var initial_spawn_delay: float = 5.0

var spawned_boxes: Array = []

func _ready() -> void:
	if not multiplayer.is_server() and multiplayer.has_multiplayer_peer():
		return

	# Wait before spawning initial boxes
	await get_tree().create_timer(initial_spawn_delay).timeout
	_spawn_all_boxes()

func _spawn_all_boxes() -> void:
	if not item_box_scene:
		item_box_scene = preload("res://src/items/item_box.tscn")

	# Find all spawn points (children with Marker3D or nodes in spawn_points group)
	var points = spawn_points.duplicate()

	# Also check for child Marker3D nodes
	for child in get_children():
		if child is Marker3D and child not in points:
			points.append(child)

	# Spawn boxes at each point
	for point in points:
		var box = item_box_scene.instantiate()
		box.global_position = point.global_position
		add_child(box)
		spawned_boxes.append(box)

func add_spawn_point(position: Vector3) -> void:
	var marker = Marker3D.new()
	marker.global_position = position
	add_child(marker)

	if item_box_scene:
		var box = item_box_scene.instantiate()
		box.global_position = position
		add_child(box)
		spawned_boxes.append(box)
