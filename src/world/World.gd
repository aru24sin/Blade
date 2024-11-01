extends Node3D

@onready var player = $player

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

func _physics_process(delta):
	get_tree().call_group("Enemy", "update_target_location", player.global_transform.origin)
