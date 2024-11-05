extends CharacterBody3D

signal dashDid

@export var health := 100.0
@export var MOUSE_SENS := 0.010
@export var gravity := -0.7
@export var speed := 20
@export var angForCamToLearpTo := 0.0
@export var XangForCamToLearpTo := 0.0
@export var vel := Vector3.ZERO
@export var ySpeed := 0.0
@export var jumpStrength := 17
@export var extraVelMulti := 150
@export var maxDashAmt := 2
@export var maxJumpAmt := 2
@export var damage := 20

var jumpNum := 0
var canDash := true
var dashNum := 0
var extraVel := Vector3.ZERO

@onready var camera = $head/Camera3D
@onready var raycast = $head/Camera3D/RayCast3D

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		$head.rotation.x += -event.relative.y * MOUSE_SENS
		rotation.y += -event.relative.x * MOUSE_SENS
		
		$head.rotation.x = clamp($head.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("r"):
		get_tree().reload_current_scene()

func jump() -> void:
	if jumpNum == 0:
		jumpNum += 1
		ySpeed = jumpStrength
	elif jumpNum == 1:
		jumpNum += 1
		ySpeed = 22	

func dashFoward() -> void:
	emit_signal("dashDid")
	dashNum += 1
	if sign(ySpeed) == -1:
		ySpeed = 0
	extraVel += ($head/Camera3D/Marker3D.global_transform.origin - $head/Camera3D.global_transform.origin).normalized() * extraVelMulti

func _physics_process(delta: float) -> void:
	vel = get_dir().rotated( Vector3.UP, rotation.y) * speed
	if !is_on_floor() :
		ySpeed += gravity
	else:
		ySpeed = 0.0
		canDash = true
		dashNum = 0
		jumpNum = 0
	if Input.is_action_just_pressed("space") and (jumpNum < maxJumpAmt):
		jump()
	vel.y = ySpeed
	
	if Input.is_action_just_pressed("attack"):
		attack(damage)
	
	if Input.is_action_pressed("run"):
		speed = 35
	elif Input.is_action_just_released("run"):
		speed = 20

	if Input.is_action_just_pressed("f") and (dashNum < maxDashAmt):
		dashFoward()
	extraVel = lerp( extraVel, Vector3.ZERO, 0.1 )
	vel += extraVel
	
	set_velocity(vel)
	set_up_direction(Vector3.UP)
	move_and_slide()
	vel = velocity
	$head.rotation_degrees.z = lerp($head.rotation_degrees.z, angForCamToLearpTo, 0.1)
	$head/Camera3D.rotation_degrees.x = lerp($head/Camera3D.rotation_degrees.x, XangForCamToLearpTo, 0.1)

func attack(damage):
	if raycast.is_colliding():
		var enemy = raycast.get_collider()
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage)

func tweenComplete() -> void:
	$head/Camera3D/camTweenBack.interpolate_property($head/Camera3D,"fov", 94, 90,0.07,Tween.TRANS_QUART,Tween.EASE_IN,0)
	$head/Camera3D/camTweenBack.start()

func get_dir() -> Vector3:
	var dir : Vector3
	dir.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	angForCamToLearpTo = dir.x*-2.5
	dir.z = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	XangForCamToLearpTo = dir.z*7.5
	return dir.normalized()
