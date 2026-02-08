extends Marker3D
## SpawnPoint - Marks a player spawn location

@export var team: GameState.Team = GameState.Team.NONE  # For team-specific spawns

func _ready() -> void:
	add_to_group("spawn_point")
