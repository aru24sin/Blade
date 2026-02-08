extends Node3D

@onready var player = $player

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
