extends Node
## MapData - Registry of available maps with metadata

const MAPS = {
	"arena": {
		"name": "Arena",
		"description": "Classic combat arena with platforms and pillars",
		"path": "res://src/world/arena.tscn",
		"player_count": "2-16",
		"theme": "Dark Temple"
	},
	"skyscrapers": {
		"name": "Skyscrapers",
		"description": "Three towering buildings with bridges and ledges to jump across",
		"path": "res://src/world/map_skyscrapers.tscn",
		"player_count": "2-8",
		"theme": "Night City"
	},
	"botanical": {
		"name": "Botanical Garden",
		"description": "Serene Japanese garden with cherry trees, a pagoda, and bamboo groves",
		"path": "res://src/world/map_botanical.tscn",
		"player_count": "2-8",
		"theme": "Nature"
	}
}

var selected_map: String = "arena"

func get_map_names() -> Array:
	var names = []
	for key in MAPS:
		names.append(MAPS[key]["name"])
	return names

func get_map_ids() -> Array:
	return MAPS.keys()

func get_map_info(map_id: String) -> Dictionary:
	if MAPS.has(map_id):
		return MAPS[map_id]
	return {}

func get_map_path(map_id: String) -> String:
	if MAPS.has(map_id):
		return MAPS[map_id]["path"]
	return "res://src/world/arena.tscn"

func get_selected_map_path() -> String:
	return get_map_path(selected_map)

func get_selected_map_name() -> String:
	if MAPS.has(selected_map):
		return MAPS[selected_map]["name"]
	return "Arena"

func set_selected_map(map_id: String) -> void:
	if MAPS.has(map_id):
		selected_map = map_id

func get_map_id_by_index(index: int) -> String:
	var keys = MAPS.keys()
	if index >= 0 and index < keys.size():
		return keys[index]
	return "arena"

func get_index_by_map_id(map_id: String) -> int:
	var keys = MAPS.keys()
	return keys.find(map_id)
