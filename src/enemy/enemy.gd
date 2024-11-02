extends CharacterBody3D

@onready var nav_agent = $NavigationAgent3D

var SPEED = 10
@export var health := 100
@export var max_health := 100
var new_health = 0

@onready var health_bar := $SubViewport/Control/ProgressBar
var player = preload("res://src/player/player3d.tscn").instantiate()
var player_camera = player.get_node("head/Camera3D")

func _ready() -> void:
	add_child(health_bar)
	health_bar.position = Vector2(0, 3)  # Adjust position to float above the enemy
	health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # Fit the health bar width
	health_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # Center it vertically

func _physics_process(delta):
	health_bar.value = health
	var current_location = global_transform.origin
	var next_location = nav_agent.get_next_path_position()
	var new_velocity = (next_location - current_location).normalized() * SPEED
	
	velocity = velocity.move_toward(new_velocity, 0.25)
	move_and_slide()
	
func update_target_location(target_location):
	nav_agent.target_position = target_location

func take_damage(damage):
	new_health = health - damage
	health_bar.value = new_health
	health = new_health
	if health == 0:
		queue_free()

func _on_navigation_agent_3d_target_reached():
	$Timer.start()
	SPEED = 0

func _on_timer_timeout():
	SPEED = 10
