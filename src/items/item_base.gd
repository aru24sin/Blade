class_name ItemBase
extends RefCounted
## ItemBase - Base class for all items

var item_name: String = "Item"
var item_description: String = ""
var uses: int = 1
var duration: float = 0.0  # 0 means instant effect
var is_active: bool = false

func activate(player: Node) -> void:
	# Override in subclasses
	pass

func deactivate(player: Node) -> void:
	# Override in subclasses for timed effects
	pass

func use(player: Node) -> bool:
	# Override in subclasses for usable items (like kunai)
	# Return true if use was successful
	return false

func get_icon_path() -> String:
	return ""
